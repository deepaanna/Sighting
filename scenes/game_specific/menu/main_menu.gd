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
	var zones      : int = (Codex.get_value("sighting", "zones_unlocked", []) as Array).size()

	# Full-screen dim overlay — blocks all input to the menu behind it
	var overlay              := ColorRect.new()
	overlay.color             = Color(0.0, 0.0, 0.0, 0.78)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter      = Control.MOUSE_FILTER_STOP
	overlay.z_index           = 40
	$HUD.add_child(overlay)

	# Centered modal card
	var card                  := PanelContainer.new()
	card.custom_minimum_size   = Vector2(280, 0)
	card.position              = Vector2(40, 190)
	card.z_index               = 41
	var bg                    := StyleBoxFlat.new()
	bg.bg_color                = Color(0.04, 0.09, 0.05, 0.98)
	bg.set_border_width_all(2)
	bg.border_color            = Color(0.22, 0.62, 0.28, 0.85)
	bg.set_corner_radius_all(6)
	bg.content_margin_left     = 20.0
	bg.content_margin_right    = 20.0
	bg.content_margin_top      = 18.0
	bg.content_margin_bottom   = 18.0
	card.add_theme_stylebox_override("panel", bg)
	$HUD.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Dismiss callback — frees both overlay and card
	var dismiss := func():
		overlay.queue_free()
		card.queue_free()

	# Tap the dim overlay to close
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			dismiss.call()
	)

	# Header
	var title                  := Label.new()
	title.text                  = "THEORY FEED"
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.modulate              = Color(0.30, 0.90, 0.30)
	vbox.add_child(title)

	vbox.add_child(_modal_divider())

	# Stat rows
	_add_stat_row(vbox, "Sighting Rep",  "%d pts" % rep,        Color(0.30, 0.90, 0.30))
	_add_stat_row(vbox, "Codex Rep",     "%d pts" % global_rep, Color(0.55, 0.80, 0.60))
	_add_stat_row(vbox, "Photos taken",  str(photos),           Color(0.72, 0.72, 0.72))
	_add_stat_row(vbox, "Zones found",   "%d / 4" % zones,      Color(0.72, 0.72, 0.72))

	vbox.add_child(_modal_divider())

	# Close button
	var close_btn                   := Button.new()
	close_btn.text                   = "CLOSE"
	close_btn.custom_minimum_size    = Vector2(0, 42)
	UIStyler.style_button(close_btn, UIStyler.ACCENT_MUTED)
	close_btn.pressed.connect(dismiss)
	vbox.add_child(close_btn)


func _add_stat_row(parent: VBoxContainer, label: String, value: String, val_color: Color) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl                    := Label.new()
	lbl.text                    = label
	lbl.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate                = Color(0.62, 0.62, 0.62)
	row.add_child(lbl)

	var val                    := Label.new()
	val.text                    = value
	val.horizontal_alignment    = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 13)
	val.modulate                = val_color
	row.add_child(val)


func _modal_divider() -> HSeparator:
	var sep              := HSeparator.new()
	var style            := StyleBoxFlat.new()
	style.bg_color        = Color(0.22, 0.42, 0.24, 0.55)
	style.content_margin_top    = 1.0
	style.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", style)
	return sep


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
