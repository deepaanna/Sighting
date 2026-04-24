## FieldPhase — The 60-second field exploration phase.
## Manages the 7x7 hex grid, researcher movement, CryptidAI, and proximity HUD.
## Step 2: hex grid, coordinates, tap-to-move.
## Step 3: cryptid AI wiring, footprint hints, rustling indicator, proximity.
## Step 4: ProximitySystem vibration, terrain-typed footprints, proximity aura.

extends Node2D

signal photo_phase_triggered(researcher_cell: Vector2i)

enum Terrain { GRASS, FOREST, SWAMP, ROCK }

const TERRAIN_COLORS: Dictionary = {
	Terrain.GRASS:  Color(0.22, 0.48, 0.22),
	Terrain.FOREST: Color(0.12, 0.32, 0.12),
	Terrain.SWAMP:  Color(0.22, 0.35, 0.18),
	Terrain.ROCK:   Color(0.38, 0.35, 0.30),
}
const OUTLINE_COLOR    := Color(0.0, 0.0, 0.0, 0.55)
const HOVER_COLOR      := Color(1.0, 1.0, 1.0, 0.18)
const FOOTPRINT_COLOR  := Color(0.55, 0.38, 0.18)
const SESSION_TIME     := 60.0
const MAX_FOOTPRINTS   := 10
const FOOTPRINT_FADE   := 18.0   # seconds until a footprint disappears
const RUSTLING_SHOW_RADIUS := 4  # only show rustling hint if cryptid within N hexes

# --- Node refs ---
@onready var _researcher:   Node2D          = $Researcher
@onready var _cryptid:      Node2D          = $Cryptid
@onready var _cryptid_ai:   CryptidAI       = $CryptidAI
@onready var _prox_sys:     ProximitySystem = $ProximitySystem
@onready var _timer_label:  Label           = $HUD/TopBar/TimerLabel
@onready var _zone_label:   Label           = $HUD/TopBar/ZoneLabel
@onready var _prox_bar:     ProgressBar     = $HUD/BottomBar/ProximityBar
@onready var _prox_label:   Label           = $HUD/BottomBar/ProxLabel
@onready var _hint_label:   Label           = $HUD/BottomBar/HintLabel

# --- Grid state ---
var _grid_offset:   Vector2
var _terrain:       Dictionary = {}   # Vector2i -> Terrain
var _blocked:       Dictionary = {}   # Vector2i -> true
var _astar:         AStar2D

# --- Session state ---
var _elapsed:         float    = 0.0
var _running:         bool     = false
var _hovered_cell:    Vector2i = Vector2i(-1, -1)
var _pending_target:  Vector2i = Vector2i(-1, -1)

# --- Footprints ---
# Each entry: { cell: Vector2i, dir: Vector2, t: float, terrain: int }
var _footprints: Array = []

# --- Rustling hint ---
var _rustling_active: bool    = false
var _rustling_timer:  float   = 0.0

# --- RNG (seeded daily so each day has a consistent layout + spawn) ---
var _rng: RandomNumberGenerator

# --- Daily rotation ---
var _daily:       Dictionary = {}
var _sweet_spot:  int        = 3

# --- Photo phase guard ---
var _photo_triggered: bool = false

# --- Retry-ad guard (prevents double rewarded_failed connections) ---
var _retry_offered: bool = false

# --- Proximity aura animation ---
# True when proximity is high enough to need per-frame redraws for the pulse.
var _aura_active: bool = false

# --- Heartbeat ---
var _heartbeat_timer: float = 99.0   # inactive until proximity > 0.3

# Exposed for external systems
var proximity: float = 0.0 : set = _set_proximity


# =====================================================================
# SETUP
# =====================================================================

