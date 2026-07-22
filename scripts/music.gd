extends Node
## Background music + Kenney jingles. Separate Music bus from SFX.
##
## Tracks: explore (dungeon crawl), combat (fight). Crossfades on mode change.

const MUSIC_DIR := "res://assets/audio/music/"
const JINGLE_DIR := "res://assets/audio/jingles/"

enum Mode { NONE, EXPLORE, COMBAT }

var _player: AudioStreamPlayer = null
var _jingle: AudioStreamPlayer = null
var _mode: int = Mode.NONE
var _fade_tw: Tween = null
var _enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = "Music"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_jingle = AudioStreamPlayer.new()
	_jingle.name = "JinglePlayer"
	_jingle.bus = "Music"
	_jingle.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_jingle)


func play_explore(force: bool = false) -> void:
	if not _enabled:
		return
	if _mode == Mode.EXPLORE and not force and _player.playing:
		return
	_mode = Mode.EXPLORE
	_swap_track(_load_loop("explore_loop"), -10.0)


func play_combat() -> void:
	if not _enabled:
		return
	if _mode == Mode.COMBAT and _player.playing:
		return
	_mode = Mode.COMBAT
	_swap_track(_load_loop("combat_loop"), -8.0)


func stop_music(fade: float = 0.4) -> void:
	_mode = Mode.NONE
	if _player == null or not _player.playing:
		return
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(_player, "volume_db", -40.0, fade)
	_fade_tw.tween_callback(func():
		if is_instance_valid(_player):
			_player.stop())


func play_jingle(id: String, volume_db: float = -4.0) -> void:
	if not _enabled:
		return
	var path := JINGLE_DIR + id + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	elif FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return
	_jingle.stop()
	_jingle.stream = stream
	_jingle.volume_db = volume_db
	_jingle.play()


func set_enabled(on: bool) -> void:
	_enabled = on
	if not on:
		stop_music(0.2)
		if _jingle:
			_jingle.stop()
	elif _mode == Mode.COMBAT:
		play_combat()
	elif _mode == Mode.EXPLORE:
		play_explore(true)
	else:
		play_explore(true)


func is_enabled() -> bool:
	return _enabled


func _swap_track(stream: AudioStream, target_db: float) -> void:
	if stream == null:
		return
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	if _player.playing and _player.stream == stream:
		_player.volume_db = target_db
		return
	# Quick cross: dip out, swap, rise
	_fade_tw = create_tween()
	if _player.playing:
		_fade_tw.tween_property(_player, "volume_db", -36.0, 0.35)
		_fade_tw.tween_callback(func():
			_player.stop()
			_start_stream(stream, target_db))
	else:
		_start_stream(stream, target_db)


func _start_stream(stream: AudioStream, target_db: float) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_player.stream = stream
	_player.volume_db = -28.0
	_player.play()
	if _fade_tw and _fade_tw.is_valid():
		pass
	var tw := create_tween()
	tw.tween_property(_player, "volume_db", target_db, 0.55)


func _load_loop(stem: String) -> AudioStream:
	for ext in [".mp3", ".wav", ".ogg"]:
		var path: String = MUSIC_DIR + stem + ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
		if FileAccess.file_exists(path):
			if ext == ".ogg":
				return AudioStreamOggVorbis.load_from_file(path)
			var s: Variant = load(path)
			if s is AudioStream:
				return s as AudioStream
	push_warning("[Music] missing loop: %s" % stem)
	return null
