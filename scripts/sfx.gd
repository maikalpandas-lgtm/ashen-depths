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

## Per-biome replacements. A forest does not sound like a mine: boots land on
## leaf litter instead of stone, and walking into a tree is a dull thud, not a
## rock knock.
##
## Anything NOT listed here falls through to CATALOG — a sword is a sword in any
## biome. And a listed clip that is not on disk yet falls back too, so the forest
## is playable with zero new files and simply gets better as they land.
const BIOME_SFX := {
	"forest": {
		"step": ["forest_step_0", "forest_step_1", "forest_step_2", "forest_step_3"],
		"bump": "forest_bump",
		"chest": "forest_chest",
		"floor_down": "forest_path",
	},
}

## Every soundscape the game can be in. `mine` is the cave it shipped with.
const BIOMES := ["mine", "nav", "forest"]

## Looping background bed, per biome. Not music — this rides the SFX bus, so a
## player who turns the music off still hears the wood.
const AMBIENCE := {
	"mine": "amb_cave",
	"nav": "amb_nav",
	"forest": "amb_forest",
}

const POOL_SIZE := 10
const SAVE_PATH := "user://audio_settings.cfg"

const AMBIENCE_DB := -14.0

var _cache: Dictionary = {}
var _pool: Array = []
var _pool_i: int = 0
var _rng := RandomNumberGenerator.new()
var _ambience: AudioStreamPlayer = null
## Which soundscape is live. "mine" is the cave the game already had.
var biome: String = "mine"

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
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	_ambience.bus = "SFX"
	_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambience)
	load_settings()
	apply_volumes()
	_start_ambience()


func play(id: String, volume_db: float = 0.0, pitch_var: float = 0.06) -> void:
	var stream := _pick_stream(id)
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


## Biome clip if there is one AND it exists on disk, otherwise the base clip.
## The fallback is the point: a half-finished forest pack must not go silent.
func _pick_stream(id: String) -> AudioStream:
	var over = (BIOME_SFX.get(biome, {}) as Dictionary).get(id, null)
	if over != null:
		var s := _load_stream(_roll(over), true)
		if s != null:
			return s
	var entry = CATALOG.get(id, null)
	if entry == null:
		return null
	return _load_stream(_roll(entry))


func _roll(entry) -> String:
	if entry is Array:
		var arr: Array = entry
		if arr.is_empty():
			return ""
		return str(arr[_rng.randi_range(0, arr.size() - 1)])
	return str(entry)


## Swap the whole soundscape. Called on floor / level change.
func set_biome(new_biome: String) -> void:
	if not BIOMES.has(new_biome):
		push_warning("[Sfx] unknown biome: %s" % new_biome)
		return
	if biome == new_biome:
		return
	biome = new_biome
	_start_ambience()


func _start_ambience() -> void:
	if _ambience == null:
		return
	var stem := str(AMBIENCE.get(biome, ""))
	var stream: AudioStream = _load_stream(stem, true) if stem != "" else null
	if stream == null:
		_ambience.stop()
		return
	# Duplicate before setting loop: the flag lives on the Resource, and the
	# cache hands the same one out everywhere.
	stream = stream.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ambience.stream = stream
	_ambience.volume_db = AMBIENCE_DB
	_ambience.play()


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


## `optional` = a clip we KNOW may not be there yet (biome packs still being
## made). Those must not warn, or the console fills with noise for assets we
## deliberately ship without — and a real missing clip stops standing out.
func _load_stream(stem: String, optional: bool = false) -> AudioStream:
	if _cache.has(stem):
		return _cache[stem]
	var path := SFX_DIR + stem + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null and FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream == null and not optional:
		push_warning("[Sfx] missing: %s" % path)
	_cache[stem] = stream
	return stream