func _ready() -> void:
	_rng      = RandomNumberGenerator.new()
	_rng.seed = Codex.get_daily_seed() ^ 0xC0DEC0DE

	_compute_grid_offset()
	_generate_terrain()
	_build_astar_and_setup_ai()

	_researcher.position = _cell_to_world(Vector2i(3, 3))
	_researcher.step_complete.connect(_on_step_complete)

	_cryptid_ai.stepped.connect(_on_cryptid_stepped)
	_cryptid_ai.started_lurking.connect(_on_cryptid_lurking)
	_cryptid_ai.entered_camera_range.connect(_on_entered_camera_range)
	_cryptid_ai.exited_camera_range.connect(_on_exited_camera_range)

	_prox_sys.level_changed.connect(_on_proximity_level_changed)
	UIStyler.style_progress_bar(_prox_bar)

	_daily            = DailyCryptid.get_today()
	_sweet_spot       = _daily.get("sweet_spot", 3)
	_cryptid.setup(_daily.get("cryptid_type", "bigfoot") as String)
	_zone_label.text  = _daily.get("zone_display", "UNKNOWN")
	_hint_label.text  = ""
	_running          = true
	queue_redraw()
	SightingCodex.on_game_start()
	_check_feed_ban()
	_update_daily_streak()
	AudioManager.play_music("field_%s" % _daily.get("zone", "pacific_nw"))
	if not Codex.get_value("sighting", "tutorial_shown", false):
		Codex.set_value("sighting", "tutorial_shown", true)
		_show_tutorial()


func _show_tutorial() -> void:
	var hints: Array = [
		"TAP any hex to move your researcher.",
		"The proximity bar shows how close\nthe cryptid is. Follow the signal!",
		"The dashed green ring = ideal shot range\n(%d hexes). Stop when the cryptid enters it\nfor the clearest photo!" % _sweet_spot,
	]
	var delay := 1.0
	for hint: String in hints:
		var lbl              := Label.new()
		lbl.text              = hint
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode     = TextServer.AUTOWRAP_WORD
		lbl.size              = Vector2(300, 80)
		lbl.position          = Vector2(30, 260)
		lbl.z_index           = 30
		lbl.modulate          = Color(1, 1, 1, 0)
		var bg               := ColorRect.new()
		bg.color              = Color(0.0, 0.0, 0.0, 0.72)
		bg.size               = Vector2(300, 80)
		bg.mouse_filter       = Control.MOUSE_FILTER_IGNORE
		lbl.add_child(bg)
		lbl.move_child(bg, 0)
		$HUD.add_child(lbl)

		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.3)
		tw.tween_interval(2.8)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.3)
		tw.tween_callback(lbl.queue_free)
		delay += 4.0


func _update_daily_streak() -> void:
	var today_idx  : int = Codex.get_daily_index()
	var last_idx   : int = Codex.get_value("sighting", "last_play_day", -1)
	var streak     : int = Codex.get_value("sighting", "daily_streak",   0)
	if today_idx == last_idx + 1:
		streak += 1
	elif today_idx != last_idx:
		streak = 1
	Codex.set_value("sighting", "daily_streak",  streak)
	Codex.set_value("sighting", "last_play_day", today_idx)


func _check_feed_ban() -> void:
	if not Codex.get_value("sighting", "_feed_banned", false):
		return
	Codex.set_value("sighting", "_feed_banned", false)
	var lbl        := Label.new()
	lbl.text        = "⚠  SHADOW BANNED\nTheory Feed suspended this run"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position    = Vector2(0, 48)
	lbl.size        = Vector2(360, 64)
	lbl.modulate    = Color(0.90, 0.20, 0.15)
	$HUD.add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


func _compute_grid_offset() -> void:
	var vp    := get_viewport_rect().size
	var hw    := HexGrid.HEX_SIZE * sqrt(3.0)
	var max_x := hw * (HexGrid.COLS - 1 + 0.5)
	var max_y := HexGrid.HEX_SIZE * 1.5 * (HexGrid.ROWS - 1)
	_grid_offset = Vector2(
		(vp.x - max_x) * 0.5,
		48.0 + ((vp.y - 96.0) - max_y) * 0.5
	)


func _generate_terrain() -> void:
	var terrain_rng       := RandomNumberGenerator.new()
	terrain_rng.seed      = Codex.get_daily_seed()
	for row in HexGrid.ROWS:
		for col in HexGrid.COLS:
			var cell := Vector2i(col, row)
			var r    := terrain_rng.randi_range(0, 9)
			if r < 5:
				_terrain[cell] = Terrain.GRASS
			elif r < 7:
				_terrain[cell] = Terrain.FOREST
			elif r < 9:
				_terrain[cell] = Terrain.SWAMP
			else:
				_terrain[cell] = Terrain.ROCK
				_blocked[cell] = true


