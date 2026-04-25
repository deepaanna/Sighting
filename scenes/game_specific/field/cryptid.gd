## Cryptid — Visual token on the field hex grid.
## Hidden until researcher enters camera range, then briefly revealed before
## the camera phase launches. Draws a per-cryptid silhouette.

extends Node2D

var _revealed := false
var _ctype    := "bigfoot"
var _tween:   Tween


func setup(ctype: String) -> void:
	_ctype = ctype
	queue_redraw()


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


func move_to(world_pos: Vector2) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "position", world_pos, 0.85)


func _draw() -> void:
	if not _revealed:
		return
	match _ctype:
		"nessie":        _draw_nessie()
		"mothman":       _draw_mothman()
		"chupacabra":    _draw_chupacabra()
		"jersey_devil":  _draw_jersey_devil()
		"skunk_ape":     _draw_skunk_ape()
		_:               _draw_bigfoot()


# ── Bigfoot ───────────────────────────────────────────────────────────────

func _draw_bigfoot() -> void:
	var fur := Color(0.20, 0.13, 0.08)
	var eye := Color(0.92, 0.60, 0.05)
	_blob(Vector2(-5, 15),  7,  3, fur)
	_blob(Vector2( 5, 15),  7,  3, fur)
	_blob(Vector2(-5,  7),  4,  8, fur)
	_blob(Vector2( 5,  7),  4,  8, fur)
	_blob(Vector2( 0, -1), 11, 10, fur)
	_blob(Vector2(-15, -5), 5,  9, fur)
	_blob(Vector2( 15, -5), 5,  9, fur)
	_blob(Vector2( 0, -14), 9,  9, fur)
	draw_circle(Vector2(-3, -15), 2.2, eye)
	draw_circle(Vector2( 3, -15), 2.2, eye)


# ── Nessie ────────────────────────────────────────────────────────────────

func _draw_nessie() -> void:
	var body  := Color(0.10, 0.24, 0.18)
	var water := Color(0.08, 0.16, 0.30, 0.55)
	var eye   := Color(0.88, 0.68, 0.08)
	# Humps
	_blob(Vector2(-12, 2), 7, 5, body)
	_blob(Vector2(  0,-3), 9, 6, body)
	_blob(Vector2( 10, 3), 5, 4, body)
	# Neck + head
	var neck := PackedVector2Array([
		Vector2(3, -5), Vector2(8, -5), Vector2(11, -18), Vector2(6, -19)
	])
	draw_colored_polygon(neck, body)
	_blob(Vector2(7, -21), 4, 3, body)
	draw_circle(Vector2(10, -22), 1.4, eye)
	# Water surface
	draw_line(Vector2(-18, 7), Vector2(18, 7), water, 2.5)
	draw_line(Vector2(-18, 10), Vector2(18, 10), water, 1.5)


# ── Mothman ───────────────────────────────────────────────────────────────

func _draw_mothman() -> void:
	var wing  := Color(0.07, 0.05, 0.10)
	var torso := Color(0.12, 0.08, 0.16)
	var eye   := Color(0.92, 0.06, 0.04)
	# Wings
	var lw := PackedVector2Array([
		Vector2(0, -6), Vector2(-22, -13), Vector2(-22, 5), Vector2(-8, 8)
	])
	var rw := PackedVector2Array([
		Vector2(0, -6), Vector2( 22, -13), Vector2( 22, 5), Vector2( 8, 8)
	])
	draw_colored_polygon(lw, wing)
	draw_colored_polygon(rw, wing)
	_blob(Vector2(0, 2), 5, 11, torso)
	# Glowing eyes
	draw_circle(Vector2(-3, -8), 3.0, Color(eye.r, eye.g, eye.b, 0.45))
	draw_circle(Vector2( 3, -8), 3.0, Color(eye.r, eye.g, eye.b, 0.45))
	draw_circle(Vector2(-3, -8), 1.8, eye)
	draw_circle(Vector2( 3, -8), 1.8, eye)


