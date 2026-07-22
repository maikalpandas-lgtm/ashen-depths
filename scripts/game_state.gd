extends Node
## Global run state (autoload). Expand in Phase 2–3.

const Party = preload("res://scripts/party.gd")

## Layout seed for the CURRENT floor (changes every descent).
var current_seed: int = 0
## Fixed for the whole run — floor layouts derive from this + floor_index.
var run_seed: int = 0
var floor_index: int = 1
var gold: int = 0
## The three heroes of this run. Combat (Phase 3) draws its deck from here.
var party: Party = null

signal dungeon_ready(start_position: Vector3)
signal encounter_started(encounter_id: String)
## Carries WHICH enemies stand there and the node to remove once they are beaten
signal combat_requested(pack: Array, source: Node)
signal chest_opened(gold_amount: int)
## Post-combat draft layer 1 (kill gold already banked)
signal draft_requested(kill_gold: int)
signal draft_finished(hint: String)
## After EXIT step — main regenerates dungeon for the new floor
signal floor_changed(new_floor: int)


func _ready() -> void:
	if party == null:
		party = Party.new()


func new_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		seed_value = randi()
	run_seed = seed_value
	current_seed = seed_value
	floor_index = 1
	gold = 0
	party = Party.new()


## Descend one floor. Layout seed = run_seed xor floor mix so seeds stay stable.
func advance_floor() -> void:
	floor_index += 1
	# Mild rest: restore a quarter of missing HP for each hero
	if party:
		for m in party.members:
			var max_hp: int = int(m["max_hp"])
			var hp: int = int(m["hp"])
			var miss: int = maxi(0, max_hp - hp)
			m["hp"] = hp + miss / 4
	current_seed = _seed_for_floor(floor_index)
	print("[Run] floor → %d (seed %d)" % [floor_index, current_seed])
	floor_changed.emit(floor_index)


func _seed_for_floor(floor_i: int) -> int:
	var base: int = run_seed if run_seed != 0 else current_seed
	if base == 0:
		base = 1
	# Mix floor into seed without overflowing into 0
	return absi(base * 1664525 + floor_i * 1013904223)