func _build_astar_and_setup_ai() -> void:
	var astar := AStar2D.new()
	for row in HexGrid.ROWS:
		for col in HexGrid.COLS:
			var cell := Vector2i(col, row)
			var id   := _cell_id(cell)
			astar.add_point(id, HexGrid.cell_to_pixel(cell))
			if _blocked.has(cell):
				astar.set_point_disabled(id, true)
	for row in HexGrid.ROWS:
		for col in HexGrid.COLS:
			var cell := Vector2i(col, row)
			for nb in HexGrid.offset_neighbors(cell):
				if HexGrid.is_in_bounds(nb):
					astar.connect_points(_cell_id(cell), _cell_id(nb), false)

	# Keep a local reference for researcher pathfinding
	_astar = astar

	# Spawn cryptid far from researcher start (3,3), minimum 4 hexes away
	var spawn := _pick_cryptid_spawn()
	_cryptid.position = _cell_to_world(spawn)

	_cryptid_ai.setup(spawn, Vector2i(3, 3), _blocked, _rng)


func _pick_cryptid_spawn() -> Vector2i:
	for _i in 30:
		var col := _rng.randi_range(0, HexGrid.COLS - 1)
		var row := _rng.randi_range(0, HexGrid.ROWS - 1)
		var c   := Vector2i(col, row)
		if not _blocked.has(c) and HexGrid.hex_distance(c, Vector2i(3, 3)) >= 4:
			return c
	return Vector2i(0, 0)  # fallback corner


# =====================================================================
# GAME LOOP
# =====================================================================

func _process(delta: float) -> void:
	if not _running:
		return

	_elapsed       += delta
	var remaining  := maxf(0.0, SESSION_TIME - _elapsed)
	_timer_label.text = "0:%02d" % int(remaining)

	# Feed researcher position to AI every frame (drives flee + camera-range)
	_cryptid_ai.update_researcher(_researcher.get_cell())

	# Update proximity from hex distance; drive ProximitySystem and aura
	var dist     := HexGrid.hex_distance(_researcher.get_cell(), _cryptid_ai.get_cell())
	var max_dist := HexGrid.COLS   # 7 — effective diameter of the 7×7 grid
	proximity = 1.0 - clampf(float(dist) / float(max_dist), 0.0, 1.0)
	_prox_sys.update(proximity)

	# Range guidance hint — only when close enough to be meaningful
	if not _rustling_active:
		_hint_label.text = _range_hint(dist)

	var want_aura := proximity > 0.3
	if want_aura != _aura_active:
		_aura_active = want_aura
	if _aura_active:
		queue_redraw()   # keep animating the pulse ring

	_tick_heartbeat(delta)

	var weather := _daily.get("weather", "clear") as String
	if weather == "rain":
		queue_redraw()   # rain drops animate every frame

	# Tick down rustling hint
	if _rustling_active:
		_rustling_timer -= delta
		if _rustling_timer <= 0.0:
			_rustling_active = false
			_hint_label.text = ""

	if remaining <= 0.0:
		_running = false
		_on_time_expired()


# =====================================================================
# INPUT
# =====================================================================

func _input(event: InputEvent) -> void:
	if not _running:
		return

	var pressed    := false
	var screen_pos := Vector2.ZERO

	if event is InputEventScreenTouch and event.pressed:
		pressed    = true
		screen_pos = event.position
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed    = true
		screen_pos = event.position
	elif event is InputEventMouseMotion:
		_hovered_cell = HexGrid.pixel_to_cell(to_local(event.position) - _grid_offset)
		queue_redraw()

	if pressed:
		var local  := to_local(screen_pos) - _grid_offset
		var tapped := HexGrid.pixel_to_cell(local)
		if HexGrid.is_in_bounds(tapped) and not _blocked.has(tapped):
			_pending_target = tapped
			_try_step()


func _try_step() -> void:
	if _pending_target == Vector2i(-1, -1):
		return
	var from: Vector2i = _researcher.get_cell()
	if _pending_target == from:
		_pending_target = Vector2i(-1, -1)
		return
	var id_path := _astar.get_id_path(_cell_id(from), _cell_id(_pending_target))
	if id_path.size() < 2:
		_pending_target = Vector2i(-1, -1)
		return
	var next_cell := _id_to_cell(int(id_path[1]))
	_researcher.move_to(next_cell, _cell_to_world(next_cell))
	queue_redraw()


