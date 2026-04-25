## PreRun — Expedition briefing screen between main menu and field phase.
## Shows the daily cryptid silhouette (PNG sprite or procedural fallback), zone/weather
## conditions, distance hint, and streak bonus before the player commits to a run.
## Step 18: Pre-run briefing. Beautified: scan lines, vignette, styled buttons.

extends Node2D

@onready var _target_label:    Label  = $HUD/Content/TargetLabel
@onready var _zone_label:      Label  = $HUD/Content/ZoneLabel
@onready var _weather_label:   Label  = $HUD/Content/WeatherLabel
@onready var _condition_label: Label  = $HUD/Content/ConditionLabel
@onready var _distance_label:  Label  = $HUD/Content/DistanceLabel
@onready var _streak_label:    Label  = $HUD/Content/StreakLabel
@onready var _begin_btn:       Button = $HUD/Content/BeginButton
@onready var _back_btn:        Button = $HUD/Content/BackButton

var _daily:         Dictionary = {}
var _cryptid_color: Color      = Color(0.45, 0.80, 0.35)
var _pulse_t:       float      = 0.0
var _sil_sprite:    Sprite2D   = null   # null when no PNG asset exists


# =====================================================================
# SETUP
# =====================================================================

func _ready() -> void:
	_daily = DailyCryptid.get_today()
	var ctype    : String = _daily.get("cryptid_type", "bigfoot") as String
	var zone_d   : String = _daily.get("zone_display", "UNKNOWN") as String
	var weather  : String = _daily.get("weather",      "clear")   as String
	var sweet    : int    = _daily.get("sweet_spot",   3)

	_cryptid_color = _type_color(ctype)

	_target_label.text     = ctype.to_upper()
	_target_label.modulate = _cryptid_color
	_zone_label.text       = "Zone: %s" % zone_d
	_weather_label.text    = "Weather: %s" % weather.capitalize()
	_condition_label.text  = _weather_condition(weather)
	_distance_label.text   = "Optimal range: %s" % _distance_hint(sweet)

	var streak : int = Codex.get_value("sighting", "daily_streak", 0)
	if streak > 1:
		var pct : int = int((Progression.streak_mult(streak) - 1.0) * 100.0)
		_streak_label.text     = "%d-Day Streak  ·  +%d%% XP bonus" % [streak, pct]
		_streak_label.modulate = Color(0.95, 0.65, 0.15)
		_streak_label.visible  = true

	_begin_btn.pressed.connect(func():
		AudioManager.stop_music(0.3)
		SceneManager.change_scene("res://scenes/game_specific/field/field.tscn", 0.35)
	)
	_back_btn.pressed.connect(func():
		SceneManager.change_scene("res://scenes/game_specific/menu/main_menu.tscn", 0.3)
	)

	# Button styling — BEGIN uses cryptid color, BACK is muted
	UIStyler.style_button(_begin_btn, _cryptid_color)
	UIStyler.style_button(_back_btn,  UIStyler.ACCENT_MUTED)

	_setup_silhouette_sprite(ctype)
	AudioManager.play_music("main_menu")
	queue_redraw()


func _setup_silhouette_sprite(ctype: String) -> void:
	var path := "res://resources/textures/cryptids/silhouettes/%s_silhouette.png" % ctype
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if not tex:
		return
	_sil_sprite          = Sprite2D.new()
	_sil_sprite.texture  = tex
	_sil_sprite.position = Vector2(get_viewport_rect().size.x * 0.5, 205.0)
	_sil_sprite.modulate = Color(_cryptid_color.r, _cryptid_color.g, _cryptid_color.b, 0.82)
	# Scale to fit within roughly 110px wide
	var tex_w := float(tex.get_width())
	if tex_w > 0.0:
		_sil_sprite.scale = Vector2.ONE * (110.0 / tex_w)
	add_child(_sil_sprite)


func _process(delta: float) -> void:
	_pulse_t += delta
	# Pulse the sprite alpha when we have a PNG silhouette
	if _sil_sprite:
		var pulse := 0.5 + sin(_pulse_t * 1.4) * 0.18
		_sil_sprite.modulate.a = 0.65 + pulse * 0.20
	queue_redraw()