# ── Chupacabra ────────────────────────────────────────────────────────────

func _draw_chupacabra() -> void:
	var hide  := Color(0.20, 0.14, 0.10)
	var spine := Color(0.52, 0.16, 0.06)
	var eye   := Color(0.82, 0.06, 0.04)
	# Crouched body
	var bod := PackedVector2Array([
		Vector2(-10, 12), Vector2(-14, 2), Vector2(-8, -8),
		Vector2( 2, -11), Vector2(12, -3), Vector2(13, 9),
		Vector2( 3, 14),
	])
	draw_colored_polygon(bod, hide)
	_blob(Vector2(-8, 15), 3, 4, hide)
	_blob(Vector2( 5, 16), 3, 4, hide)
	# Spine ridges
	for i: int in 4:
		draw_circle(Vector2(-5.0 + i * 4.5, -9.5), 2.2, spine)
	draw_circle(Vector2(-6, -4), 2.2, eye)
	draw_circle(Vector2(-6, -4), 1.0, Color(1.0, 0.4, 0.3))


# ── Jersey Devil ──────────────────────────────────────────────────────────

func _draw_jersey_devil() -> void:
	var body := Color(0.18, 0.12, 0.24)
	var wing := Color(0.10, 0.07, 0.16)
	var eye  := Color(0.95, 0.18, 0.04)
	# Wings — swept up, thin
	var lw := PackedVector2Array([
		Vector2(0, 0), Vector2(-20, -12), Vector2(-16, 4), Vector2(-8, 7)
	])
	var rw := PackedVector2Array([
		Vector2(0, 0), Vector2( 20, -12), Vector2( 16, 4), Vector2( 8, 7)
	])
	draw_colored_polygon(lw, wing)
	draw_colored_polygon(rw, wing)
	# Thin body + head
	_blob(Vector2(0, 2), 3, 9, body)
	_blob(Vector2(0, -13), 4, 4, body)
	# Horns
	draw_line(Vector2(-2, -16), Vector2(-5, -22), body, 1.5)
	draw_line(Vector2( 2, -16), Vector2( 5, -22), body, 1.5)
	# Eye glow
	draw_circle(Vector2(3, -13), 2.0, Color(eye.r, eye.g, eye.b, 0.5))
	draw_circle(Vector2(3, -13), 1.2, eye)
	# Long whip tail
	draw_line(Vector2(0, 8), Vector2(6, 14), body, 1.8)
	draw_line(Vector2(6, 14), Vector2(3, 19), body, 1.5)


# ── Skunk Ape ─────────────────────────────────────────────────────────────

func _draw_skunk_ape() -> void:
	var fur   := Color(0.14, 0.10, 0.08)
	var snout := Color(0.28, 0.18, 0.12)
	var eye   := Color(0.55, 0.82, 0.12)
	# Feet
	_blob(Vector2(-5, 15), 6, 3, fur)
	_blob(Vector2( 5, 15), 6, 3, fur)
	# Legs
	_blob(Vector2(-5, 7), 4, 7, fur)
	_blob(Vector2( 5, 7), 4, 7, fur)
	# Hunched torso
	_blob(Vector2(0, -2), 11, 9, fur)
	# Long knuckle-dragging arms
	_blob(Vector2(-14, 3), 5, 7, fur)
	_blob(Vector2( 14, 3), 5, 7, fur)
	# Head (set forward, not upright)
	_blob(Vector2(4, -13), 8, 7, fur)
	# Elongated snout
	_blob(Vector2(9, -11), 4, 2, snout)
	draw_circle(Vector2(1, -16), 1.8, eye)
	draw_circle(Vector2(6, -15), 1.8, eye)


# ── Shared ────────────────────────────────────────────────────────────────

func _blob(center: Vector2, rx: float, ry: float, color: Color, segs: int = 10) -> void:
	var p := PackedVector2Array()
	for i: int in segs:
		var a := TAU * float(i) / float(segs)
		p.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(p, color)
