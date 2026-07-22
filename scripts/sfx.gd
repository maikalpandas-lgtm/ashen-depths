extends Node
## SFX pool + bus volume API. Clips in assets/audio/sfx/ (Kenney CC0).
##
## process_mode ALWAYS so combat (tree paused) still hears hits.

const SFX_DIR := "res://assets/audio/sfx/"

const CATALOG := {
	"step": ["step_0", "step_1", "step_2", "step_3", "step_4"],
	"turn": "turn",
	"bump": "bump",
	"combat_start": "combat_start",
	"card_pick": "card_pick",
	"card_play": "card_play",
	"slash": ["slash_0", "slash_1", "slash_2"],
	"hit": ["hit_0", "hit_1", "hit_2"],
	"hit_heavy": "hit_heavy",
	"block": "block",
	"party_hit": "party_hit",
	"enemy_die": "enemy_die",
	"fire": "fire",
	"spell": "spell",
	"ui_click": "ui_click",
	"ui_hover": "ui_hover",
	"end_turn": "end_turn",
	"victory": "victory",
	"defeat": "defeat",
	"draft_open": "draft_open",
	"draft_pick": "draft_pick",
	"draft_skip": "draft_skip",
	"gold": "gold",
	"chest": "chest",
	"floor_down": "floor_down",
	"miss": "miss",
}

const POOL_SIZE := 10
const SAVE_PATH := "user://audio_settings.cfg"

var _cache: Dictionary = {}
var _pool: Array = []
var _pool_i: int = 0
var _rng := RandomNumberGenerator.new()

## Linear 0..1 volumes
var master_vol: float = 1.0
var music_vol: float = 0.55
var sfx_vol: float = 0.85


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer_%d" % i
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)
	load_settings()
	apply_volumes()


func play(id: String, volume_db: float = 0.0, pitch_var: float = 0.06) -> void:
	var entry = CATALOG.get(id, null)
	if entry == null:
		return
	var stem: String
	if entry is Array:
		var arr: Array = entry
		if arr.is_empty():
			return
		stem = str(arr[_rng.randi_range(0, arr.size() - 1)])
	else:
		stem = str(entry)
	var stream := _load_stream(stem)
	if stream == null:
		return
	var player := _next_player()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	if pitch_var > 0.0:
		player.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	else:
		player.pitch_scale = 1.0
	player.play()


func set_master_volume(linear: float) -> void:
	master_vol = clampf(linear, 0.0, 1.0)
	apply_volumes()


func set_music_volume(linear: float) -> void:
	music_vol = clampf(linear, 0.0, 1.0)
	apply_volumes()


func set_sfx_volume(linear: float) -> void:
	sfx_vol = clampf(linear, 0.0, 1.0)
	apply_volumes()


func apply_volumes() -> void:
	_set_bus_linear("Master", master_vol)
	_set_bus_linear("Music", music_vol)
	_set_bus_linear("SFX", sfx_vol)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_vol)
	cfg.set_value("audio", "music", music_vol)
	cfg.set_value("audio", "sfx", sfx_vol)
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	master_vol = float(cfg.get_value("audio", "master", master_vol))
	music_vol = float(cfg.get_value("audio", "music", music_vol))
	sfx_vol = float(cfg.get_value("audio", "sfx", sfx_vol))


func _set_bus_linear(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _next_player() -> AudioStreamPlayer:
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	return p


func _load_stream(stem: String) -> AudioStream:
	if _cache.has(stem):
		return _cache[stem]
	var path := SFX_DIR + stem + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null and FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		push_warning("[Sfx] missing: %s" % path)
	_cache[stem] = stream
	return stream
