## AudioManager — Centralized audio with SFX pool and music crossfade.
##
## Usage:
##   AudioManager.play_sfx("stamp")          # one-shot from preloaded pool
##   AudioManager.play_music("ambient_spy")  # crossfade to new track
##   AudioManager.stop_music(1.0)            # fade out over 1 second

extends Node

const MAX_SFX_PLAYERS := 8
const MUSIC_FADE_SEC := 1.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _music_player: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer  # for crossfade
var _sfx_cache: Dictionary = {}  # name -> AudioStream
var _music_cache: Dictionary = {}
var _master_volume := 1.0
var _sfx_volume := 1.0
var _music_volume := 0.7


func _ready() -> void:
	# Create SFX pool
	for i in MAX_SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)
	
	# Create dual music players for crossfade
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	
	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Music"
	add_child(_music_player_b)


## Play a one-shot SFX by name.
## Looks for "res://resources/audio/sfx/{name}.wav" (or .ogg / .mp3).
func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	var stream := _get_sfx(sfx_name)
	if stream == null:
		return
	
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % MAX_SFX_PLAYERS
	player.stream = stream
	player.volume_db = volume_db
	player.play()


## Play music with crossfade. Looks for "res://resources/audio/music/{name}.ogg".
func play_music(music_name: String, fade_sec: float = MUSIC_FADE_SEC) -> void:
	var stream := _get_music(music_name)
	if stream == null:
		return
	
	# Crossfade: fade out current, fade in new
	var old := _music_player
	var new_p := _music_player_b
	
	new_p.stream = stream
	new_p.volume_db = -40.0
	new_p.play()
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(old, "volume_db", -40.0, fade_sec)
	tween.tween_property(new_p, "volume_db", linear_to_db(_music_volume), fade_sec)
	await tween.finished
	
	old.stop()
	
	# Swap references
	_music_player = new_p
	_music_player_b = old


func stop_music(fade_sec: float = MUSIC_FADE_SEC) -> void:
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, fade_sec)
	await tween.finished
	_music_player.stop()


func _get_sfx(sfx_name: String) -> AudioStream:
	if sfx_name in _sfx_cache:
		return _sfx_cache[sfx_name]
	
	for ext in ["wav", "ogg", "mp3"]:
		var path := "res://resources/audio/sfx/%s.%s" % [sfx_name, ext]
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			_sfx_cache[sfx_name] = stream
			return stream
	
	push_warning("AudioManager: SFX not found — %s" % sfx_name)
	return null


func _get_music(music_name: String) -> AudioStream:
	if music_name in _music_cache:
		return _music_cache[music_name]
	
	for ext in ["ogg", "mp3", "wav"]:
		var path := "res://resources/audio/music/%s.%s" % [music_name, ext]
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			_music_cache[music_name] = stream
			return stream
	
	push_warning("AudioManager: Music not found — %s" % music_name)
	return null
