## DailyCryptid — Server-free daily rotation using date-hash seed.
## 8 cryptids × 4 weathers × 3 sweet-spot variants = 96-day cycle before exact repeat.
## get_today() returns the same result for every player on the same calendar day.

class_name DailyCryptid

const CRYPTIDS: Array = [
	# ── Original 4 ────────────────────────────────────────────────────────
	{
		"type":         "bigfoot",
		"zone":         "pacific_nw",
		"zone_display": "PACIFIC NW",
		"sweet_spot":   3,
	},
	{
		"type":         "mothman",
		"zone":         "appalachian",
		"zone_display": "APPALACHIAN",
		"sweet_spot":   4,
	},
	{
		"type":         "chupacabra",
		"zone":         "desert_sw",
		"zone_display": "DESERT SW",
		"sweet_spot":   2,
	},
	{
		"type":         "nessie",
		"zone":         "scottish_loch",
		"zone_display": "SCOTTISH LOCH",
		"sweet_spot":   5,
	},
	# ── Unlockable 4 ──────────────────────────────────────────────────────
	{
		"type":         "jersey_devil",
		"zone":         "pine_barrens",
		"zone_display": "PINE BARRENS",
		"sweet_spot":   4,
	},
	{
		"type":         "skunk_ape",
		"zone":         "everglades",
		"zone_display": "EVERGLADES",
		"sweet_spot":   3,
	},
	{
		"type":         "champ",
		"zone":         "scottish_loch",
		"zone_display": "LAKE CHAMPLAIN",
		"sweet_spot":   5,
	},
	{
		"type":         "mokele_mbembe",
		"zone":         "pacific_nw",
		"zone_display": "CONGO BASIN",
		"sweet_spot":   3,
	},
]

const WEATHERS: Array = ["clear", "fog", "rain", "night"]


## Returns a deterministic daily config — same for all players on a given day.
## Cycle: 8 cryptids × 4 weathers × 3 sweet-spot variants = 96 unique days.
static func get_today() -> Dictionary:
	var daily_idx := Codex.get_daily_index()

	var n_c   := CRYPTIDS.size()        # 8
	var n_w   := WEATHERS.size()        # 4
	var n_s   := 3                      # sweet variants: base-1, base, base+1

	var pos    := daily_idx % (n_c * n_w * n_s)
	var s_var  := pos / (n_c * n_w)           # 0, 1, 2
	var cw     := pos % (n_c * n_w)
	var c_idx  := cw % n_c
	var w_idx  := (cw / n_c) % n_w

	var cryptid_data: Dictionary = CRYPTIDS[c_idx]
	var weather: String          = WEATHERS[w_idx]
	var sweet_spot: int          = clampi(cryptid_data["sweet_spot"] + (s_var - 1), 1, 6)

	return {
		"cryptid_type": cryptid_data["type"],
		"zone":         cryptid_data["zone"],
		"zone_display": cryptid_data["zone_display"],
		"weather":      weather,
		"sweet_spot":   sweet_spot,
	}
