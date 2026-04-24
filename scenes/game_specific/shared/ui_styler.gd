## UIStyler — Static programmer-art button/bar styling.
## Call UIStyler.style_button(btn, accent) in any scene's _ready() to apply
## the dark-terminal aesthetic without a theme resource file.

class_name UIStyler

const ACCENT_GREEN  := Color(0.22, 0.62, 0.28)
const ACCENT_MUTED  := Color(0.35, 0.38, 0.35)
const ACCENT_ORANGE := Color(0.82, 0.48, 0.10)
const ACCENT_BLUE   := Color(0.25, 0.55, 0.85)
const BG_DARK       := Color(0.04, 0.08, 0.05, 0.92)
const BG_HOVER      := Color(0.08, 0.15, 0.09, 0.95)
const TEXT_NORMAL   := Color(0.88, 0.92, 0.86)
const TEXT_BRIGHT   := Color(1.00, 1.00, 0.98)


static func style_button(btn: Button, accent: Color = ACCENT_GREEN) -> void:
	btn.add_theme_color_override("font_color",         TEXT_NORMAL)
	btn.add_theme_color_override("font_hover_color",   TEXT_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", TEXT_BRIGHT)
	btn.add_theme_color_override("font_focus_color",   TEXT_BRIGHT)
	btn.add_theme_stylebox_override("normal",
		_box(BG_DARK,  accent, 2, 5))
	btn.add_theme_stylebox_override("hover",
		_box(BG_HOVER, accent.lightened(0.18), 2, 5))
	btn.add_theme_stylebox_override("pressed",
		_box(accent.darkened(0.55), accent, 2, 5))
	btn.add_theme_stylebox_override("focus",
		_box(BG_HOVER, Color(1, 1, 1, 0.40), 2, 5))
	btn.add_theme_stylebox_override("disabled",
		_box(Color(0.04, 0.06, 0.04, 0.50), Color(0.30, 0.30, 0.30, 0.40), 1, 5))


static func style_progress_bar(bar: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.07, 0.05, 0.90)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.18, 0.42, 0.20, 0.65)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)


static func _box(bg: Color, border: Color, bw: int, corner: int) -> StyleBoxFlat:
	var s            := StyleBoxFlat.new()
	s.bg_color        = bg
	s.set_border_width_all(bw)
	s.border_color    = border
	s.set_corner_radius_all(corner)
	s.content_margin_left   = 8.0
	s.content_margin_right  = 8.0
	s.content_margin_top    = 4.0
	s.content_margin_bottom = 4.0
	return s
