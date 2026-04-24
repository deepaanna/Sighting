## Codex — Cross-game persistent save system
## All Conspiracy Codex games read/write to the same ConfigFile.
## This is the connective tissue of the entire Codex universe.
##
## Usage:
##   Codex.set_value("sighting", "best_scores", {"bigfoot": 73})
##   var scores = Codex.get_value("sighting", "best_scores", {})
##   Codex.modify_skepticism(-2.0)  # conspiracy event
##   Codex.add_reputation(100)
##   Codex.save()

extends Node

# --- Constants ---
const SAVE_PATH := "user://conspiracy_codex.cfg"
const BACKUP_PATH := "user://conspiracy_codex.bak"
const AUTO_SAVE_INTERVAL := 30.0  # seconds

# --- Signals ---
signal skepticism_changed(new_value: float)
signal reputation_changed(new_value: float)
signal evidence_collected(total: int)
signal codex_loaded()
signal codex_saved()

# --- Internal ---
var _config := ConfigFile.new()
var _dirty := false
var _auto_save_timer := 0.0
var _loaded := false


# =====================================================================
# LIFECYCLE
# =====================================================================

func _ready() -> void:
	load_codex()


func _process(delta: float) -> void:
	if _dirty:
		_auto_save_timer += delta
		if _auto_save_timer >= AUTO_SAVE_INTERVAL:
			save()


# =====================================================================
# CORE SAVE / LOAD
# =====================================================================

func load_codex() -> void:
	var err := _config.load(SAVE_PATH)
	if err != OK:
		# First launch or corrupted — try backup
		err = _config.load(BACKUP_PATH)
		if err != OK:
			# True first launch — initialize defaults
			_initialize_defaults()
			save()
	_loaded = true
	codex_loaded.emit()


func save() -> void:
	# Backup current save before overwriting
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	
	var err := _config.save(SAVE_PATH)
	if err == OK:
		_dirty = false
		_auto_save_timer = 0.0
		codex_saved.emit()
	else:
		push_error("Codex: Failed to save — error code %d" % err)


func _initialize_defaults() -> void:
	# Global Codex values shared across ALL games
	_config.set_value("codex", "global_skepticism", 50.0)
	_config.set_value("codex", "theory_feed_reputation", 0)
	_config.set_value("codex", "total_evidence_collected", 0)
	_config.set_value("codex", "install_timestamp", Time.get_unix_time_from_system())
	_config.set_value("codex", "games_installed", [])
	_config.set_value("codex", "version", 1)


# =====================================================================
# GENERIC GET / SET (per-game sections)
# =====================================================================

## Get a value from a game's section. Returns default if not found.
func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return _config.get_value(section, key, default)


## Set a value in a game's section. Marks save as dirty.
func set_value(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)
	_dirty = true


## Check if a key exists in a section.
func has_value(section: String, key: String) -> bool:
	return _config.has_section_key(section, key)


## Get all keys in a section.
func get_keys(section: String) -> PackedStringArray:
	if _config.has_section(section):
		return _config.get_section_keys(section)
	return PackedStringArray()


# =====================================================================
# GLOBAL CODEX VALUES (the shared universe state)
# =====================================================================

## Global Skepticism: 0 = full conspiracy, 100 = full skeptic
## This is the master variable that affects ALL games.
func get_skepticism() -> float:
	return _config.get_value("codex", "global_skepticism", 50.0)


func modify_skepticism(delta: float) -> void:
	var current := get_skepticism()
	var new_val := clampf(current + delta, 0.0, 100.0)
	_config.set_value("codex", "global_skepticism", new_val)
	_dirty = true
	skepticism_changed.emit(new_val)


func get_skepticism_label() -> String:
	var s := get_skepticism()
	if s < 15.0: return "FULL CONSPIRACY"
	elif s < 30.0: return "Highly Conspiratorial"
	elif s < 45.0: return "Leaning Conspiratorial"
	elif s < 55.0: return "Balanced"
	elif s < 70.0: return "Leaning Skeptical"
	elif s < 85.0: return "Highly Skeptical"
	else: return "TOTAL SKEPTIC"


## Theory Feed Reputation — cumulative across all games.
func get_reputation() -> int:
	return _config.get_value("codex", "theory_feed_reputation", 0)


func add_reputation(amount: int) -> void:
	var current := get_reputation()
	_config.set_value("codex", "theory_feed_reputation", current + amount)
	_dirty = true
	reputation_changed.emit(current + amount)


## Total Evidence Collected — cross-game counter.
func get_evidence_count() -> int:
	return _config.get_value("codex", "total_evidence_collected", 0)


func add_evidence(count: int = 1) -> void:
	var current := get_evidence_count()
	_config.set_value("codex", "total_evidence_collected", current + count)
	_dirty = true
	evidence_collected.emit(current + count)


# =====================================================================
# CROSS-GAME EFFECT QUERIES
# Used by individual games to check what other games have done.
# =====================================================================

## Check if a specific game has been played (has saved data).
func is_game_active(game_section: String) -> bool:
	return _config.has_section(game_section)


## Get the amplified/debunked status of a conspiracy category from Echo Chamber.
## Returns: -1.0 (heavily debunked) to +1.0 (heavily amplified), 0 = neutral
func get_echo_bias(category: String) -> float:
	var amplified: int = get_value("echo_chamber", "amplified_%s" % category, 0)
	var debunked: int  = get_value("echo_chamber", "debunked_%s" % category, 0)
	var total: int     = amplified + debunked
	if total == 0:
		return 0.0
	return clampf(float(amplified - debunked) / float(total), -1.0, 1.0)


## Get total wraps from Flat Out (used by Sighting for dimensional rift events).
func get_flat_out_wraps() -> int:
	return get_value("flat_out", "total_wraps", 0)


## Get documents solved from Redacted (used for bonus zones in Sighting).
func get_redacted_solves() -> int:
	return get_value("redacted", "documents_solved", 0)


## Get listener count from Echo Chamber.
func get_echo_listeners() -> int:
	return get_value("echo_chamber", "listeners", 0)


# =====================================================================
# DAILY SEED — same daily content for all players, no server needed.
# =====================================================================

## Returns a deterministic seed based on today's date.
## All games use this for daily content rotation.
func get_daily_seed() -> int:
	var date := Time.get_date_dict_from_system()
	var date_str := "%04d%02d%02d" % [date.year, date.month, date.day]
	return date_str.hash()


## Returns which "daily index" we're on (days since a fixed epoch).
func get_daily_index() -> int:
	var unix := Time.get_unix_time_from_system()
	return int(unix / 86400)


# =====================================================================
# UTILITY
# =====================================================================

## Register this game as installed in the Codex.
func register_game(game_id: String) -> void:
	var games: Array = get_value("codex", "games_installed", [])
	if game_id not in games:
		games.append(game_id)
		set_value("codex", "games_installed", games)


## Force save on app quit / pause.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or \
	   what == NOTIFICATION_APPLICATION_PAUSED:
		if _dirty:
			save()


## Debug: print all Codex contents.
func debug_dump() -> void:
	print("=== CODEX DUMP ===")
	for section in _config.get_sections():
		print("[%s]" % section)
		for key in _config.get_section_keys(section):
			print("  %s = %s" % [key, _config.get_value(section, key)])
	print("=== END DUMP ===")
