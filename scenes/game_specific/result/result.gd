## Result — Score display, grade, Theory Feed animation, reputation save.
## Step 11: SHARE sends the saved sighting photo (with burned-in overlay) via
##          system share sheet; falls back to result-screen capture if none saved.
## Step 14: Boost ad (+50% XP/rep), interstitial after animation.

extends Node2D

const GRADE_TABLE: Array = [
	[90, "S", "THE TRUTH",          Color(1.00, 0.85, 0.10)],
	[70, "A", "Compelling Evidence", Color(0.30, 0.90, 0.30)],
	[50, "B", "Interesting...",      Color(0.40, 0.70, 1.00)],
	[30, "C", "Needs More Evidence", Color(0.80, 0.60, 0.20)],
	[10, "D", "Blurry Nonsense",     Color(0.70, 0.30, 0.20)],
	[ 0, "F", "Obviously Fake",      Color(0.50, 0.10, 0.10)],
]

@onready var _grade_label:   Label      = $HUD/Content/GradeLabel
@onready var _score_label:   Label      = $HUD/Content/ScoreLabel
@onready var _verdict_label: Label      = $HUD/Content/VerdictLabel
@onready var _theory_feed:   TheoryFeed = $HUD/Content/TheoryFeedSection
@onready var _pb_label:      Label      = $HUD/Content/PersonalBestLabel
@onready var _xp_label:      Label      = $HUD/Content/XPLabel
@onready var _boost_btn:     Button     = $HUD/Content/BoostButton
@onready var _unlock_label:  Label      = $HUD/Content/UnlockLabel
@onready var _home_btn:      Button     = $HUD/Content/NavRow/HomeButton
@onready var _retry_btn:     Button     = $HUD/Content/NavRow/RetryButton
@onready var _share_btn:     Button     = $HUD/Content/ActionRow/ShareButton
@onready var _gallery_btn:   Button     = $HUD/Content/ActionRow/GalleryButton

var _score:        int    = 0
var _grade_letter: String = "F"
var _ctype:        String = "bigfoot"
var _grade_idx:    int    = 5
var _xp_earned:    int    = 0   # stored for boost calculation
var _grade_color:  Color  = Color.WHITE
var _draw_t:       float  = 0.0


