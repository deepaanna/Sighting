## CameraPhase — Photo capture viewfinder phase.
## Step 5: scene transition, viewfinder layout, cryptid drift + lunge, capture flow.
## Step 6: SubViewport renders CryptidView; blur.gdshader applies distance-based
##         Gaussian blur, chromatic aberration, overexposure, film grain, vignette.
##         Camera shake added at very close range. ViewfinderFrame draws overlays.
## Step 7: Credibility slider; slider_mult bell-curve; DEBUNKED/ENHANCED overlays.
## Step 8: Full scoring — Gaussian base_score × slider_mult + time_bonus → 0–100.

class_name CameraPhase
extends Node2D

## Set by FieldPhase before SceneManager.change_scene().
static var session: Dictionary = {
	"cryptid_type": "bigfoot",
	"hex_distance": 3,
	"zone":         "pacific_nw",
	"weather":      "clear",
	"sweet_spot":   3,
}

# ── Layout constants ──────────────────────────────────────────────────
const VF_ORIGIN  := Vector2(20.0,  50.0)
const VF_SIZE    := Vector2(320.0, 290.0)
const VP_CENTER  := Vector2(160.0, 145.0)   # SubViewport centre (VF_SIZE / 2)

# ── Timing ────────────────────────────────────────────────────────────
const PHASE_TIME := 20.0
const MAX_SHOTS  := 3

# ── Cryptid drift ─────────────────────────────────────────────────────
const DRIFT_H_SPEED := 0.72
const DRIFT_V_SPEED := 0.50
const DRIFT_H_AMP   := 60.0
const DRIFT_V_AMP   := 25.0
const LUNGE_MIN     := 3.8
const LUNGE_MAX     := 7.5
const LUNGE_SPEED   := 290.0
const DRIFT_LERP    := 0.07

# ── Node refs ─────────────────────────────────────────────────────────
@onready var _cryptid_view:  Node2D       = $CryptidViewport/CryptidView
@onready var _vp_display:    TextureRect  = $ViewportDisplay
@onready var _vf_frame:      Node2D       = $ViewfinderFrame
@onready var _timer_label:   Label        = $HUD/TopBar/TimerLabel
@onready var _cryptid_label: Label        = $HUD/TopBar/CryptidLabel
@onready var _slider:        HSlider      = $HUD/Controls/SliderRow/CredibilitySlider
@onready var _slider_pct:    Label        = $HUD/Controls/CredibilityPct
@onready var _capture_btn:   Button       = $HUD/Controls/CaptureButton
@onready var _shots_label:   Label        = $HUD/Controls/ShotsLabel

# ── Blur pipeline ─────────────────────────────────────────────────────
var _blur_mat:       ShaderMaterial
var _blur_amount:    float = 0.0
var _overexposure:   float = 0.0
var _shake_mag:      float = 0.0   # px, >0 only when very close

# ── Session state ─────────────────────────────────────────────────────
var _elapsed:           float = 0.0
var _shots_taken:       int   = 0
var _best_score:        int   = 0
var _running:           bool  = false
var _slider_value:      float = 0.5   # 0.0–1.0; 0.5 = center sweet spot
var _extra_shot_used:   bool  = false
var _extra_btn:         Button = null

# ── REC blink ─────────────────────────────────────────────────────────
var _rec_visible:  bool  = true
var _rec_timer:    float = 0.0

# ── Cryptid movement ──────────────────────────────────────────────────
var _cryptid_pos:  Vector2 = VP_CENTER
var _lunge_timer:  float   = 4.0
var _lunge_target: Vector2 = VP_CENTER
var _is_lunging:   bool    = false


# ── Setup ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup_viewport_texture()
	_setup_blur_shader()
	_apply_blur_for_distance()

	_cryptid_view.position = VP_CENTER
	_cryptid_view.setup(session.get("hex_distance", 3))

	var ctype := (session.get("cryptid_type", "bigfoot") as String).to_upper()
	var zone  := _zone_display()
	_cryptid_label.text = "%s · %s" % [ctype, zone]
	_timer_label.text   = "0:%02d" % int(PHASE_TIME)
	_shots_label.text   = "Shots remaining: %d" % MAX_SHOTS
	_slider.value       = 50.0
	_slider_pct.text    = "50%"
	_slider.value_changed.connect(_on_slider_changed)

	_vf_frame.zone_name       = zone
	_vf_frame.shots_remaining = MAX_SHOTS
	_vf_frame.blur_amount     = _blur_amount
	_vf_frame.overexposure    = _overexposure
	_vf_frame.slider_value    = _slider_value

	_capture_btn.pressed.connect(_on_capture_pressed)
	UIStyler.style_button(_capture_btn, UIStyler.ACCENT_GREEN)
	_running = true
	AudioManager.play_music("camera_tense")
	if not Codex.get_value("sighting", "camera_tutorial_shown", false):
		Codex.set_value("sighting", "camera_tutorial_shown", true)
		_show_camera_hint()
	if _overexposure > 0.1:
		_show_too_close_hint()


