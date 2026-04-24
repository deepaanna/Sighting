## CryptidView — The cryptid sprite as seen through the camera viewfinder.
## Draws a per-cryptid silhouette scaled by hex_distance (closer = bigger).

extends Node2D

var hex_distance: int   = 3
var _ctype:       String = "bigfoot"


func setup(distance: int) -> void:
	hex_distance = distance
	_ctype = CameraPhase.session.get("cryptid_type", "bigfoot") as String
	var s := clampf(3.0 / maxf(float(hex_distance), 0.5), 0.5, 2.4)
	scale = Vector2(s, s)
	queue_redraw()


func _draw() -> void:
	match _ctype:
		"nessie":     _draw_nessie()
		"mothman":    _draw_mothman()
		"chupacabra": _draw_chupacabra()
		_:            _draw_bigfoot()


# ── Bigfoot ───────────────────────────────────────────────────────────────

func _draw_bigfoot() -> void:
	var fur := Color(0.20, 0.13, 0.08)
	var eye := Color(0.92, 0.60, 0.05)
	_blob(Vector2(-6, 18),  8,  4, fur)
	_blob(Vector2( 6, 18),  8,  4, fur)
	_blob(Vector2(-5,  8),  5,  9, fur)
	_blob(Vector2( 5,  8),  5,  9, fur)
	_blob(Vector2( 0, -2), 13, 12, fur)
	_blob(Vector2(-17, -6), 6, 10, fur)
	_blob(Vector2( 17, -6), 6, 10, fur)
	_blob(Vector2( 0, -17),11, 11, fur)
	draw_circle(Vector2(-4, -18), 2.8, eye)
	draw_circle(Vector2( 4, -18), 2.8, eye)


# ── Nessie ────────────────────────────────────────────────────────────────

func _draw_nessie() -> void:
	var body  := Color(0.12, 0.28, 0.22)
	var water := Color(0.08, 0.18, 0.32, 0.65)
	var eye   := Color(0.90, 0.70, 0.10)
	# Three humps above waterline
	_blob(Vector2(-18,  2), 9, 6, body)
	_blob(Vector2(  0, -4),12, 8, body)
	_blob(Vector2( 15,  4), 7, 5, body)
	# Neck
	var neck := PackedVector2Array([
		Vector2(5, -6), Vector2(11, -6),
		Vector2(15, -24), Vector2(8, -26),
	])
	draw_colored_polygon(neck, body)
	# Head
	_blob(Vector2(10, -28), 6, 4, body)
	draw_circle(Vector2(14, -29), 1.8, eye)
	# Water lines
	draw_line(Vector2(-28,  10), Vector2(28,  10), water, 3.0)
	draw_line(Vector2(-28,  14), Vector2(28,  14), water, 2.0)


# ── Mothman ───────────────────────────────────────────────────────────────

func _draw_mothman() -> void:
	var wing  := Color(0.08, 0.06, 0.12)
	var torso := Color(0.15, 0.10, 0.20)
	var eye   := Color(0.95, 0.08, 0.04)
	# Wings
	var lw := PackedVector2Array([
		Vector2(0, -8), Vector2(-30, -16), Vector2(-30, 6), Vector2(-10, 10)
	])
	var rw := PackedVector2Array([
		Vector2(0, -8), Vector2( 30, -16), Vector2( 30, 6), Vector2( 10, 10)
	])
	draw_colored_polygon(lw, wing)
	draw_colored_polygon(rw, wing)
	# Body
	_blob(Vector2(0, 2), 7, 14, torso)
	# Glowing red eyes — double-layer for glow effect
	draw_circle(Vector2(-4, -10), 4.0, Color(eye.r, eye.g, eye.b, 0.5))
	draw_circle(Vector2( 4, -10), 4.0, Color(eye.r, eye.g, eye.b, 0.5))
	draw_circle(Vector2(-4, -10), 2.5, eye)
	draw_circle(Vector2( 4, -10), 2.5, eye)
	draw_circle(Vector2(-4, -10), 1.2, Color(1.0, 0.5, 0.4))
	draw_circle(Vector2( 4, -10), 1.2, Color(1.0, 0.5, 0.4))


# ── Chupacabra ────────────────────────────────────────────────────────────

func _draw_chupacabra() -> void:
	var hide  := Color(0.22, 0.16, 0.12)
	var spine := Color(0.55, 0.18, 0.08)
	var eye   := Color(0.85, 0.08, 0.04)
	# Crouched body
	var bod := PackedVector2Array([
		Vector2(-14, 14), Vector2(-18,  2), Vector2(-10, -10),
		Vector2(  2, -14), Vector2( 15,  -4), Vector2( 16, 12),
		Vector2(  4, 18),
	])
	draw_colored_polygon(bod, hide)
	# Legs
	_blob(Vector2(-10, 18), 4, 5, hide)
	_blob(Vector2(  6, 20), 4, 5, hide)
	# Spine ridges
	for i: int in 5:
		var sx := -8.0 + i * 5.5
		var sy := -12.0 - sin(float(i) * 0.9) * 3.0
		draw_circle(Vector2(sx, sy), 2.8, spine)
	# Eye
	draw_circle(Vector2(-8, -6), 2.8, eye)
	draw_circle(Vector2(-8, -6), 1.4, Color(1.0, 0.4, 0.3))


# ── Shared ────────────────────────────────────────────────────────────────

func _blob(center: Vector2, rx: float, ry: float, color: Color, segs: int = 12) -> void:
	var p := PackedVector2Array()
	for i: int in segs:
		var a := TAU * float(i) / float(segs)
		p.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(p, color)