func _ready() -> void:
	_score  = Codex.get_value("sighting", "_last_score",   0)
	_ctype  = Codex.get_value("sighting", "_last_cryptid", "bigfoot") as String
	var zone := Codex.get_value("sighting", "_last_zone",   "pacific_nw") as String

	_grade_idx            = _grade_idx_for(_score)
	var grade_data: Array = GRADE_TABLE[_grade_idx]
	_grade_letter          = grade_data[1] as String
	_grade_color           = grade_data[3] as Color

	_grade_label.text     = _grade_letter
	_grade_label.modulate  = grade_data[3] as Color
	_score_label.text     = "%s — %d / 100" % [_ctype.to_upper(), _score]
	_verdict_label.text   = '"%s"' % grade_data[2]

	# Grade label punch-in — deferred so layout has run and size is valid
	_grade_label.modulate.a = 0.0
	call_deferred("_animate_grade_reveal")

	# Music and reveal SFX
	if _grade_idx <= 1:
		AudioManager.play_sfx("score_high")
		AudioManager.play_music("result_fanfare")
	elif _grade_idx >= 4:
		AudioManager.play_sfx("score_low")
		AudioManager.play_music("result_sad")
	else:
		AudioManager.play_music("result_ambient")

	# Personal best
	var best_key    := "best_" + _ctype
	var is_new_best := Codex.get_value("sighting", "_last_is_new_best", false) as bool
	var best_score  : int = Codex.get_value("sighting", best_key, _score)
	if is_new_best:
		_pb_label.text     = "★  NEW PERSONAL BEST!"
		_pb_label.modulate = grade_data[3] as Color
	elif best_score > 0:
		_pb_label.text     = "Personal Best: %d / 100" % best_score
		_pb_label.modulate = Color(0.65, 0.65, 0.65)
	else:
		_pb_label.text     = "First Sighting!"
		_pb_label.modulate = Color(0.80, 0.85, 0.50)

	# Reputation
	var rep_delta : int = TheoryFeed.REP_DELTA[_grade_idx]
	var old_rep   : int = Codex.get_value("sighting", "feed_reputation", 0)
	Codex.set_value("sighting", "feed_reputation", max(0, old_rep + rep_delta))
	var global_rep: int = Codex.get_value("codex", "theory_feed_reputation", 0)
	Codex.set_value("codex", "theory_feed_reputation", max(0, global_rep + rep_delta))

	if _grade_idx == 5:
		Codex.set_value("sighting", "_feed_banned", true)

	_show_progression(Progression.award_run(_grade_idx, _ctype))

	_theory_feed.start(_grade_idx, _ctype, zone)

	_home_btn.pressed.connect(func():
		SceneManager.change_scene(
			"res://scenes/game_specific/menu/main_menu.tscn", 0.3
		)
	)
	_retry_btn.pressed.connect(func():
		SceneManager.change_scene(
			"res://scenes/game_specific/field/field.tscn", 0.3
		)
	)
	_boost_btn.pressed.connect(_on_boost_pressed)
	_share_btn.pressed.connect(_on_share_pressed)
	_gallery_btn.pressed.connect(_on_gallery_pressed)

	# Button styling
	UIStyler.style_button(_home_btn,    UIStyler.ACCENT_MUTED)
	UIStyler.style_button(_retry_btn,   UIStyler.ACCENT_GREEN)
	UIStyler.style_button(_share_btn,   UIStyler.ACCENT_MUTED)
	UIStyler.style_button(_gallery_btn, UIStyler.ACCENT_MUTED)
	UIStyler.style_button(_boost_btn,   UIStyler.ACCENT_ORANGE)

	queue_redraw()

	SightingCodex.on_run_complete(_grade_idx, _ctype, _score)

	# Interstitial after animation settles — frequency-capped by AdManager
	get_tree().create_timer(3.5).timeout.connect(AdManager.show_interstitial_if_ready)


func _process(delta: float) -> void:
	_draw_t += delta
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	_draw_scanlines(vp)
	_draw_grade_glow(vp)


func _draw_scanlines(vp: Vector2) -> void:
	for y in range(0, int(vp.y), 6):
		draw_line(Vector2(0, float(y)), Vector2(vp.x, float(y)),
			Color(0.0, 0.0, 0.0, 0.05), 1.0)


func _draw_grade_glow(vp: Vector2) -> void:
	# Animated hex-ring glow centered on the grade label (approx y=163 in 640 viewport)
	var center := Vector2(vp.x * 0.5, 163.0)
	var pulse  := 0.5 + sin(_draw_t * 1.3) * 0.28
	for i in 5:
		var radius : float = 48.0 + i * 17.0
		var alpha  : float = (0.20 - i * 0.036) * pulse
		var col    := Color(_grade_color.r, _grade_color.g, _grade_color.b, alpha)
		_draw_hex_ring(center, radius, col)


func _draw_hex_ring(center: Vector2, radius: float, color: Color) -> void:
	var verts := HexGrid.hex_vertices(radius)
	var pts   := PackedVector2Array()
	for v in verts:
		pts.append(center + v)
	pts.append(pts[0])
	draw_polyline(pts, color, 2.0)


