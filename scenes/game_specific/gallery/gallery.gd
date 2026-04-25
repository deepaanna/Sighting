## Gallery — Scrollable grid of saved sighting photos with grade badges.
## Tap any photo to trigger the system share sheet for that image.
## Photos stored in user://gallery/ by camera_phase._capture_viewfinder().

extends Node2D

const THUMB_W := 88
const THUMB_H := 80

@onready var _count:    Label         = $HUD/Layout/CountLabel
@onready var _grid:     GridContainer = $HUD/Layout/ScrollBox/GalleryGrid
@onready var _back_btn: Button        = $HUD/Layout/BackButton


func _ready() -> void:
	UIStyler.style_button(_back_btn, UIStyler.ACCENT_MUTED)
	_back_btn.pressed.connect(func():
		SceneManager.change_scene(
			"res://scenes/game_specific/menu/main_menu.tscn", 0.3
		)
	)

	# Best-wall export button — added dynamically above the grid
	var wall_btn                   := Button.new()
	wall_btn.text                   = "EXPORT BEST WALL"
	wall_btn.custom_minimum_size    = Vector2(0, 38)
	wall_btn.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	UIStyler.style_button(wall_btn, UIStyler.ACCENT_ORANGE)
	wall_btn.pressed.connect(_export_best_wall)
	_back_btn.get_parent().add_child(wall_btn)
	_back_btn.get_parent().move_child(wall_btn, _back_btn.get_index())

	_populate()


func _populate() -> void:
	var all_entries: Array = Codex.get_value("gallery", "photos", [])
	var entries: Array = all_entries.filter(
		func(e: Dictionary) -> bool:
			return (e.get("file", "") as String).begins_with("sighting_")
	)

	_count.text = "%d photo%s" % [
		entries.size(), "" if entries.size() == 1 else "s"
	]

	if entries.is_empty():
		var lbl              := Label.new()
		lbl.text              = "No sightings yet.\nGet out there and find one."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode     = TextServer.AUTOWRAP_WORD
		_grid.add_child(lbl)
		return

	var sorted := entries.duplicate()
	sorted.reverse()   # most recent first
	for entry: Dictionary in sorted:
		_grid.add_child(_make_cell(entry))


func _make_cell(entry: Dictionary) -> Control:
	var meta    : Dictionary = entry.get("meta", {})
	var filename: String     = entry.get("file", "")

	# Flat Button so the whole cell is tappable
	var btn                     := Button.new()
	btn.flat                     = true
	btn.custom_minimum_size      = Vector2(THUMB_W, THUMB_H + 16)
	btn.pressed.connect(_on_cell_tapped.bind(entry))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	# Thumbnail
	var tex_rect                 := TextureRect.new()
	tex_rect.custom_minimum_size  = Vector2(THUMB_W, THUMB_H)
	tex_rect.stretch_mode         = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.expand_mode          = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	if FileAccess.file_exists("user://gallery/" + filename):
		var path := ProjectSettings.globalize_path("user://gallery/" + filename)
		var img  := Image.load_from_file(path)
		if img:
			tex_rect.texture = ImageTexture.create_from_image(img)
	vbox.add_child(tex_rect)

	# Grade + score badge
	var grade : String = meta.get("grade", "?")
	var score : int    = meta.get("score", 0)
	var badge          := Label.new()
	badge.text                  = "%s  %d%%" % [grade, score]
	badge.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 10)
	badge.modulate              = _grade_color(grade)
	badge.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(badge)

	return btn


func _on_cell_tapped(entry: Dictionary) -> void:
	var filename: String = entry.get("file", "")
	if filename == "" or not FileAccess.file_exists("user://gallery/" + filename):
		return
	var meta   : Dictionary = entry.get("meta", {})
	var grade  : String     = meta.get("grade",   "?")
	var score  : int        = meta.get("score",   0)
	var cryptid: String     = (meta.get("cryptid", "CRYPTID") as String).to_upper()
	var text   := "%s sighting — Grade %s (%d/100)\n#SIGHTING #ConspiracyCodex" % [
		cryptid, grade, score,
	]
	var abs_path := ProjectSettings.globalize_path("user://gallery/" + filename)
	ShareManager._system_share(abs_path, text)


func _export_best_wall() -> void:
	var all_entries: Array = Codex.get_value("gallery", "photos", [])
	var entries: Array = all_entries.filter(
		func(e: Dictionary) -> bool:
			return (e.get("file", "") as String).begins_with("sighting_")
	)
	if entries.is_empty():
		return

	# Sort by score desc; take best 6
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("meta", {}).get("score", 0) > b.get("meta", {}).get("score", 0)
	)
	var picks: Array = entries.slice(0, mini(6, entries.size()))

	const COLS   := 2
	const ROWS   := 3
	const TW     := 160
	const TH     := 145
	const GAP    := 4
	const PAD    := 8
	const BAR_H  := 22

	var img_w := COLS * TW + (COLS - 1) * GAP + PAD * 2
	var img_h := ROWS * TH + (ROWS - 1) * GAP + PAD * 2 + BAR_H

	var wall := Image.create(img_w, img_h, false, Image.FORMAT_RGB8)
	wall.fill(Color(0.06, 0.06, 0.08))

	for idx in picks.size():
		var entry: Dictionary = picks[idx]
		var filename: String  = entry.get("file", "")
		if not FileAccess.file_exists("user://gallery/" + filename):
			continue
		var photo := Image.load_from_file(
			ProjectSettings.globalize_path("user://gallery/" + filename)
		)
		if not photo:
			continue
		photo.resize(TW, TH, Image.INTERPOLATE_BILINEAR)
		var col_pos := idx % COLS
		var row_pos := idx / COLS
		var x := PAD + col_pos * (TW + GAP)
		var y := PAD + BAR_H + row_pos * (TH + GAP)
		wall.blit_rect(photo, Rect2i(0, 0, TW, TH), Vector2i(x, y))

	var wall_path := "user://gallery/best_wall.png"
	wall.save_png(wall_path)

	var abs_path := ProjectSettings.globalize_path(wall_path)
	var text     := "My best SIGHTING! captures — #SIGHTING #ConspiracyCodex"
	ShareManager._system_share(abs_path, text)


static func _grade_color(grade: String) -> Color:
	match grade:
		"S": return Color(1.00, 0.85, 0.10)
		"A": return Color(0.30, 0.90, 0.30)
		"B": return Color(0.40, 0.70, 1.00)
		"C": return Color(0.80, 0.60, 0.20)
		"D": return Color(0.70, 0.30, 0.20)
		_:   return Color(0.60, 0.15, 0.15)
