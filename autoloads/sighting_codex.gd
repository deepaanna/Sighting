## SightingCodex — Codex write hooks specific to SIGHTING!
## Centralises cross-game signals: skepticism shifts, best_scores dict,
## game registration, and force-save at run completion.
##
## Call on_game_start() once when the field scene loads.
## Call on_run_complete() once per finished camera phase.

class_name SightingCodex

## Skepticism shift per grade (S→F). Negative = more conspiratorial.
## Applied to the shared global_skepticism float (0–100).
const SKEPTICISM_DELTA: Array = [-5.0, -3.0, -1.5, 0.0, 2.0, 4.0]


static func on_game_start() -> void:
	Codex.register_game("sighting")


static func on_run_complete(grade_idx: int, ctype: String, score: int) -> void:
	# Shift global skepticism — good sightings make the world more conspiratorial
	var delta: float = SKEPTICISM_DELTA[clampi(grade_idx, 0, SKEPTICISM_DELTA.size() - 1)]
	Codex.modify_skepticism(delta)

	# Keep a consolidated best_scores dict for cross-game queries
	_update_best_scores(ctype, score)

	# Force-save so a crash after a run never loses progress
	Codex.save()


static func _update_best_scores(ctype: String, score: int) -> void:
	var bests: Dictionary = Codex.get_value("sighting", "best_scores", {})
	if score > bests.get(ctype, 0):
		bests[ctype] = score
		Codex.set_value("sighting", "best_scores", bests)