func _setup_viewport_texture() -> void:
	_vp_display.texture = $CryptidViewport.get_texture()


func _setup_blur_shader() -> void:
	_blur_mat        = ShaderMaterial.new()
	_blur_mat.shader = load("res://shaders/blur.gdshader")
	_vp_display.material = _blur_mat


func _apply_blur_for_distance() -> void:
	var dist   : int = session.get("hex_distance", 3)
	var sweet  : int = session.get("sweet_spot",   3)
	_blur_amount   = _calc_blur(dist, sweet)
	_overexposure  = _calc_overexposure(dist, sweet)
	_shake_mag     = _calc_shake(dist, sweet)
	_blur_mat.set_shader_parameter("blur_amount",  _blur_amount)
	_blur_mat.set_shader_parameter("overexposure", _overexposure)


# ── Blur math (distance-quality inversion) ────────────────────────────

static func _calc_blur(dist: int, sweet: int) -> float:
	if dist < sweet:
		# Closer than sweet spot — blur grows quadratically, capped so shape stays visible
		var steps := sweet - dist
		return minf(1.5 + steps * steps * 2.5, 5.5)
	elif dist == sweet:
		return 1.5   # slight authentic blur at the ideal distance
	else:
		# Farther than sweet spot — linear falloff toward sharp
		var t := clampf(float(dist - sweet) / 3.0, 0.0, 1.0)
		return lerp(1.5, 0.0, t)


static func _calc_overexposure(dist: int, sweet: int) -> float:
	if dist >= sweet - 1:
		return 0.0
	return clampf(float(sweet - dist - 1) / 2.0, 0.0, 0.45)


static func _calc_shake(dist: int, sweet: int) -> float:
	var steps_too_close := sweet - dist
	if steps_too_close <= 0:
		return 0.0
	return minf(steps_too_close * 3.5, 10.0)


static func _calc_slider_mult(v: float) -> float:
	# Peaks at 0.5 (1.0×), falls to 0.3× at extremes (0.0 or 1.0)
	var t: float = abs(v - 0.5) * 2.0
	return lerp(1.0, 0.3, pow(t, 1.5))


static func _calc_base_score(dist: int, sweet: int) -> float:
	# Gaussian bell curve centered on sweet spot, spread = 1.5 hex steps
	const SPREAD := 1.5
	var t := float(dist - sweet) / SPREAD
	return exp(-0.5 * t * t)


# ── Game loop ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _running:
		return

	_elapsed += delta
	var remaining := maxf(0.0, PHASE_TIME - _elapsed)
	_timer_label.text = "0:%02d" % int(remaining)

	_rec_timer -= delta
	if _rec_timer <= 0.0:
		_rec_timer   = 0.75
		_rec_visible = not _rec_visible

	_tick_cryptid(delta)
	_tick_shake()
	_update_frame_overlay()

	if remaining <= 0.0:
		_running = false
		_finish_phase()

	queue_redraw()


# ── Cryptid movement ──────────────────────────────────────────────────

func _tick_cryptid(delta: float) -> void:
	if _is_lunging:
		var to_target := _lunge_target - _cryptid_pos
		if to_target.length() < 6.0:
			_is_lunging  = false
			_lunge_timer = randf_range(LUNGE_MIN, LUNGE_MAX)
		else:
			_cryptid_pos += to_target.normalized() * LUNGE_SPEED * delta
			return

	_lunge_timer -= delta
	if _lunge_timer <= 0.0:
		_is_lunging   = true
		var half      := VF_SIZE * 0.36
		_lunge_target  = VP_CENTER + Vector2(
			randf_range(-half.x, half.x),
			randf_range(-half.y, half.y)
		)

	var drift_target := VP_CENTER + Vector2(
		sin(_elapsed * DRIFT_H_SPEED) * DRIFT_H_AMP,
		cos(_elapsed * DRIFT_V_SPEED) * DRIFT_V_AMP
	)
	_cryptid_pos = _cryptid_pos.lerp(drift_target, DRIFT_LERP)


func _tick_shake() -> void:
	if _shake_mag < 0.1:
		_cryptid_view.position = _cryptid_pos
		return
	var shake := Vector2(
		randf_range(-_shake_mag, _shake_mag),
		randf_range(-_shake_mag, _shake_mag)
	)
	_cryptid_view.position = _cryptid_pos + shake


