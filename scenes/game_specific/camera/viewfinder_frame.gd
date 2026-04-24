## ViewfinderFrame — Draws the found-footage camera overlay on top of the
## cryptid SubViewport. Rendered at z_index=2 so it sits above the blurred image.
## State is pushed from CameraPhase each frame before queue_redraw() is called.

extends Node2D

const VF_ORIGIN := Vector2(20.0, 50.0)
const VF_SIZE   := Vector2(320.0, 290.0)
const VF_CENTER := Vector2(180.0, 195.0)   # VF_ORIGIN + VF_SIZE * 0.5
const MAX_SHOTS := 3

# Updated by CameraPhase each process tick
var rec_visible:     bool   = true
var shots_remaining: int    = 3
var zone_name:       String = ""
var blur_amount:     float  = 0.0   # drives corner-bracket colour
var overexposure:    float  = 0.0   # tints frame red when too close
var slider_value:    float  = 0.5   # 0=SKEPTIC, 0.5=sweet, 1=BELIEVER

# Export mode — set by camera_phase before capturing the gallery photo.
# Swaps live HUD elements for burned-in photo overlays.
var export_overlay_mode: bool   = false
var export_grade:        String = ""
var export_score:        int    = 0
var export_cryptid:      String = ""


func _draw() -> void:
    _draw_scanline_layer()
    _draw_border()
    _draw_corner_brackets()
    _draw_focus_reticle()
    _draw_roc_thirds()
    if not export_overlay_mode:
        _draw_shot_pips()
    _draw_rec_indicator()
    if export_overlay_mode:
        _draw_export_overlay()
    else:
        _draw_text_overlays()
        if overexposure > 0.15:
            _draw_overexposure_warning()
    if slider_value < 0.25:
        _draw_debunked_overlay()
    elif slider_value > 0.75:
        _draw_enhanced_overlay()


# ── Scanlines (secondary pass — lighter than the bg scanlines) ────────
func _draw_scanline_layer() -> void:
    for y in range(int(VF_ORIGIN.y) + 3, int(VF_ORIGIN.y + VF_SIZE.y), 6):
        draw_line(
            Vector2(VF_ORIGIN.x + 1, y),
            Vector2(VF_ORIGIN.x + VF_SIZE.x - 1, y),
            Color(0.0, 0.0, 0.0, 0.08), 1.0
        )


# ── Viewfinder outer border (colour-shifts with blur) ─────────────────
func _draw_border() -> void:
    var t     := clampf(blur_amount / 10.0, 0.0, 1.0)
    var color := Color(
        lerp(0.45, 0.9, t),
        lerp(0.85, 0.2, t),
        lerp(0.45, 0.1, t),
        0.60
    )
    draw_rect(Rect2(VF_ORIGIN, VF_SIZE), color, false, 1.5)


# ── Corner brackets ───────────────────────────────────────────────────
func _draw_corner_brackets() -> void:
    var t     := clampf(blur_amount / 10.0, 0.0, 1.0)
    var color := Color(
        lerp(0.55, 1.0, t),
        lerp(1.00, 0.25, t),
        lerp(0.55, 0.10, t),
        0.80
    )
    var arm := 22.0
    var gap := 5.0
    var w   := 2.0
    var pts := [
        [VF_ORIGIN + Vector2(gap, gap),                         Vector2( 1,  1)],
        [VF_ORIGIN + Vector2(VF_SIZE.x - gap, gap),             Vector2(-1,  1)],
        [VF_ORIGIN + Vector2(gap, VF_SIZE.y - gap),             Vector2( 1, -1)],
        [VF_ORIGIN + Vector2(VF_SIZE.x - gap, VF_SIZE.y - gap), Vector2(-1, -1)],
    ]
    for pt in pts:
        var p: Vector2 = pt[0]
        var d: Vector2 = pt[1]
        draw_line(p, p + Vector2(d.x * arm, 0.0), color, w)
        draw_line(p, p + Vector2(0.0, d.y * arm), color, w)


