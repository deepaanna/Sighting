## GameConfig — Sighting-specific constants.
## Overrides the template defaults for this game.

extends Node

func get_game_id() -> String:
	return "sighting"

func get_game_name() -> String:
	return "SIGHTING!"

func get_game_subtitle() -> String:
	return "A Conspiracy Codex Game"

func get_game_version() -> String:
	return "0.1.0"


# =====================================================================
# AD CONFIGURATION
# =====================================================================

func get_applovin_sdk_key() -> String:
	return ""

func get_rewarded_ad_unit() -> String:
	return ""

func get_interstitial_ad_unit() -> String:
	return ""

func get_banner_ad_unit() -> String:
	return ""


# =====================================================================
# MONETIZATION TUNING
# =====================================================================

func get_remove_ads_price() -> String:
	return "$1.99"

func get_interstitial_cap() -> int:
	return 3

func get_rewarded_cooldown() -> float:
	return 30.0


# =====================================================================
# GAMEPLAY TUNING
# =====================================================================

func get_session_length() -> float:
	return 60.0  # Field phase: 60 seconds

func get_xp_multiplier() -> float:
	return 1.0


# =====================================================================
# SHARE CONFIGURATION
# =====================================================================

func get_share_watermark() -> String:
	return "SIGHTING! — A Conspiracy Codex Game"

func get_share_hashtags() -> String:
	return "#ConspiracyCodex #Sighting #Cryptid"


# =====================================================================
# SCENE PATHS
# =====================================================================

func get_main_menu_scene() -> String:
	return "res://scenes/shared/main_menu.tscn"

func get_gameplay_scene() -> String:
	return "res://scenes/game_specific/field/field.tscn"

func get_result_scene() -> String:
	return "res://scenes/game_specific/result/result.tscn"


# =====================================================================
# LIFECYCLE
# =====================================================================

func _ready() -> void:
	Codex.register_game(get_game_id())