# =====================================================================
# DRAWING — glow rings + atmosphere; procedural silhouette only as fallback
# =====================================================================

func _draw() -> void:
	var vp     := get_viewport_rect().size
	var center := Vector2(vp.x * 0.5, 205.0)
	var pulse  := 0.5 + sin(_pulse_t * 1.4) * 0.18   # oscillates 0.32 → 0.68

	_draw_scanlines(vp)
	_draw_glow_rings(center, pulse)

	if not _sil_sprite:
		var ctype: String = _daily.get("cryptid_type", "bigfoot") as String
		_draw_unknown(center, pulse) if ctype not in ["bigfoot","mothman","chupacabra","nessie"] \
			else _draw_procedural(ctype, center, pulse)

	_draw_vignette(vp)
	_draw_divider(vp)


func _draw_procedural(ctype: String, center: Vector2, pulse: float) -> void:
	match ctype:
		"bigfoot":    _draw_bigfoot(center, pulse)
		"mothman":    _draw_mothman(center, pulse)
		"chupacabra": _draw_chupacabra(center, pulse)
		"nessie":     _draw_nessie(center, pulse)


func _draw_glow_rings(center: Vector2, pulse: float) -> void:
	for i in 4:
		var radius : float = 54.0 + i * 11.0
		var alpha  : float = (0.16 - i * 0.035) * pulse
		_draw_circle_outline(
			center, radius,
			Color(_cryptid_color.r, _cryptid_color.g, _cryptid_color.b, alpha)
		)


func _draw_bigfoot(center: Vector2, pulse: float) -> void:
	var c    := Color(_cryptid_color.r, _cryptid_color.g, _cryptid_color.b, 0.82)
	var hang := 42.0 + pulse * 4.0
	draw_circle(center + Vector2(0, -44), 16, c)
	draw_rect(Rect2(center + Vector2(-26, -30), Vector2(52, 14)), c)
	draw_rect(Rect2(center + Vector2(-18, -20), Vector2(36, 36)), c)
	draw_rect(Rect2(center + Vector2(-14, 14), Vector2(12, 28)), c)
	draw_rect(Rect2(center + Vector2(2,   14), Vector2(12, 28)), c)
	draw_rect(Rect2(center + Vector2(-38, -22), Vector2(12, hang)), c)
	draw_rect(Rect2(center + Vector2(26,  -22), Vector2(12, hang)), c)


func _draw_mothman(center: Vector2, pulse: float) -> void:
	var c  := Color(_cryptid_color.r, _cryptid_color.g, _cryptid_color.b, 0.82)
	var ww := 62.0 + pulse * 10.0
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-8, -12),
		center + Vector2(-ww, -52),
		center + Vector2(-ww + 18, 18),
		center + Vector2(-12, 22),
	]), c)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(8, -12),
		center + Vector2(ww, -52),
		center + Vector2(ww - 18, 18),
		center + Vector2(12, 22),
	]), c)
	draw_circle(center + Vector2(0, -12), 12, c)
	draw_rect(Rect2(center + Vector2(-7, 0), Vector2(14, 26)), c)
	var eye_a : float = 0.7 + pulse * 0.25
	draw_circle(center + Vector2(-5, -16), 4, Color(0.95, 0.08, 0.04, eye_a))
	draw_circle(center + Vector2(5,  -16), 4, Color(0.95, 0.08, 0.04, eye_a))


func _draw_chupacabra(center: Vector2, pulse: float) -> void:
	var c := Color(_cryptid_color.r, _cryptid_color.g, _cryptid_color.b, 0.82)
	draw_circle(center + Vector2(-12, -12), 11, c)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-6, -4),
		center + Vector2(22, 2),
		center + Vector2(20, 22),
		center + Vector2(-8, 20),
	]), c)
	for i: int in 4:
		var rx : float = 12.0 + i * 4.5
		var ry : float = -14.0 + i * 2.5 - pulse * 3.0
		draw_circle(center + Vector2(rx, ry), 3.5, c)
	draw_rect(Rect2(center + Vector2(4,  18), Vector2(9, 22)), c)
	draw_rect(Rect2(center + Vector2(-9, 16), Vector2(9, 18)), c)