func _on_step_complete(_cell: Vector2i) -> void:
	_spawn_step_dust(_researcher.position)
	_prox_sys.on_researcher_stepped(proximity)
	if _pending_target != Vector2i(-1, -1) and _pending_target != _researcher.get_cell():
		_try_step()
	else:
		_pending_target = Vector2i(-1, -1)


# =====================================================================
# CRYPTID AI SIGNAL HANDLERS
# =====================================================================

func _on_cryptid_stepped(from: Vector2i, to: Vector2i) -> void:
	var dir     := (HexGrid.cell_to_pixel(to) - HexGrid.cell_to_pixel(from)).normalized()
	var terrain: int = _terrain.get(from, Terrain.GRASS)
	_footprints.append({"cell": from, "dir": dir, "t": _elapsed, "terrain": terrain})
	if _footprints.size() > MAX_FOOTPRINTS:
		_footprints.pop_front()
	_cryptid.move_to(_cell_to_world(to))
	queue_redraw()


func _on_cryptid_lurking(cell: Vector2i) -> void:
	var dist := HexGrid.hex_distance(_researcher.get_cell(), cell)
	if dist <= RUSTLING_SHOW_RADIUS:
		_rustling_active  = true
		_rustling_timer   = 3.5
		_hint_label.text  = "Something is moving nearby..."
		AudioManager.play_sfx("cryptid_nearby", -4.0)
	queue_redraw()