# ── Frame overlay ─────────────────────────────────────────────────────

func _update_frame_overlay() -> void:
	_vf_frame.rec_visible     = _rec_visible
	_vf_frame.shots_remaining = MAX_SHOTS - _shots_taken
	_vf_frame.blur_amount     = _blur_amount
	_vf_frame.overexposure    = _overexposure
	_vf_frame.slider_value    = _slider_value
	_vf_frame.queue_redraw()


# ── Capture ───────────────────────────────────────────────────────────

func _on_capture_pressed() -> void:
	if not _running or _shots_taken >= MAX_SHOTS:
		return
	_shots_taken += 1
	_shots_label.text = "Shots remaining: %d" % (MAX_SHOTS - _shots_taken)

	var dist       : int   = session.get("hex_distance", 3)
	var sweet      : int   = session.get("sweet_spot",   3)
	var base        := _calc_base_score(dist, sweet)
	var slider_mult := _calc_slider_mult(_slider_value)
	var time_bonus  := maxf(0.0, 1.0 - (_elapsed / PHASE_TIME)) * 0.2
	var score       := int(clampf((base * slider_mult + time_bonus) * 100.0, 0.0, 100.0))
	if score > _best_score:
		_best_score = score

	_flash_shutter()

	if _shots_taken >= MAX_SHOTS:
		_running = false
		_offer_extra_shot()


func _show_camera_hint() -> void:
	var hints: Array = [
		"TAP the viewfinder or CAPTURE\nto take a photo. You have 3 shots.",
		"CENTER dial = best score.\nFull SKEPTIC or BELIEVER hurts quality.",
	]
	var delay := 0.5
	for hint: String in hints:
		var lbl          := Label.new()
		lbl.text          = hint
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.size          = Vector2(320, 64)
		lbl.position      = Vector2(20, 360)
		lbl.z_index       = 20
		lbl.modulate      = Color(1, 1, 1, 0)
		var bg           := ColorRect.new()
		bg.color          = Color(0.0, 0.0, 0.0, 0.75)
		bg.size           = Vector2(320, 64)
		bg.mouse_filter   = Control.MOUSE_FILTER_IGNORE
		lbl.add_child(bg)
		lbl.move_child(bg, 0)
		add_child(lbl)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.3)
		tw.tween_interval(3.0)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
		tw.tween_callback(lbl.queue_free)
		delay += 4.5


func _show_too_close_hint() -> void:
	var lbl                  := Label.new()
	lbl.text                  = "CRYPTID TOO CLOSE — blurry shot.\nIn the field, stay further away\nfor a cleaner photo."
	lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD
	lbl.size                  = Vector2(280, 72)
	lbl.position              = Vector2(40, 352)
	lbl.z_index               = 20
	lbl.modulate              = Color(1.0, 0.45, 0.30, 0.0)
	var bg                   := ColorRect.new()
	bg.color                  = Color(0.0, 0.0, 0.0, 0.82)
	bg.size                   = lbl.size
	bg.mouse_filter           = Control.MOUSE_FILTER_IGNORE
	lbl.add_child(bg)
	lbl.move_child(bg, 0)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.4)
	tw.tween_interval(4.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)


func _offer_extra_shot() -> void:
	if _extra_shot_used:
		await get_tree().create_timer(0.6).timeout
		_finish_phase()
		return

	_extra_btn = Button.new()
	_extra_btn.text = "EXTRA SHOT — Watch Ad"
	_extra_btn.custom_minimum_size = Vector2(320, 52)
	_extra_btn.position = Vector2(20, 555)
	_extra_btn.z_index  = 10
	UIStyler.style_button(_extra_btn, UIStyler.ACCENT_ORANGE)
	add_child(_extra_btn)
	_extra_btn.pressed.connect(_on_extra_shot_ad)

	get_tree().create_timer(5.0).timeout.connect(_on_extra_shot_timeout, CONNECT_ONE_SHOT)


func _on_extra_shot_timeout() -> void:
	if not _extra_shot_used and is_instance_valid(_extra_btn):
		_extra_btn.queue_free()
		_finish_phase()


func _on_extra_shot_ad() -> void:
	if is_instance_valid(_extra_btn):
		_extra_btn.queue_free()
	AdManager.show_rewarded("extra_capture", _grant_extra_shot)
	AdManager.rewarded_failed.connect(
		func(_p: String):
			if is_instance_valid(self) and not _extra_shot_used:
				_finish_phase(),
		CONNECT_ONE_SHOT
	)


