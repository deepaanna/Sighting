## SceneManager — Scene transitions with fade effects.
##
## Usage:
##   SceneManager.change_scene("res://scenes/game.tscn")
##   SceneManager.change_scene("res://scenes/menu.tscn", 0.5)  # custom fade duration

extends Node

signal transition_started()
signal transition_midpoint()  # scene swapped, fade-in about to start
signal transition_finished()

var _transition_layer: CanvasLayer
var _color_rect: ColorRect
var _is_transitioning := false


func _ready() -> void:
	_build_transition_layer()


func _build_transition_layer() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.layer = 100  # above everything
	add_child(_transition_layer)
	
	_color_rect = ColorRect.new()
	_color_rect.color = Color(0.03, 0.03, 0.05, 0.0)
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_layer.add_child(_color_rect)


func change_scene(scene_path: String, fade_duration: float = 0.3) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	transition_started.emit()
	
	# Fade out
	var tween := create_tween()
	tween.tween_property(_color_rect, "color:a", 1.0, fade_duration)
	await tween.finished
	
	# Swap scene
	get_tree().change_scene_to_file(scene_path)
	transition_midpoint.emit()
	
	# Wait one frame for scene to initialize
	await get_tree().process_frame
	
	# Fade in
	tween = create_tween()
	tween.tween_property(_color_rect, "color:a", 0.0, fade_duration)
	await tween.finished
	
	_is_transitioning = false
	transition_finished.emit()


func is_transitioning() -> bool:
	return _is_transitioning
