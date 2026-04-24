## Cryptid — Visual token for the cryptid on the field.
## Concealed until researcher enters camera range.
## Draws a rough, intentionally-sketchy Bigfoot silhouette.
## Step 6 will replace _draw() with per-cryptid sprites + blur shaders.

extends Node2D

var _revealed := false
var _tween: Tween


func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	modulate.a = 0.0
	queue_redraw()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.4)


func conceal() -> void:
	_revealed = false
	modulate.a = 0.0
	queue_redraw()


## Tween to new world position — slower than the researcher to feel lumbering.
func move_to(world_pos: Vector2) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "position", world_pos, 0.85)


func _draw() -> void:
	if not _revealed:
		return
	var fur  := Color(0.20, 0.13, 0.08)
	var eye  := Color(0.92, 0.60, 0.05)
	# Feet
	_blob(Vector2(-5, 15), 7, 3, fur)
	_blob(Vector2(5, 15), 7, 3, fur)
	# Legs
	_blob(Vector2(-5, 7), 4, 8, fur)
	_blob(Vector2(5, 7), 4, 8, fur)
	# Body
	_blob(Vector2(0, -1), 11, 10, fur)
	# Arms (raised, menacing)
	_blob(Vector2(-15, -5), 5, 9, fur)
	_blob(Vector2(15, -5), 5, 9, fur)
	# Head
	_blob(Vector2(0, -14), 9, 9, fur)
	# Eyes
	draw_circle(Vector2(-3, -15), 2.2, eye)
	draw_circle(Vector2(3, -15), 2.2, eye)


## Approximate ellipse via polygon.
func _blob(center: Vector2, rx: float, ry: float, color: Color, segs: int = 10) -> void:
	var p := PackedVector2Array()
	for i in segs:
		var a := TAU * i / segs
		p.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(p, color)