func _grant_extra_shot() -> void:
	_extra_shot_used = true
	_shots_taken    -= 1
	_shots_label.text = "Shots remaining: 1"
	_running          = true


func _on_slider_changed(val: float) -> void:
	_slider_value    = val / 100.0
	_slider_pct.text = "%d%%" % int(val)


func _flash_shutter() -> void:
	AudioManager.play_sfx("shutter")
	var flash        := ColorRect.new()
	flash.color       = Color(1.0, 1.0, 1.0, 0.75)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var t := create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.28)
	t.tween_callback(flash.queue_free)


func _finish_phase() -> void:
	var ctype    := session.get("cryptid_type", "bigfoot") as String
	var best_key := "best_" + ctype
	var prev_best: int = Codex.get_value("sighting", best_key, 0)
	Codex.set_value("sighting", "_last_score",       _best_score)
	Codex.set_value("sighting", "_last_cryptid",     ctype)
	Codex.set_value("sighting", "_last_zone",        session.get("zone", "pacific_nw"))
	Codex.set_value("sighting", "_last_weather",     session.get("weather", "clear"))
	Codex.set_value("sighting", "_last_is_new_best", _best_score > prev_best)
	if _best_score > prev_best:
		Codex.set_value("sighting", best_key, _best_score)

	AudioManager.stop_music(0.4)
	await _capture_viewfinder()

	SceneManager.change_scene(
		"res://scenes/game_specific/result/result.tscn", 0.4
	)


func _capture_viewfinder() -> void:
	# Arm export overlay on ViewfinderFrame so the grade badge + watermark
	# are burned into the captured image via its _draw() path.
	_vf_frame.export_overlay_mode = true
	_vf_frame.export_grade        = _grade_letter(_best_score)
	_vf_frame.export_score        = _best_score
	_vf_frame.export_cryptid      = session.get("cryptid_type", "bigfoot") as String
	_vf_frame.queue_redraw()

	# Hide HUD so the captured image is only viewfinder content
	$HUD.visible = false
	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	img = img.get_region(Rect2i(
		int(VF_ORIGIN.x), int(VF_ORIGIN.y),
		int(VF_SIZE.x),   int(VF_SIZE.y)
	))

	# Restore normal state
	$HUD.visible              = true
	_vf_frame.export_overlay_mode = false
	_vf_frame.queue_redraw()

	var ctype     := session.get("cryptid_type", "bigfoot") as String
	var meta      := {
		"score":   _best_score,
		"grade":   _grade_letter(_best_score),
		"cryptid": ctype,
		"zone":    session.get("zone", "pacific_nw"),
	}
	var timestamp := Time.get_unix_time_from_system()
	var filename  := "sighting_%d.png" % timestamp
	var path      := "user://gallery/" + filename
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://gallery/")
	)
	img.save_png(path)

	# Register in shared gallery metadata
	var gallery_meta: Array = Codex.get_value("gallery", "photos", [])
	gallery_meta.append({"file": filename, "time": timestamp, "meta": meta})
	while gallery_meta.size() > 100:
		var oldest: Dictionary = gallery_meta.pop_front()
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path("user://gallery/" + oldest.get("file", ""))
		)
	Codex.set_value("gallery", "photos", gallery_meta)
	Codex.set_value("sighting", "gallery_photos", gallery_meta.size())
	Codex.set_value("sighting", "_last_photo_file", filename)


static func _grade_letter(score: int) -> String:
	if score >= 90: return "S"
	elif score >= 70: return "A"
	elif score >= 50: return "B"
	elif score >= 30: return "C"
	elif score >= 10: return "D"
	else: return "F"


# ── Input ─────────────────────────────────────────────────────────────
# Intentionally empty — use the CAPTURE button. Viewfinder taps were
# firing accidental captures when players tried to interact with the UI.


# ── Drawing — background only; frame overlays are on ViewfinderFrame ──

func _draw() -> void:
	var vp := get_viewport_rect().size
	# Dark background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.04, 0.05))
	# Viewfinder green background (sits beneath ViewportDisplay)
	draw_rect(Rect2(VF_ORIGIN, VF_SIZE), Color(0.06, 0.11, 0.07))
	# Base scanlines beneath the SubViewport content
	for y in range(int(VF_ORIGIN.y) + 1, int(VF_ORIGIN.y + VF_SIZE.y), 4):
		draw_line(Vector2(VF_ORIGIN.x, y), Vector2(VF_ORIGIN.x + VF_SIZE.x, y),
			Color(0.0, 0.0, 0.0, 0.12), 1.0)


# ── Helpers ───────────────────────────────────────────────────────────

func _zone_display() -> String:
	return (session.get("zone", "") as String).replace("_", " ").to_upper()
