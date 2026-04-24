## HexGrid — Static utility class for hex coordinate math.
## Uses pointy-top orientation with odd-r offset coordinates.
## Reference: redblobgames.com/grids/hexagons

class_name HexGrid

const COLS := 7
const ROWS := 7
const HEX_SIZE := 22.0  # pointy-top radius (center to corner)

# Six neighbor directions in cube space (pointy-top)
const CUBE_DIRS: Array = [
	Vector3i(1, 0, -1), Vector3i(1, -1, 0), Vector3i(0, -1, 1),
	Vector3i(-1, 0, 1), Vector3i(-1, 1, 0), Vector3i(0, 1, -1)
]


# =====================================================================
# COORDINATE CONVERSION: Offset (col, row) <-> Cube (q, r, s)
# Odd-r offset: odd rows shift right by 0.5
# =====================================================================

static func offset_to_cube(col: int, row: int) -> Vector3i:
	var q := col - (row - (row & 1)) / 2
	var r := row
	return Vector3i(q, r, -q - r)

static func cube_to_offset(cube: Vector3i) -> Vector2i:
	var col := cube.x + (cube.y - (cube.y & 1)) / 2
	return Vector2i(col, cube.y)

static func offset_to_cube_v(cell: Vector2i) -> Vector3i:
	return offset_to_cube(cell.x, cell.y)


# =====================================================================
# DISTANCE
# =====================================================================

static func cube_distance(a: Vector3i, b: Vector3i) -> int:
	return (abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)) / 2

static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	return cube_distance(offset_to_cube_v(a), offset_to_cube_v(b))


# =====================================================================
# NEIGHBORS
# =====================================================================

static func cube_neighbors(cube: Vector3i) -> Array:
	var result: Array = []
	for d in CUBE_DIRS:
		result.append(cube + d)
	return result

static func offset_neighbors(cell: Vector2i) -> Array:
	var result: Array = []
	for neighbor_cube in cube_neighbors(offset_to_cube_v(cell)):
		result.append(cube_to_offset(neighbor_cube))
	return result


# =====================================================================
# PIXEL CONVERSIONS
# =====================================================================

## Hex cell (col, row) center in pixel space (origin at top-left of grid).
static func cell_to_pixel(cell: Vector2i) -> Vector2:
	var x := HEX_SIZE * sqrt(3.0) * (cell.x + 0.5 * (cell.y & 1))
	var y := HEX_SIZE * 1.5 * cell.y
	return Vector2(x, y)

## Pixel position → nearest hex cell. Input is relative to grid origin.
static func pixel_to_cell(pos: Vector2) -> Vector2i:
	var q := (pos.x * sqrt(3.0) / 3.0 - pos.y / 3.0) / HEX_SIZE
	var r := pos.y * 2.0 / 3.0 / HEX_SIZE
	return cube_to_offset(_cube_round(Vector3(q, r, -q - r)))

static func _cube_round(frac: Vector3) -> Vector3i:
	var q := roundi(frac.x)
	var r := roundi(frac.y)
	var s := roundi(frac.z)
	var dq := absf(q - frac.x)
	var dr := absf(r - frac.y)
	var ds := absf(s - frac.z)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	else:
		s = -q - r
	return Vector3i(q, r, s)


# =====================================================================
# DRAWING HELPERS
# =====================================================================

## Six vertices of a pointy-top hex centered at origin.
static func hex_vertices(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts


# =====================================================================
# BOUNDS CHECK
# =====================================================================

static func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS
