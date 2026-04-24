## MainMenu — Hub screen: daily expedition card, player stats, navigation.
## Step 17: Entry point replacing direct field launch.
## Beautified: animated starfield + hex-grid background, styled buttons.

extends Node2D

@onready var _title_label:   Label  = $HUD/Content/TitleLabel
@onready var _cryptid_label: Label  = $HUD/Content/CryptidLabel
@onready var _zone_label:    Label  = $HUD/Content/ZoneLabel
@onready var _weather_label: Label  = $HUD/Content/WeatherLabel
@onready var _streak_label:  Label  = $HUD/Content/StatsRow/StreakLabel
@onready var _best_label:    Label  = $HUD/Content/StatsRow/BestLabel
@onready var _xp_label:      Label  = $HUD/Content/StatsRow/XPLabel
@onready var _start_btn:     Button = $HUD/Content/StartButton
@onready var _gallery_btn:   Button = $HUD/Content/ActionRow/GalleryButton
@onready var _feed_btn:      Button = $HUD/Content/ActionRow/FeedButton
@onready var _footer_label:  Label  = $HUD/Content/FooterLabel

# ── Background animation ──────────────────────────────────────────────
var _bg_t:       float             = 0.0
var _stars:      PackedVector2Array = PackedVector2Array()
var _star_sizes: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var daily      := DailyCryptid.get_today()
	var ctype      : String = daily.get("cryptid_type", "bigfoot") as String
	var zone_d     : String = daily.get("zone_display", "UNKNOWN") as String
	var weather    : String = daily.get("weather",      "clear")   as String
	var sweet_spot : int    = daily.get("sweet_spot",   3)

	_cryptid_label.text     = ctype.to_upper()
	_cryptid_label.modulate = _cryptid_color(ctype)
	_zone_label.text        = zone_d
	_weather_label.text     = "%s  ·  Sweet Spot: Zone %d" % [weather.capitalize(), sweet_spot]

	var streak   : int = Codex.get_value("sighting", "daily_streak", 0)
	var total_xp : int = Codex.get_value("sighting", "total_xp",    0)
	var best     : int = _best_score_any()

	if streak > 1:
		_streak_label.text     = "%d day streak" % streak
		_streak_label.modulate = Color(0.95, 0.65, 0.15)
	else:
		_streak_label.text     = "First run!"
		_streak_label.modulate = Color(0.75, 0.75, 0.75)

	_best_label.text  = "Best: %d/100" % best if best > 0 else "No score yet"
	_xp_label.text    = "%d XP" % total_xp

	var rep   : int = Codex.get_value("sighting", "feed_reputation", 0)
	var zones : int = (Codex.get_value("sighting", "zones_unlocked", []) as Array).size()
	_footer_label.text = "Feed Rep: %d  ·  Zones: %d / 4" % [rep, zones]

	# Button styling
	UIStyler.style_button(_start_btn,   UIStyler.ACCENT_GREEN)
	UIStyler.style_button(_gallery_btn, UIStyler.ACCENT_MUTED)
	UIStyler.style_button(_feed_btn,    UIStyler.ACCENT_MUTED)

	_start_btn.pressed.connect(func():
		SceneManager.change_scene("res://scenes/game_specific/prerun/prerun.tscn", 0.3)
	)
	_gallery_btn.pressed.connect(func():
		SceneManager.change_scene("res://scenes/game_specific/gallery/gallery.tscn", 0.3)
	)
	_feed_btn.pressed.connect(_show_feed_popup)

	AudioManager.play_music("main_menu")

	# Fade title in
	_title_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_title_label, "modulate:a", 1.0, 0.7)

	# Pre-generate starfield with a fixed seed (stable across frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x51474821
	for _i in 44:
		_stars.append(Vector2(rng.randf() * 360.0, rng.randf() * 640.0))
		_star_sizes.append(0.7 + rng.randf() * 1.3)
	queue_redraw()


func _process(delta: float) -> void:
	_bg_t += delta
	queue_redraw()


# =====================================================================
# BACKGROUND DRAWING
# =====================================================================

func _draw() -> void:
	var vp := Vector2(360.0, 640.0)
	_draw_bg_hex_grid(vp)
	_draw_starfield(vp)
	_draw_vignette(vp)
	_draw_title_underline(vp)


