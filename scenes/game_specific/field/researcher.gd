## Researcher — The player's field researcher token on the hex grid.
## Draws itself as a colored marker; animates moves via Tween from parent.

extends Node2D

var _current_cell: Vector2i = Vector2i(3, 3)

# Emitted after the tween finishes so step_toward can chain moves.
signal step_complete(cell: Vector2i)

var _tween: Tween


func get_cell() -> Vector2i:
	return _current_cell


## Move the token to a new world position, updating its tracked cell.
func move_to(cell: Vector2i, world_pos: Vector2) -> void:
	_current_cell = cell
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(self, "position", world_pos, 0.14)
	_tween.tween_callback(func(): step_complete.emit(_current_cell))


func _draw() -> void:
	# Shadow
	draw_circle(Vector2(1, 2), 9.0, Color(0, 0, 0, 0.25))
	# Body circle
	draw_circle(Vector2.ZERO, 9.0, Color(0.95, 0.82, 0.1))
	draw_circle(Vector2.ZERO, 9.0, Color(0.1, 0.08, 0.0, 0.9), false, 1.5)
	# Tiny head to suggest person silhouette
	draw_circle(Vector2(0, -6), 4.0, Color(0.92, 0.78, 0.62))
	draw_circle(Vector2(0, -6), 4.0, Color(0.1, 0.08, 0.0, 0.7), false, 1.0)
