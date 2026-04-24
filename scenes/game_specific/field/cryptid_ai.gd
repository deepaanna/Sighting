## CryptidAI — Procedural wander controller for the cryptid.
## A* navigation with random noise, lurking pauses, and researcher-flee behavior.
## Signals FieldPhase when it steps or enters/exits the photo-phase camera range.

class_name CryptidAI
extends Node

signal stepped(from_cell: Vector2i, to_cell: Vector2i)
signal started_lurking(cell: Vector2i)
signal entered_camera_range
signal exited_camera_range

const STEP_INTERVAL  := 1.5   # base seconds between wander steps
const LURK_CHANCE    := 0.18  # per-step probability of pausing to lurk
const LURK_DURATION  := 2.0   # seconds spent lurking before resuming
const NOISE_CHANCE   := 0.28  # probability of random neighbor instead of A* next-step
const FLEE_RADIUS    := 2     # researcher within this many hexes triggers flee
const CAMERA_RADIUS  := 3     # researcher within this range triggers photo phase

var _cell: Vector2i
var _target: Vector2i = Vector2i(-1, -1)
var _researcher_cell: Vector2i

var _blocked: Dictionary       # shared ref from FieldPhase — not owned here
var _rng: RandomNumberGenerator
var _astar: AStar2D

var _step_timer      := STEP_INTERVAL   # start delayed so no frame-1 step
var _lurking         := false
var _lurk_timer      := 0.0
var _in_camera_range := false
var _initialized     := false
var _startup_grace   := 3.0            # suppress camera-range signals for first 3 s


# =====================================================================
# SETUP  (called from FieldPhase._ready)
# =====================================================================

func setup(
	start_cell: Vector2i,
	researcher_start: Vector2i,
	blocked: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	_cell            = start_cell
	_researcher_cell = researcher_start
	_blocked         = blocked
	_rng             = rng
	_build_astar()
	_pick_wander_target()
	_initialized     = true


func get_cell() -> Vector2i:
	return _cell


## Called every frame by FieldPhase to keep the AI aware of researcher position.
## Also fires the camera-range signals so FieldPhase can reveal/conceal the sprite.
func update_researcher(cell: Vector2i) -> void:
	_researcher_cell = cell
	if _startup_grace > 0.0:
		return   # don't trigger camera range during the opening grace period
	var dist         := HexGrid.hex_distance(_cell, _researcher_cell)
	var was_in_range := _in_camera_range
	_in_camera_range  = dist <= CAMERA_RADIUS
	if _in_camera_range and not was_in_range:
		entered_camera_range.emit()
	elif not _in_camera_range and was_in_range:
		exited_camera_range.emit()


# =====================================================================
# WANDER LOOP
# =====================================================================

func _process(delta: float) -> void:
	if not _initialized:
		return

	if _startup_grace > 0.0:
		_startup_grace -= delta

	if _lurking:
		_lurk_timer -= delta
		if _lurk_timer <= 0.0:
			_lurking = false
			_pick_wander_target()
		return

	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = STEP_INTERVAL + _rng.randf_range(-0.25, 0.35)
		_wander_step()


func _wander_step() -> void:
	# Flee overrides wander when researcher is dangerously close
	if HexGrid.hex_distance(_cell, _researcher_cell) <= FLEE_RADIUS:
		_pick_flee_target()
	elif _cell == _target or not HexGrid.is_in_bounds(_target):
		_pick_wander_target()

	# Next cell: A* step or random neighbor noise
	var next_cell: Vector2i
	if _rng.randf() < NOISE_CHANCE:
		next_cell = _random_open_neighbor(_cell)
	else:
		next_cell = _astar_step(_cell, _target)

	if next_cell == _cell:
		_pick_wander_target()
		return

	# Lurk check — cryptid pauses, creating "rustling" moment
	if _rng.randf() < LURK_CHANCE:
		_lurking    = true
		_lurk_timer = LURK_DURATION + _rng.randf_range(-0.4, 0.6)
		started_lurking.emit(_cell)
		return

	var from := _cell
	_cell     = next_cell
	stepped.emit(from, _cell)


# =====================================================================
# TARGET SELECTION
# =====================================================================

func _pick_wander_target() -> void:
	# Sample random cells; bias toward ones far from researcher
	var best       := _cell
	var best_score := -1.0
	for _i in 14:
		var col := _rng.randi_range(0, HexGrid.COLS - 1)
		var row := _rng.randi_range(0, HexGrid.ROWS - 1)
		var c   := Vector2i(col, row)
		if _blocked.has(c) or c == _cell:
			continue
		var d_researcher := float(HexGrid.hex_distance(c, _researcher_cell))
		var d_current    := float(HexGrid.hex_distance(c, _cell))
		var score        := d_researcher * 0.65 + d_current * 0.35
		if score > best_score:
			best_score = score
			best       = c
	_target = best


func _pick_flee_target() -> void:
	var best      := _cell
	var best_dist := 0
	for row in HexGrid.ROWS:
		for col in HexGrid.COLS:
			var c := Vector2i(col, row)
			if _blocked.has(c):
				continue
			var d := HexGrid.hex_distance(c, _researcher_cell)
			if d > best_dist:
				best_dist = d
				best      = c
	_target = best


# =====================================================================
# PATHFINDING HELPERS
# =====================================================================

func _astar_step(from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return from
	var ids := _astar.get_id_path(_cid(from), _cid(to))
	if ids.size() < 2:
		return from
	return _cell_of(int(ids[1]))


func _random_open_neighbor(from: Vector2i) -> Vector2i:
	var valid: Array = []
	for nb in HexGrid.offset_neighbors(from):
		if HexGrid.is_in_bounds(nb) and not _blocked.has(nb):
			valid.append(nb)
	if valid.is_empty():
		return from
	return valid[_rng.randi_range(0, valid.size() - 1)]


func _build_astar() -> void:
	_astar = AStar2D.new()
	for row in HexGrid.ROWS:
		for col in HexGrid.COLS:
			var c := Vector2i(col, row)
			_astar.add_point(_cid(c), HexGrid.cell_to_pixel(c))
			if _blocked.has(c):
				_astar.set_point_disabled(_cid(c), true)
	for row in HexGrid.ROWS:
		for col in HexGrid.COLS:
			var c := Vector2i(col, row)
			for nb in HexGrid.offset_neighbors(c):
				if HexGrid.is_in_bounds(nb):
					_astar.connect_points(_cid(c), _cid(nb), false)


func _cid(c: Vector2i) -> int:
	return c.y * HexGrid.COLS + c.x

func _cell_of(id: int) -> Vector2i:
	return Vector2i(id % HexGrid.COLS, id / HexGrid.COLS)