# ── Centre focus reticle ──────────────────────────────────────────────
func _draw_focus_reticle() -> void:
    var col := Color(0.55, 0.90, 0.55, 0.40)
    draw_line(VF_CENTER - Vector2(16, 0), VF_CENTER + Vector2(16, 0), col, 1.0)
    draw_line(VF_CENTER - Vector2(0, 16), VF_CENTER + Vector2(0, 16), col, 1.0)
    # Small circle outline
    var pts := PackedVector2Array()
    for i in 20:
        var a := TAU * i / 20.0
        pts.append(VF_CENTER + Vector2(cos(a), sin(a)) * 22.0)
    pts.append(pts[0])
    draw_polyline(pts, Color(0.55, 0.90, 0.55, 0.25), 1.0)


# ── Rule-of-thirds grid (very subtle) ────────────────────────────────
func _draw_roc_thirds() -> void:
    var col := Color(0.6, 0.9, 0.6, 0.08)
    for i: int in [1, 2]:
        var x: float = VF_ORIGIN.x + VF_SIZE.x * float(i) / 3.0
        var y: float = VF_ORIGIN.y + VF_SIZE.y * float(i) / 3.0
        draw_line(Vector2(x, VF_ORIGIN.y), Vector2(x, VF_ORIGIN.y + VF_SIZE.y), col, 1.0)
        draw_line(Vector2(VF_ORIGIN.x, y), Vector2(VF_ORIGIN.x + VF_SIZE.x, y), col, 1.0)


# ── Shot pips (top-left) ──────────────────────────────────────────────
func _draw_shot_pips() -> void:
    for i in MAX_SHOTS:
        var cx    := VF_ORIGIN.x + 10.0 + i * 16.0
        var cy    := VF_ORIGIN.y + 14.0
        var color := Color(0.9, 0.8, 0.1, 0.9) if i < shots_remaining \
                     else Color(0.25, 0.25, 0.25, 0.5)
        draw_circle(Vector2(cx, cy), 4.5, color)


# ── REC indicator (top-right) ─────────────────────────────────────────
func _draw_rec_indicator() -> void:
    if not rec_visible:
        return
    var rx := VF_ORIGIN.x + VF_SIZE.x - 14.0
    var ry := VF_ORIGIN.y + 14.0
    draw_circle(Vector2(rx - 10.0, ry), 5.0, Color(0.90, 0.12, 0.12))
    draw_string(ThemeDB.fallback_font,
        Vector2(rx - 2.0, ry + 4.0), "REC",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
        Color(0.95, 0.95, 0.95, 0.90))


# ── Text overlays (timestamp, zone) ──────────────────────────────────
func _draw_text_overlays() -> void:
    var font   := ThemeDB.fallback_font
    var sz     := 11
    var bot_y  := VF_ORIGIN.y + VF_SIZE.y - 7.0
    var tint   := Color(0.50, 0.90, 0.50, 0.75)
    draw_string(font, Vector2(VF_ORIGIN.x + 6.0, bot_y),
        Time.get_time_string_from_system(),
        HORIZONTAL_ALIGNMENT_LEFT, -1, sz, tint)
    if zone_name != "":
        draw_string(font, Vector2(VF_ORIGIN.x + VF_SIZE.x - 6.0, bot_y),
            zone_name, HORIZONTAL_ALIGNMENT_RIGHT, -1, sz, tint)


# ── Overexposure warning (red flicker when dangerously close) ─────────
func _draw_overexposure_warning() -> void:
    var alpha := overexposure * 0.30
    draw_rect(Rect2(VF_ORIGIN, VF_SIZE), Color(1.0, 0.1, 0.05, alpha))
    draw_string(ThemeDB.fallback_font,
        Vector2(VF_CENTER.x - 40.0, VF_ORIGIN.y + 26.0),
        "TOO CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
        Color(1.0, 0.2, 0.1, minf(overexposure * 1.5, 0.9)))


