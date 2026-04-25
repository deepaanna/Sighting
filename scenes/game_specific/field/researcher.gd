## Researcher — The player's field researcher token on the hex grid.
## Directional sprite (up/down/left/right) from resources/textures/researcher/.
## Shadow is drawn procedurally; the sprite handles the facing direction.

extends Node2D

var _current_cell: Vector2i = Vector2i(3, 3)

signal step_complete(cell: Vector2i)

var _tween:  Tween
var _sprite: Sprite2D
var _tex:    Dictionary = {}


func _ready() -> void:
	_tex = {
		"down":  load("res://resources/textures/researcher/researcher_down.png"),
		"up":    load("res://resources/textures/researcher/researcher_up.png"),
		"left":  load("res://resources/textures/researcher/researcher_left.png"),
		"right": load("res://resources/textures/researcher/researcher_right.png"),
	}
	_sprite         = Sprite2D.new()
	_sprite.texture = _tex["down"]
	_sprite.scale   = Vector2(0.44, 0.44)
	_sprite.z_index = 1
	add_child(_sprite)


func get_cell() -> Vector2i:
	return _current_cell


func move_to(cell: Vector2i, world_pos: Vector2) -> void:
	var delta       := world_pos - position
	_sprite.texture  = _tex_for_dir(delta)
	_current_cell    = cell
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(self, "position", world_pos, 0.14)
	_tween.tween_callback(func(): step_complete.emit(_current_cell))


func _tex_for_dir(delta: Vector2) -> Texture2D:
	if abs(delta.x) >= abs(delta.y):
		return _tex["right"] if delta.x >= 0.0 else _tex["left"]
	return _tex["down"] if delta.y >= 0.0 else _tex["up"]


func _draw() -> void:
	draw_circle(Vector2(1.0, 2.0), 9.0, Color(0.0, 0.0, 0.0, 0.22))
