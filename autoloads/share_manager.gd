## ShareManager — Screenshot capture, overlay compositing, and system share.
## Every Conspiracy Codex game uses this to produce shareable content.
##
## Usage:
##   ShareManager.capture_and_share("My 97% Mothman shot!", {"score": 97, "grade": "S"})
##   ShareManager.capture_to_gallery()  # save without sharing
##   ShareManager.share_text("REDACTED #47\n🟩⬛⬛🟩🟨⬛🟩\nScore: 1,340")

extends Node

# --- Signals ---
signal screenshot_captured(image: Image)
signal share_completed()
signal share_failed(reason: String)

# --- Config ---
const WATERMARK_TEXT := "A Conspiracy Codex Game"
const GALLERY_DIR := "user://gallery/"
const MAX_GALLERY_SIZE := 100

# --- State ---
var _capture_queued := false
var _capture_callback: Callable


# =====================================================================
# LIFECYCLE
# =====================================================================

func _ready() -> void:
	# Ensure gallery directory exists
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(GALLERY_DIR)
	)


# =====================================================================
# SCREENSHOT CAPTURE
# =====================================================================

## Capture the current viewport as an Image.
func capture_screenshot() -> Image:
	# Wait for frame to render
	await RenderingServer.frame_post_draw
	
	var viewport := get_viewport()
	var image := viewport.get_texture().get_image()
	
	screenshot_captured.emit(image)
	return image


## Capture, add overlay data, and trigger system share.
func capture_and_share(title: String, overlay_data: Dictionary = {}) -> void:
	var image := await capture_screenshot()
	
	# Add watermark and overlay
	image = _apply_overlay(image, title, overlay_data)
	
	# Save to temp file for sharing
	var temp_path := "user://share_temp.png"
	image.save_png(temp_path)
	
	# Trigger system share
	_system_share(
		ProjectSettings.globalize_path(temp_path),
		title
	)


## Capture and save to gallery without sharing.
func capture_to_gallery(metadata: Dictionary = {}) -> String:
	var image := await capture_screenshot()
	
	var timestamp := Time.get_unix_time_from_system()
	var filename := "codex_%d.png" % timestamp
	var path := GALLERY_DIR + filename
	
	image.save_png(path)
	
	# Store metadata in Codex
	var gallery_meta: Array = Codex.get_value("gallery", "photos", [])
	gallery_meta.append({
		"file": filename,
		"time": timestamp,
		"meta": metadata
	})
	
	# Trim gallery if over max
	while gallery_meta.size() > MAX_GALLERY_SIZE:
		var oldest = gallery_meta.pop_front()
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(GALLERY_DIR + oldest.file)
		)
	
	Codex.set_value("gallery", "photos", gallery_meta)
	
	return path


# =====================================================================
# TEXT-ONLY SHARE (for Wordle-style results)
# =====================================================================

## Share text to clipboard and trigger system share if available.
func share_text(text: String) -> void:
	DisplayServer.clipboard_set(text)
	
	# On mobile, also trigger share sheet with text
	if OS.has_feature("mobile"):
		_system_share_text(text)
	else:
		print("ShareManager: Copied to clipboard:\n%s" % text)
	
	share_completed.emit()


# =====================================================================
# OVERLAY COMPOSITING
# =====================================================================

## Apply game-branded overlay to a screenshot image.
## overlay_data keys: "score", "grade", "title", "subtitle", "game_name"
func _apply_overlay(image: Image, title: String, data: Dictionary) -> Image:
	# For MVP, we use a simple approach:
	# Composite a semi-transparent bar at the bottom with text info.
	# Full implementation would use a ViewportTexture with Control nodes.
	#
	# In production, consider rendering an overlay scene to a SubViewport
	# and compositing the result onto the screenshot.
	
	var width := image.get_width()
	var height := image.get_height()
	
	# Draw semi-transparent black bar at bottom (48px tall)
	var bar_height := 48
	var bar_y := height - bar_height
	for x in range(width):
		for y in range(bar_y, height):
			var existing := image.get_pixel(x, y)
			var blended := existing.lerp(Color.BLACK, 0.7)
			image.set_pixel(x, y, blended)
	
	# Note: Godot's Image class doesn't support text rendering directly.
	# For text overlays, use one of these approaches in production:
	#   1. Render a Control scene to SubViewport, capture, composite
	#   2. Use a pre-rendered overlay texture with dynamic text
	#   3. Use the ThemeDB font rendering methods
	#
	# For MVP, the bar alone provides a branded look.
	# The share text accompanies the image via the share sheet.
	
	return image


# =====================================================================
# SYSTEM SHARE (platform-specific)
# =====================================================================

func _system_share(image_path: String, text: String) -> void:
	if OS.has_feature("android"):
		_share_android(image_path, text)
	elif OS.has_feature("ios"):
		_share_ios(image_path, text)
	else:
		# Desktop fallback: save to user folder and notify
		var desktop_path := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		var filename := "codex_share_%d.png" % Time.get_unix_time_from_system()
		DirAccess.copy_absolute(image_path, desktop_path + "/" + filename)
		print("ShareManager: Saved to %s/%s" % [desktop_path, filename])
		share_completed.emit()


func _share_android(image_path: String, text: String) -> void:
	# Android share intent via JNI
	# Requires a small Java/Kotlin plugin or use of OS.shell_open
	# For MVP, we use a Godot Android plugin or the GodotShare plugin
	if Engine.has_singleton("GodotShare"):
		var share = Engine.get_singleton("GodotShare")
		share.shareImage(image_path, text, "Share via")
	else:
		push_warning("ShareManager: GodotShare plugin not available")
		DisplayServer.clipboard_set(text)
		share_failed.emit("Share plugin not available")


func _share_ios(image_path: String, text: String) -> void:
	# iOS share sheet
	# Requires iOS plugin — similar approach to Android
	if Engine.has_singleton("GodotShare"):
		var share = Engine.get_singleton("GodotShare")
		share.shareImage(image_path, text, "")
	else:
		push_warning("ShareManager: GodotShare plugin not available on iOS")
		DisplayServer.clipboard_set(text)
		share_failed.emit("Share plugin not available")


func _system_share_text(text: String) -> void:
	if Engine.has_singleton("GodotShare"):
		var share = Engine.get_singleton("GodotShare")
		share.shareText(text, "Share via")
	else:
		DisplayServer.clipboard_set(text)


# =====================================================================
# GALLERY QUERIES
# =====================================================================

## Get list of gallery photos (metadata).
func get_gallery() -> Array:
	return Codex.get_value("gallery", "photos", [])


## Get the full path to a gallery image.
func get_gallery_image_path(filename: String) -> String:
	return ProjectSettings.globalize_path(GALLERY_DIR + filename)


## Get gallery count.
func get_gallery_count() -> int:
	return get_gallery().size()