func _on_time_expired() -> void:
	# Save a zero-score run so the result screen displays correctly if skipped
	Codex.set_value("sighting", "_last_score",       0)
	Codex.set_value("sighting", "_last_cryptid",     _daily.get("cryptid_type", "bigfoot"))
	Codex.set_value("sighting", "_last_zone",        _daily.get("zone",          "pacific_nw"))
	Codex.set_value("sighting", "_last_weather",     _daily.get("weather",       "clear"))
	Codex.set_value("sighting", "_last_is_new_best", false)

	# Second expiry (timer reset after successful retry): skip straight to result
	# so we don't stack a second rewarded_failed connection.
	if _retry_offered:
		SceneManager.change_scene("res://scenes/game_specific/result/result.tscn", 0.4)
		return
	_retry_offered = true

	# Build a "retry?" panel on the HUD
	var panel                     := PanelContainer.new()
	panel.custom_minimum_size      = Vector2(280, 100)
	panel.position                 = Vector2(40, 240)
	panel.z_index                  = 20
	$HUD.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var lbl                    := Label.new()
	lbl.text                    = "TIME'S UP!\nWatch an ad to try again?"
	lbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode           = TextServer.AUTOWRAP_WORD
	vbox.add_child(lbl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var watch_btn                   := Button.new()
	watch_btn.text                   = "▶  Watch Ad"
	watch_btn.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	row.add_child(watch_btn)

	var skip_btn                    := Button.new()
	skip_btn.text                    = "Skip"
	skip_btn.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	row.add_child(skip_btn)

	UIStyler.style_button(watch_btn, UIStyler.ACCENT_GREEN)
	UIStyler.style_button(skip_btn,  UIStyler.ACCENT_MUTED)

	watch_btn.pressed.connect(func():
		if is_instance_valid(panel):
			panel.queue_free()
		AdManager.show_rewarded("daily_retry", func():
			if is_instance_valid(self):
				_elapsed         = 0.0
				_photo_triggered = false
				_running         = true
		)
		AdManager.rewarded_failed.connect(
			func(_p: String):
				SceneManager.change_scene(
					"res://scenes/game_specific/result/result.tscn", 0.4
				),
			CONNECT_ONE_SHOT
		)
	)
	skip_btn.pressed.connect(func():
		if is_instance_valid(panel):
			panel.queue_free()
		SceneManager.change_scene("res://scenes/game_specific/result/result.tscn", 0.4)
	)


func _on_entered_camera_range() -> void:
	_cryptid.reveal()
	if not _photo_triggered:
		_photo_triggered = true
		photo_phase_triggered.emit(_researcher.get_cell())
		_running = false
		AudioManager.stop_music(0.5)
		await get_tree().create_timer(0.75).timeout
		_launch_camera_phase()


func _launch_camera_phase() -> void:
	var dist := HexGrid.hex_distance(_researcher.get_cell(), _cryptid_ai.get_cell())
	CameraPhase.session = {
		"cryptid_type": _daily.get("cryptid_type", "bigfoot"),
		"hex_distance": dist,
		"zone":         _daily.get("zone",          "pacific_nw"),
		"weather":      _daily.get("weather",       "clear"),
		"sweet_spot":   _daily.get("sweet_spot",    3),
	}
	SceneManager.change_scene(
		"res://scenes/game_specific/camera/camera_phase.tscn", 0.35
	)


func _on_exited_camera_range() -> void:
	_cryptid.conceal()
	_photo_triggered = false   # allow re-trigger if player re-approaches


func _on_proximity_level_changed(_old: int, new_level: int) -> void:
	# Update the proximity bar colour to reflect urgency
	var bar_color: Color
	match new_level:
		0: bar_color = Color(0.3, 0.6, 0.3)
		1: bar_color = Color(0.5, 0.7, 0.2)
		2: bar_color = Color(0.8, 0.75, 0.1)
		3: bar_color = Color(0.9, 0.45, 0.05)
		_: bar_color = Color(0.95, 0.15, 0.10)
	# StyleBoxFlat lets us tint the fill at runtime
	var style := StyleBoxFlat.new()
	style.bg_color = bar_color
	_prox_bar.add_theme_stylebox_override("fill", style)


# =====================================================================
# PUBLIC API
# =====================================================================

func set_cell_blocked(cell: Vector2i, blocked: bool) -> void:
	var id := _cell_id(cell)
	if blocked:
		_blocked[cell]  = true
		_astar.set_point_disabled(id, true)
	else:
		_blocked.erase(cell)
		_astar.set_point_disabled(id, false)
	queue_redraw()


func cell_world_pos(cell: Vector2i) -> Vector2:
	return _cell_to_world(cell)


func get_researcher_cell() -> Vector2i:
	return _researcher.get_cell()


# =====================================================================
# PROXIMITY SETTER
# =====================================================================

func _range_hint(dist: int) -> String:
	if dist <= _sweet_spot - 2:
		return "TOO CLOSE — back up for a cleaner shot"
	elif dist == _sweet_spot - 1:
		return "A little close — back up one hex"
	elif dist <= _sweet_spot + 1:
		return "GOOD RANGE — camera ready!"
	elif dist <= _sweet_spot + 3:
		return "Getting closer... ideal: %d hex away" % _sweet_spot
	else:
		return "Ideal shot range: %d hex away" % _sweet_spot


func _set_proximity(value: float) -> void:
	proximity      = clampf(value, 0.0, 1.0)
	_prox_bar.value = proximity * 100.0
	var pct        := int(proximity * 100)
	if pct < 20:
		_prox_label.text = "No signal"
	elif pct < 45:
		_prox_label.text = "Something nearby..."
	elif pct < 70:
		_prox_label.text = "Close!"
	else:
		_prox_label.text = "IT'S HERE"


# =====================================================================
# HEARTBEAT
# =====================================================================

func _tick_heartbeat(delta: float) -> void:
	if proximity <= 0.3:
		_heartbeat_timer = 99.0
		return
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		AudioManager.play_sfx("heartbeat", -6.0)
		var t := clampf((proximity - 0.3) / 0.7, 0.0, 1.0)
		_heartbeat_timer = lerpf(1.8, 0.35, t)


# =====================================================================
# DRAWING
# =====================================================================

func _draw() -> void:
	_draw_hud_bars()
	var inner_r := HexGrid.HEX_SIZE - 1.5
	var vt      := HexGrid.hex_vertices(inner_r)

	# --- Hex tiles ---
	for row in HexGrid.ROWS:
		for col in HexGrid.COLS:
			var cell   := Vector2i(col, row)
			var center := HexGrid.cell_to_pixel(cell) + _grid_offset
			var fill: Color = TERRAIN_COLORS.get(_terrain.get(cell, Terrain.GRASS), TERRAIN_COLORS[Terrain.GRASS])

			if _blocked.has(cell):
				fill = fill.darkened(0.4)

			var poly := _shifted(vt, center)
			draw_colored_polygon(poly, fill)

			if cell == _hovered_cell and not _blocked.has(cell):
				draw_colored_polygon(poly, HOVER_COLOR)

			var outline := PackedVector2Array(poly)
			outline.append(poly[0])
			draw_polyline(outline, OUTLINE_COLOR, 1.2)

	# --- Footprints ---
	for fp in _footprints:
		var age   : float = _elapsed - float(fp["t"])
		var alpha : float = clampf(1.0 - age / FOOTPRINT_FADE, 0.0, 1.0)
		if alpha <= 0.01:
			continue
		var center := HexGrid.cell_to_pixel(fp["cell"]) + _grid_offset
		_draw_footprint(center, fp["dir"], alpha, fp["terrain"])

	# --- Researcher cell highlight + proximity aura ---
	var r_cell: Vector2i = _researcher.get_cell()
	if HexGrid.is_in_bounds(r_cell):
		var center := HexGrid.cell_to_pixel(r_cell) + _grid_offset

		# Proximity aura: animated expanding hex ring
		if _aura_active:
			_draw_proximity_aura(center, proximity)

		var poly   := _shifted(vt, center)
		draw_colored_polygon(poly, Color(1.0, 0.95, 0.2, 0.18))
		var outline := PackedVector2Array(poly)
		outline.append(poly[0])
		draw_polyline(outline, Color(1.0, 0.95, 0.2, 0.70), 1.5)

	_draw_range_guide()
	_draw_weather()


func _draw_range_guide() -> void:
	if not HexGrid.is_in_bounds(_researcher.get_cell()):
		return
	var center  := HexGrid.cell_to_pixel(_researcher.get_cell()) + _grid_offset
	var hw      := HexGrid.HEX_SIZE * sqrt(3.0)   # center-to-center distance per hex step
	var ideal_r := float(_sweet_spot) * hw

	# Outer ideal-range ring — dashed green
	_draw_dashed_circle(center, ideal_r, Color(0.25, 0.88, 0.38, 0.30), 48)

	# Inner too-close ring — dashed orange (only when sweet_spot > 1)
	if _sweet_spot > 1:
		var close_r := float(_sweet_spot - 1) * hw
		_draw_dashed_circle(center, close_r, Color(0.90, 0.48, 0.08, 0.22), 36)

	# "IDEAL" label floating just above the top of the ring
	var lp := center + Vector2(0.0, -ideal_r - 5.0)
	draw_string(
		ThemeDB.fallback_font, lp,
		"IDEAL  %d HEX" % _sweet_spot,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 8,
		Color(0.30, 0.92, 0.40, 0.55)
	)


func _draw_dashed_circle(center: Vector2, radius: float, color: Color, segs: int) -> void:
	for i: int in segs:
		if i % 3 == 2:
			continue   # skip every third segment → dashed look
		var a0 := TAU * float(i)     / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		draw_line(
			center + Vector2(cos(a0), sin(a0)) * radius,
			center + Vector2(cos(a1), sin(a1)) * radius,
			color, 1.2
		)


func _draw_hud_bars() -> void:
	var vp := get_viewport_rect().size
	# Top bar: dark semi-transparent backing + accent separator line
	draw_rect(Rect2(0, 0, vp.x, 42), Color(0.03, 0.06, 0.04, 0.88))
	draw_line(Vector2(0, 41.5), Vector2(vp.x, 41.5),
		Color(0.20, 0.52, 0.22, 0.60), 1.0)
	# Bottom bar: same
	draw_rect(Rect2(0, 582, vp.x, vp.y - 582), Color(0.03, 0.06, 0.04, 0.88))
	draw_line(Vector2(0, 582.5), Vector2(vp.x, 582.5),
		Color(0.20, 0.52, 0.22, 0.60), 1.0)


func _draw_weather() -> void:
	match _daily.get("weather", "clear") as String:
		"fog":   _draw_fog()
		"rain":  _draw_rain()
		"night": _draw_night()


func _draw_fog() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.82, 0.86, 0.90, 0.24))


