## ProximitySystem — Vibration feedback and proximity-level change events.
## Vibration is Android-only; silently no-ops on other platforms.
## Levels 0-4 map to the five proximity zones shown in the HUD.
## Call update() every frame and on_researcher_stepped() after each move.

class_name ProximitySystem
extends Node

signal level_changed(old_level: int, new_level: int)

# Normalized proximity thresholds for each level boundary
const THRESHOLDS := [0.0, 0.20, 0.45, 0.65, 0.82]

# Idle pulse intervals (seconds). 0 = no idle pulse at that level.
const PULSE_INTERVAL := [0.0, 0.0, 4.0, 2.0, 1.0]

var _current_level := 0
var _pulse_timer   := 0.0
var _is_android    := false


func _ready() -> void:
	_is_android = OS.get_name() == "Android"


# =====================================================================
# PUBLIC
# =====================================================================

## Call every frame with the latest normalized proximity value (0–1).
func update(normalized: float) -> void:
	var new_level := _level_for(normalized)
	if new_level == _current_level:
		return
	var old := _current_level
	_current_level = new_level
	_pulse_timer   = 0.0
	_on_level_changed(old, new_level)
	level_changed.emit(old, new_level)


## Call from field when the researcher completes a step.
## Gives a short buzz whose strength matches current proximity.
func on_researcher_stepped(normalized: float) -> void:
	if normalized < 0.15:
		return
	_buzz(int(lerp(40.0, 160.0, normalized)), normalized * 0.65)


# =====================================================================
# INTERNAL
# =====================================================================

func _process(delta: float) -> void:
	var interval: float = PULSE_INTERVAL[_current_level]
	if interval <= 0.0:
		return
	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_pulse_timer = interval
		_idle_pulse()


func _on_level_changed(old: int, new_level: int) -> void:
	if new_level <= old:
		return  # only buzz when getting closer
	match new_level:
		1: _buzz(50,  0.25)                  # faint single tap
		2: _double_buzz(70, 0.40, 0.15)      # two taps
		3: _double_buzz(100, 0.60, 0.12)     # stronger double
		4: _buzz(280, 0.90)                  # long sustained


func _idle_pulse() -> void:
	match _current_level:
		2: _buzz(40,  0.22)
		3: _buzz(55,  0.42)
		4: _buzz(70,  0.60)


func _double_buzz(duration: int, amplitude: float, gap: float) -> void:
	_buzz(duration, amplitude)
	# Second buzz on a deferred call — can't sleep in GDScript without a timer
	var t := get_tree().create_timer(gap)
	t.timeout.connect(func(): _buzz(duration, amplitude))


func _buzz(duration: int, amplitude: float) -> void:
	if _is_android:
		Input.vibrate_handheld(duration, amplitude)


func _level_for(normalized: float) -> int:
	for i in range(THRESHOLDS.size() - 1, 0, -1):
		if normalized >= THRESHOLDS[i]:
			return i
	return 0
