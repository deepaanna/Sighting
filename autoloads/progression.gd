## Progression — XP, zone unlocks, cryptid log, camera upgrades.
## Call award_run() once per completed camera phase; it reads/writes Codex directly.

class_name Progression

## XP earned by grade index (S=0 … F=5)
const XP_PER_GRADE: Array = [100, 70, 45, 20, 8, 2]

## Total cumulative XP required to unlock each zone (index mirrors DailyCryptid.CRYPTIDS).
## Zone 0 is always unlocked; zones 1-3 gate progressively.
const ZONE_XP_THRESHOLDS: Array = [0, 200, 600, 1400]

## Streak multiplier: +5% per consecutive day, capped at 1.5× (10 days).
static func streak_mult(streak: int) -> float:
	return minf(1.0 + streak * 0.05, 1.5)


## Main entry point called from result.gd after score is finalised.
## Returns a dict describing what changed so the UI can react.
static func award_run(grade_idx: int, cryptid_type: String) -> Dictionary:
	var streak  : int   = Codex.get_value("sighting", "daily_streak", 1)
	var mult    : float = streak_mult(streak)
	var base_xp : int   = XP_PER_GRADE[clampi(grade_idx, 0, XP_PER_GRADE.size() - 1)]
	var xp_earned: int  = int(base_xp * mult)

	# Accumulate total XP (sighting-specific and cross-game)
	var total_xp: int = Codex.get_value("sighting", "total_xp", 0)
	total_xp += xp_earned
	Codex.set_value("sighting", "total_xp", total_xp)

	var global_xp: int = Codex.get_value("codex", "total_evidence_collected", 0)
	Codex.set_value("codex", "total_evidence_collected", global_xp + xp_earned)

	# Zone unlock check
	var zones: Array = Codex.get_value("sighting", "zones_unlocked", [0])
	var new_zone_idx: int = -1
	for i in ZONE_XP_THRESHOLDS.size():
		if not (i in zones) and total_xp >= ZONE_XP_THRESHOLDS[i]:
			zones.append(i)
			new_zone_idx = i
	Codex.set_value("sighting", "zones_unlocked", zones)

	# Cryptid photograph log
	var photographed: Array = Codex.get_value("sighting", "cryptids_photographed", [])
	var is_new_cryptid := false
	if cryptid_type != "" and not (cryptid_type in photographed):
		photographed.append(cryptid_type)
		is_new_cryptid = true
	Codex.set_value("sighting", "cryptids_photographed", photographed)

	# Camera upgrade unlock checks
	var upgrades: Array     = Codex.get_value("sighting", "camera_upgrades", [])
	var new_upgrade: String = ""
	var gallery_count: int  = Codex.get_value("sighting", "gallery_photos", 0)

	if not ("vintage" in upgrades) and gallery_count >= 10:
		upgrades.append("vintage")
		new_upgrade = "vintage"

	if not ("night_vision" in upgrades):
		var weather: String = Codex.get_value("sighting", "_last_weather", "clear")
		if weather == "night":
			upgrades.append("night_vision")
			if new_upgrade == "":
				new_upgrade = "night_vision"

	if not ("vhs" in upgrades) and photographed.size() >= 4:
		upgrades.append("vhs")
		if new_upgrade == "":
			new_upgrade = "vhs"

	Codex.set_value("sighting", "camera_upgrades", upgrades)

	return {
		"xp_earned":      xp_earned,
		"total_xp":       total_xp,
		"streak":         streak,
		"streak_mult":    mult,
		"new_zone_idx":   new_zone_idx,
		"is_new_cryptid": is_new_cryptid,
		"new_upgrade":    new_upgrade,
	}


## Human-readable zone display name for a zone index.
static func zone_display(zone_idx: int) -> String:
	if zone_idx < 0 or zone_idx >= DailyCryptid.CRYPTIDS.size():
		return "UNKNOWN ZONE"
	return (DailyCryptid.CRYPTIDS[zone_idx] as Dictionary).get("zone_display", "UNKNOWN")