func _draw_rain() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.55, 0.62, 0.75, 0.14))
	for i in 32:
		var x   := fmod(float(i * 41 + 19), vp.x)
		var spd := 160.0 + float(i % 6) * 30.0
		var y   := fmod(_elapsed * spd + float(i * 79), vp.y)
		draw_line(
			Vector2(x, y),
			Vector2(x - 1.5, y + 9.0),
			Color(0.60, 0.72, 0.90, 0.42),
			1.0
		)


func _draw_night() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.04, 0.18, 0.42))


func _draw_footprint(center: Vector2, dir: Vector2, alpha: float, terrain: int) -> void:
	match terrain:
		Terrain.FOREST: _draw_broken_branch(center, dir, alpha)
		Terrain.SWAMP:  _draw_swamp_ripple(center, alpha)
		_:              _draw_arrow_footprint(center, dir, alpha)


## Grass / default — directional arrow + heel dot.
func _draw_arrow_footprint(center: Vector2, dir: Vector2, alpha: float) -> void:
	var color := Color(FOOTPRINT_COLOR.r, FOOTPRINT_COLOR.g, FOOTPRINT_COLOR.b, alpha * 0.85)
	var n    := dir.normalized()
	var perp := Vector2(-n.y, n.x)
	var tip  := center + n * 7.0
	var bl   := center - n * 2.0 + perp * 4.5
	var br   := center - n * 2.0 - perp * 4.5
	draw_colored_polygon(PackedVector2Array([tip, bl, br]), color)
	draw_circle(center - n * 5.0, 2.0, color)


