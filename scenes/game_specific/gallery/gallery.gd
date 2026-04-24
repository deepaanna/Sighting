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


static func _grade_color(grade: String) -> Color:
	match grade:
		"S": return Color(1.00, 0.85, 0.10)
		"A": return Color(0.30, 0.90, 0.30)
		"B": return Color(0.40, 0.70, 1.00)
		"C": return Color(0.80, 0.60, 0.20)
		"D": return Color(0.70, 0.30, 0.20)
		_:   return Color(0.60, 0.15, 0.15)