func _draw_nessie(center: Vector2, pulse: float) -> void:
	var c     := Color(_cryptid_color.r, _cryptid_color.g, _cryptid_color.b, 0.82)
	var bob_y : float = sin(_pulse_t * 0.9) * 4.0
	var off   := Vector2(0, bob_y)
	draw_circle(center + off + Vector2(-22, -38), 8, c)
	draw_colored_polygon(PackedVector2Array([
		center + off + Vector2(-28, -32),
		center + off + Vector2(-16, -32),
		center + off + Vector2(-4, -10),
		center + off + Vector2(-18, -10),
	]), c)
	draw_circle(center + off + Vector2(-4, 6), 20, c)
	draw_circle(center + off + Vector2(24, 4), 15, c)
	draw_circle(center + off + Vector2(44, 8), 10, c)
	var wa : float = 0.30 + pulse * 0.18
	draw_line(
		center + Vector2(-68, 26 + bob_y),
		center + Vector2(68,  26 + bob_y),
		Color(0.25, 0.55, 0.90, wa), 2.0
	)


func _draw_unknown(center: Vector2, pulse: float) -> void:
	var c := Color(_cryptid_color.r, _cryptid_color.g, _cryptid_color.b, 0.5 + pulse * 0.3)
	draw_circle(center, 38, c)


func _draw_scanlines(vp: Vector2) -> void:
	for y in range(0, int(vp.y), 5):
		draw_line(Vector2(0, float(y)), Vector2(vp.x, float(y)),
			Color(0.0, 0.0, 0.0, 0.055), 1.0)


func _draw_vignette(vp: Vector2) -> void:
	draw_rect(Rect2(0, 0, vp.x, 68), Color(0, 0, 0, 0.30))
	draw_rect(Rect2(0, vp.y - 68, vp.x, 68), Color(0, 0, 0, 0.30))
	draw_rect(Rect2(0, 0, 26, vp.y), Color(0, 0, 0, 0.20))
	draw_rect(Rect2(vp.x - 26, 0, 26, vp.y), Color(0, 0, 0, 0.20))


func _draw_divider(vp: Vector2) -> void:
	# Separator line between silhouette area and info block
	var alpha := 0.25 + sin(_pulse_t * 0.9) * 0.08
	draw_line(
		Vector2(32, 344), Vector2(vp.x - 32, 344),
		Color(_cryptid_color.r, _cryptid_color.g, _cryptid_color.b, alpha), 1.0
	)


func _draw_circle_outline(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 24:
		var angle := TAU * i / 24.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	pts.append(pts[0])
	draw_polyline(pts, color, 1.5)


# =====================================================================
# STATIC HELPERS
# =====================================================================

static func _weather_condition(weather: String) -> String:
	match weather:
		"fog":   return "Reduced visibility. Cryptid harder to\nspot — closer approach required."
		"rain":  return "Rain washes footprints faster.\nCryptid moves more unpredictably."
		"night": return "Night expedition. Cryptid active but\nharder to photograph clearly."
		_:       return "Clear conditions. Ideal photography\nweather. Full proximity range active."


static func _distance_hint(sweet_spot: int) -> String:
	if sweet_spot <= 2:
		return "VERY CLOSE  (high blur risk)"
	elif sweet_spot <= 3:
		return "CLOSE  (moderate risk)"
	elif sweet_spot <= 4:
		return "MEDIUM  (balanced)"
	else:
		return "DISTANT  (safer approach)"


static func _type_color(ctype: String) -> Color:
	match ctype:
		"bigfoot":    return Color(0.45, 0.80, 0.35)
		"mothman":    return Color(0.70, 0.40, 0.95)
		"chupacabra": return Color(0.95, 0.38, 0.28)
		"nessie":     return Color(0.28, 0.68, 0.95)
		_:            return Color(0.82, 0.82, 0.82)