func _draw_bg_hex_grid(vp: Vector2) -> void:
	const R    := 26.0
	const W    := R * 1.7321   # sqrt(3) × R, flat-to-flat width for pointy-top
	const COL  := Color(0.16, 0.48, 0.20, 0.055)
	var verts  := HexGrid.hex_vertices(R)
	var cols   := int(vp.x / W) + 2
	var rows   := int(vp.y / (R * 1.5)) + 2
	for row in rows:
		for col in cols:
			var cx : float = col * W + (0.5 * W if row % 2 == 1 else 0.0)
			var cy : float = row * R * 1.5
			var pts := PackedVector2Array()
			for v in verts:
				pts.append(Vector2(cx, cy) + v)
			pts.append(pts[0])
			draw_polyline(pts, COL, 1.0)


func _draw_starfield(vp: Vector2) -> void:
	var drift := fmod(_bg_t * 9.0, vp.y)
	for i in _stars.size():
		var pos   := Vector2(_stars[i].x, fmod(_stars[i].y + drift, vp.y))
		var alpha := 0.32 + sin(_bg_t * 0.75 + _stars[i].x * 0.05) * 0.16
		draw_circle(pos, _star_sizes[i], Color(0.62, 0.88, 0.68, alpha))


func _draw_vignette(vp: Vector2) -> void:
	# Edge darkening — 4 dark strips at borders
	draw_rect(Rect2(0, 0, vp.x, 72), Color(0, 0, 0, 0.26))
	draw_rect(Rect2(0, vp.y - 72, vp.x, 72), Color(0, 0, 0, 0.26))
	draw_rect(Rect2(0, 0, 28, vp.y), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(vp.x - 28, 0, 28, vp.y), Color(0, 0, 0, 0.18))


func _draw_title_underline(vp: Vector2) -> void:
	# Subtle accent line beneath the title area
	var pulse := 0.55 + sin(_bg_t * 1.1) * 0.20
	draw_line(
		Vector2(40, 108), Vector2(vp.x - 40, 108),
		Color(0.22, 0.62, 0.28, pulse * 0.55), 1.0
	)
	# Divider above footer
	draw_line(
		Vector2(24, 600), Vector2(vp.x - 24, 600),
		Color(0.22, 0.62, 0.28, 0.22), 1.0
	)


# =====================================================================
# THEORY FEED POPUP
# =====================================================================

func _show_feed_popup() -> void:
	var rep        : int = Codex.get_value("sighting", "feed_reputation",        0)
	var global_rep : int = Codex.get_value("codex",    "theory_feed_reputation", 0)
	var photos     : int = Codex.get_value("sighting", "gallery_photos",         0)

	var panel                 := PanelContainer.new()
	panel.custom_minimum_size  = Vector2(300, 160)
	panel.position             = Vector2(30, 200)
	panel.z_index              = 20
	$HUD.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header                 := Label.new()
	header.text                 = "── THEORY FEED STATS ──"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	vbox.add_child(header)

	var rep_lbl                 := Label.new()
	rep_lbl.text                 = "Sighting Rep: %d pts" % rep
	rep_lbl.modulate             = Color(0.30, 0.90, 0.30)
	rep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rep_lbl)

	var g_rep_lbl                 := Label.new()
	g_rep_lbl.text                 = "Codex Rep: %d pts" % global_rep
	g_rep_lbl.modulate             = Color(0.60, 0.75, 0.60)
	g_rep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(g_rep_lbl)

	var photo_lbl                 := Label.new()
	photo_lbl.text                 = "Photos taken: %d" % photos
	photo_lbl.modulate             = Color(0.70, 0.70, 0.70)
	photo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(photo_lbl)

	var close_btn := Button.new()
	close_btn.text = "Close"
	UIStyler.style_button(close_btn, UIStyler.ACCENT_MUTED)
	close_btn.pressed.connect(panel.queue_free)
	vbox.add_child(close_btn)


# =====================================================================
# HELPERS
# =====================================================================

func _best_score_any() -> int:
	var best := 0
	for ctype: String in ["bigfoot", "mothman", "chupacabra", "nessie"]:
		var s: int = Codex.get_value("sighting", "best_" + ctype, 0)
		if s > best:
			best = s
	return best


static func _cryptid_color(ctype: String) -> Color:
	match ctype:
		"bigfoot":    return Color(0.45, 0.80, 0.35)
		"mothman":    return Color(0.70, 0.40, 0.95)
		"chupacabra": return Color(0.95, 0.38, 0.28)
		"nessie":     return Color(0.28, 0.68, 0.95)
		_:            return Color(0.85, 0.85, 0.85)