func _show_progression(prog: Dictionary) -> void:
	_xp_earned      = prog.get("xp_earned",   0)
	var streak  : int   = prog.get("streak",       1)
	var mult    : float = prog.get("streak_mult",  1.0)
	var zone_idx: int   = prog.get("new_zone_idx", -1)
	var upgrade : String = prog.get("new_upgrade", "")

	var xp_text := "+%d XP" % _xp_earned
	if streak > 1:
		xp_text += "  ×%.1f streak" % mult
	_xp_label.text     = xp_text
	_xp_label.modulate = Color(0.95, 0.85, 0.20)

	# Show boost for any scoring run; AdManager grants free reward if ads removed
	if _score > 0:
		_boost_btn.visible = true

	if zone_idx >= 0:
		_unlock_label.text    = "★  ZONE UNLOCKED: %s" % Progression.zone_display(zone_idx)
		_unlock_label.modulate = Color(0.30, 0.90, 0.30)
		_unlock_label.visible  = true
	elif upgrade != "":
		var upgrade_names: Dictionary = {
			"vintage":      "VINTAGE FILTER",
			"night_vision": "NIGHT VISION CAM",
			"vhs":          "VHS MODE",
		}
		_unlock_label.text    = "★  UPGRADE UNLOCKED: %s" % upgrade_names.get(upgrade, upgrade.to_upper())
		_unlock_label.modulate = Color(0.40, 0.70, 1.00)
		_unlock_label.visible  = true


func _on_boost_pressed() -> void:
	_boost_btn.disabled = true
	AdManager.show_rewarded("boost_xp", _apply_boost)
	AdManager.rewarded_failed.connect(
		func(_p: String):
			if is_instance_valid(self):
				_boost_btn.disabled = false,
		CONNECT_ONE_SHOT
	)


func _apply_boost() -> void:
	_boost_btn.visible = false

	var bonus_xp  : int = max(1, _xp_earned / 2 as int)   # +50% of run XP
	var total_xp  : int = Codex.get_value("sighting", "total_xp", 0)
	Codex.set_value("sighting", "total_xp", total_xp + bonus_xp)
	var global_xp : int = Codex.get_value("codex", "total_evidence_collected", 0)
	Codex.set_value("codex", "total_evidence_collected", global_xp + bonus_xp)

	var rep_bonus : int = max(0, TheoryFeed.REP_DELTA[_grade_idx] / 2 as int)
	var rep       : int = Codex.get_value("sighting", "feed_reputation", 0)
	Codex.set_value("sighting", "feed_reputation", max(0, rep + rep_bonus))
	var g_rep     : int = Codex.get_value("codex", "theory_feed_reputation", 0)
	Codex.set_value("codex", "theory_feed_reputation", max(0, g_rep + rep_bonus))

	_xp_label.text    = "%s  +%d BOOSTED!" % [_xp_label.text, bonus_xp]
	_xp_label.modulate = Color(1.00, 0.65, 0.10)   # orange-gold for boosted


func _on_share_pressed() -> void:
	var suffix := " [BANNED FROM THEORY FEED]" if _grade_letter == "F" else ""
	var text   := "%s sighting — Grade %s (%d/100)%s\n#SIGHTING #ConspiracyCodex" % [
		_ctype.to_upper(), _grade_letter, _score, suffix,
	]

	var filename := Codex.get_value("sighting", "_last_photo_file", "") as String
	if filename != "" and FileAccess.file_exists("user://gallery/" + filename):
		var abs_path := ProjectSettings.globalize_path("user://gallery/" + filename)
		ShareManager._system_share(abs_path, text)
	else:
		ShareManager.capture_and_share(text, {
			"score": _score, "grade": _grade_letter, "game_name": "SIGHTING!",
		})


func _on_gallery_pressed() -> void:
	SceneManager.change_scene(
		"res://scenes/game_specific/gallery/gallery.tscn", 0.3
	)


func _animate_grade_reveal() -> void:
	_grade_label.pivot_offset = _grade_label.size / 2.0
	_grade_label.scale        = Vector2(0.4, 0.4)
	var pulse := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.set_parallel(true)
	pulse.tween_property(_grade_label, "scale",      Vector2(1.0, 1.0), 0.45)
	pulse.tween_property(_grade_label, "modulate:a", 1.0,               0.25)


func _grade_idx_for(score: int) -> int:
	for i in GRADE_TABLE.size():
		if score >= GRADE_TABLE[i][0]:
			return i
	return GRADE_TABLE.size() - 1