# ── DEBUNKED overlay — slider in 0–25% skeptic zone ──────────────────
func _draw_debunked_overlay() -> void:
    var alpha := clampf((0.25 - slider_value) / 0.25, 0.0, 1.0)
    # Red tint wash
    draw_rect(Rect2(VF_ORIGIN, VF_SIZE), Color(0.75, 0.05, 0.05, alpha * 0.18))
    # Rotated DEBUNKED stamp centered in viewfinder
    draw_set_transform(VF_CENTER, deg_to_rad(-18.0), Vector2.ONE)
    draw_string(ThemeDB.fallback_font,
        Vector2(-VF_SIZE.x * 0.5, 10.0), "DEBUNKED",
        HORIZONTAL_ALIGNMENT_CENTER, int(VF_SIZE.x), 26,
        Color(0.90, 0.10, 0.10, alpha * 0.85))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    # X marks in the four quadrants
    var xc := Color(0.90, 0.10, 0.10, alpha * 0.65)
    for pt: Vector2 in [
        VF_ORIGIN + Vector2(44.0, 46.0),
        VF_ORIGIN + Vector2(VF_SIZE.x - 44.0, 46.0),
        VF_ORIGIN + Vector2(44.0, VF_SIZE.y - 46.0),
        VF_ORIGIN + Vector2(VF_SIZE.x - 44.0, VF_SIZE.y - 46.0),
    ]:
        draw_line(pt - Vector2(10, 10), pt + Vector2(10, 10), xc, 2.0)
        draw_line(pt + Vector2(-10, 10), pt + Vector2(10, -10), xc, 2.0)


# ── Export overlay — burned-in badge for saved gallery photo ─────────
func _draw_export_overlay() -> void:
    var font     := ThemeDB.fallback_font
    var gc       := _grade_color(export_grade)
    var bot_y    := VF_ORIGIN.y + VF_SIZE.y   # = 340

    # Grade badge — top-right, below REC indicator
    var bx := VF_ORIGIN.x + VF_SIZE.x - 62.0   # right-aligned inside VF
    var by := VF_ORIGIN.y + 28.0
    draw_rect(Rect2(bx, by, 57.0, 22.0), Color(0.0, 0.0, 0.0, 0.78))
    draw_rect(Rect2(bx, by, 57.0, 22.0), gc, false, 1.5)
    draw_string(font, Vector2(bx + 5.0, by + 15.0),
        "%s  %d%%" % [export_grade, export_score],
        HORIZONTAL_ALIGNMENT_LEFT, -1, 12, gc)

    # Cryptid · zone strip — bottom-left (mirrors original timestamp position)
    var tint  := Color(0.55, 0.95, 0.55, 0.80)
    var label := "%s · %s" % [
        export_cryptid.to_upper(),
        zone_name if zone_name != "" else "UNKNOWN",
    ]
    draw_string(font, Vector2(VF_ORIGIN.x + 6.0, bot_y - 18.0),
        label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tint)

    # Credibility % — bottom-right
    draw_string(font, Vector2(VF_ORIGIN.x + VF_SIZE.x - 6.0, bot_y - 18.0),
        "%d%% CREDIBLE" % export_score,
        HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, gc)

    # Watermark — very bottom center, semi-transparent
    draw_string(font, Vector2(VF_ORIGIN.x, bot_y - 6.0),
        "SIGHTING! — A Conspiracy Codex Game",
        HORIZONTAL_ALIGNMENT_CENTER, int(VF_SIZE.x), 8,
        Color(1.0, 1.0, 1.0, 0.35))


static func _grade_color(grade: String) -> Color:
    match grade:
        "S": return Color(1.00, 0.85, 0.10)
        "A": return Color(0.30, 0.90, 0.30)
        "B": return Color(0.40, 0.70, 1.00)
        "C": return Color(0.80, 0.60, 0.20)
        "D": return Color(0.70, 0.30, 0.20)
        _:   return Color(0.60, 0.15, 0.15)


# ── ENHANCED overlay — slider in 75–100% believer zone ───────────────
func _draw_enhanced_overlay() -> void:
    var alpha := clampf((slider_value - 0.75) / 0.25, 0.0, 1.0)
    # Subtle purple tint
    draw_rect(Rect2(VF_ORIGIN, VF_SIZE), Color(0.35, 0.10, 0.65, alpha * 0.14))
    # Gold glowing inner border
    draw_rect(Rect2(VF_ORIGIN + Vector2(3, 3), VF_SIZE - Vector2(6, 6)),
        Color(0.85, 0.70, 0.10, alpha * 0.50), false, 2.0)
    # Watermark text centred at bottom of frame
    draw_string(ThemeDB.fallback_font,
        Vector2(VF_ORIGIN.x, VF_ORIGIN.y + VF_SIZE.y - 22.0),
        "✦ ENHANCED BY TRUTHSEEKER PRO ✦",
        HORIZONTAL_ALIGNMENT_CENTER, int(VF_SIZE.x), 9,
        Color(0.95, 0.85, 0.20, alpha * 0.80))
