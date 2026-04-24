## AdManager — Unified ad interface for all Conspiracy Codex games.
## Wraps AppLovin MAX (primary) with fallback stubs for development/testing.
##
## Usage:
##   AdManager.show_rewarded("boost_xp", func(): player.xp *= 2)
##   AdManager.show_interstitial_if_ready()
##   AdManager.can_show_interstitial()  # respects frequency cap

extends Node

# --- Configuration ---
## Set these per-game in GameConfig or override here.
const INTERSTITIAL_CAP_SESSIONS := 3  # show interstitial every N sessions/runs
const REWARDED_COOLDOWN_SEC := 30.0   # min seconds between rewarded ads

# --- Signals ---
signal rewarded_completed(placement: String)
signal rewarded_failed(placement: String)
signal interstitial_shown()
signal ads_initialized()

# --- State ---
var _initialized := false
var _has_applovin := false
var _sessions_since_interstitial := 0
var _last_rewarded_time := -999.0
var _pending_reward_callback: Callable
var _pending_reward_placement: String
var _ads_removed := false  # set by IAP


# =====================================================================
# LIFECYCLE
# =====================================================================

func _ready() -> void:
	# Check if ads have been removed via IAP
	_ads_removed = Codex.get_value("codex", "ads_removed", false)
	
	# Try to initialize AppLovin MAX
	_try_init_applovin()


func _try_init_applovin() -> void:
	# Check if AppLovin plugin is available
	if Engine.has_singleton("AppLovinMAX"):
		_has_applovin = true
		# Initialize — replace with your actual SDK key
		var sdk_key := GameConfig.get_applovin_sdk_key()
		if sdk_key.is_empty():
			push_warning("AdManager: No AppLovin SDK key configured")
			return
		# AppLovin init would go here — see AppLovin-MAX-Godot plugin docs
		# AppLovinMAX.initialize(sdk_key, _on_sdk_initialized)
		print("AdManager: AppLovin MAX available, initializing...")
	else:
		_has_applovin = false
		print("AdManager: AppLovin not available — using stubs (dev mode)")
	
	_initialized = true
	ads_initialized.emit()


# =====================================================================
# REWARDED ADS
# =====================================================================

## Show a rewarded ad. Callback fires only on successful completion.
## If ads are removed (IAP), callback fires immediately (free reward).
func show_rewarded(placement: String, on_complete: Callable) -> void:
	# If user bought "remove ads", give reward for free
	if _ads_removed:
		on_complete.call()
		rewarded_completed.emit(placement)
		return
	
	# Cooldown check
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_rewarded_time < REWARDED_COOLDOWN_SEC:
		push_warning("AdManager: Rewarded ad on cooldown")
		rewarded_failed.emit(placement)
		return
	
	_pending_reward_callback = on_complete
	_pending_reward_placement = placement
	
	if _has_applovin:
		# Real ad path — AppLovin MAX
		var ad_unit := GameConfig.get_rewarded_ad_unit()
		# AppLovinMAX.show_rewarded_ad(ad_unit)
		# In production, connect to AppLovin signals for completion/failure
		# For now, simulate:
		_simulate_rewarded()
	else:
		# Dev stub — simulate ad with a timer
		_simulate_rewarded()


func _simulate_rewarded() -> void:
	print("AdManager: [SIMULATED] Rewarded ad for '%s'" % _pending_reward_placement)
	# In dev, just grant the reward after a brief delay
	await get_tree().create_timer(0.5).timeout
	_on_rewarded_complete()


func _on_rewarded_complete() -> void:
	_last_rewarded_time = Time.get_ticks_msec() / 1000.0
	if _pending_reward_callback.is_valid():
		_pending_reward_callback.call()
	rewarded_completed.emit(_pending_reward_placement)
	_pending_reward_callback = Callable()


func _on_rewarded_failed() -> void:
	rewarded_failed.emit(_pending_reward_placement)
	_pending_reward_callback = Callable()


# =====================================================================
# INTERSTITIAL ADS
# =====================================================================

## Call this at natural break points (end of run, between levels).
## Respects frequency cap automatically.
func show_interstitial_if_ready() -> void:
	if _ads_removed:
		return
	
	_sessions_since_interstitial += 1
	
	if _sessions_since_interstitial < INTERSTITIAL_CAP_SESSIONS:
		return
	
	_sessions_since_interstitial = 0
	
	if _has_applovin:
		var ad_unit := GameConfig.get_interstitial_ad_unit()
		# AppLovinMAX.show_interstitial(ad_unit)
		print("AdManager: [REAL] Showing interstitial")
	else:
		print("AdManager: [SIMULATED] Interstitial would show here")
	
	interstitial_shown.emit()


## Check if an interstitial would show (for UI hints).
func can_show_interstitial() -> bool:
	if _ads_removed:
		return false
	return _sessions_since_interstitial >= INTERSTITIAL_CAP_SESSIONS - 1


# =====================================================================
# IAP: REMOVE ADS
# =====================================================================

## Call when user successfully purchases "Remove Ads" IAP.
func on_ads_removed_purchased() -> void:
	_ads_removed = true
	Codex.set_value("codex", "ads_removed", true)
	Codex.save()
	print("AdManager: Ads removed via IAP")


func are_ads_removed() -> bool:
	return _ads_removed