## Forest — two crossed lines suggesting a snapped branch.
func _draw_broken_branch(center: Vector2, dir: Vector2, alpha: float) -> void:
	var color := Color(0.45, 0.30, 0.10, alpha * 0.9)
	var n     := dir.normalized()
	var perp  := Vector2(-n.y, n.x)
	# Main branch stub in travel direction
	draw_line(center - n * 6.0, center + n * 6.0, color, 2.0)
	# Snapped cross-piece
	var mid := center + n * 1.5
	draw_line(mid - perp * 5.0, mid + perp * 3.0, color, 1.5)
	# Break-point notch
	draw_circle(mid, 1.8, Color(0.6, 0.4, 0.15, alpha))


## Swamp — concentric circle ripple suggesting disturbed water/mud.
func _draw_swamp_ripple(center: Vector2, alpha: float) -> void:
	for i in 3:
		var r     := 3.5 + i * 3.5
		var a     := alpha * (0.75 - i * 0.22)
		var color := Color(0.30, 0.50, 0.25, a)
		# Draw circle outline via polyline
		var pts := PackedVector2Array()
		for s in 16:
			var angle := TAU * s / 16.0
			pts.append(center + Vector2(cos(angle), sin(angle)) * r)
		pts.append(pts[0])
		draw_polyline(pts, color, 1.2)


## Expanding hex ring that pulses outward from the researcher cell.
## Colour shifts green → yellow → red with increasing proximity.
func _draw_proximity_aura(center: Vector2, prox: float) -> void:
	var t       := fmod(Time.get_ticks_msec() / 900.0, 1.0)   # 0→1 cycle ~0.9 s
	var radius  := HexGrid.HEX_SIZE * (1.1 + t * prox * 1.6)
	var alpha   := (1.0 - t) * prox * 0.55
	if alpha < 0.02:
		return
	var hue: float = lerp(0.33, 0.02, prox)  # green → red
	var color   := Color.from_hsv(hue, 0.9, 1.0, alpha)
	var verts   := HexGrid.hex_vertices(radius)
	var shifted := PackedVector2Array()
	for v in verts:
		shifted.append(center + v)
	shifted.append(shifted[0])
	draw_polyline(shifted, color, 2.0)


# =====================================================================
# HELPERS
# =====================================================================

func _spawn_step_dust(world_pos: Vector2) -> void:
	var p                       := CPUParticles2D.new()
	p.position                   = world_pos
	p.amount                     = 7
	p.lifetime                   = 0.55
	p.one_shot                   = true
	p.explosiveness              = 0.95
	p.emission_shape             = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius     = 3.5
	p.direction                  = Vector2(0.0, -1.0)
	p.spread                     = 55.0
	p.gravity                    = Vector2(0.0, 95.0)
	p.initial_velocity_min       = 20.0
	p.initial_velocity_max       = 42.0
	p.scale_amount_min           = 1.5
	p.scale_amount_max           = 3.5
	p.color                      = Color(0.58, 0.44, 0.22, 0.72)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _shifted(vt: PackedVector2Array, center: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in vt:
		out.append(center + v)
	return out


func _cell_id(cell: Vector2i) -> int:
	return cell.y * HexGrid.COLS + cell.x

func _id_to_cell(id: int) -> Vector2i:
	return Vector2i(id % HexGrid.COLS, id / int(HexGrid.COLS))

func _cell_to_world(cell: Vector2i) -> Vector2:
	return HexGrid.cell_to_pixel(cell) + _grid_offset
