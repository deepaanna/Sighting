## DailyCryptid — Server-free daily rotation using date-hash seed.
## get_today() returns the same cryptid/weather/sweet_spot for a full calendar day.

class_name DailyCryptid

const CRYPTIDS: Array = [
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
]

const WEATHERS: Array = ["clear", "fog", "rain", "night"]


static func get_today() -> Dictionary:
	var daily_idx := Codex.get_daily_index()

	var cryptid_data: Dictionary = CRYPTIDS[daily_idx % CRYPTIDS.size()]
	var weather: String = WEATHERS[(daily_idx / int(CRYPTIDS.size())) % WEATHERS.size()]

	# ±1 sweet-spot variance seeded by the daily hash — consistent within a day
	var rng := RandomNumberGenerator.new()
	rng.seed = Codex.get_daily_seed()
	var sweet_spot: int = cryptid_data["sweet_spot"] + rng.randi_range(-1, 1)
	sweet_spot = clampi(sweet_spot, 1, 6)

	return {
		"cryptid_type": cryptid_data["type"],
		"zone":         cryptid_data["zone"],
		"zone_display": cryptid_data["zone_display"],
		"weather":      weather,
		"sweet_spot":   sweet_spot,
	}
