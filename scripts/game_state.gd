extends Node
## Global run state (autoload). Expand in Phase 2–3.

var current_seed: int = 0
var floor_index: int = 1
var gold: int = 0

signal dungeon_ready(start_position: Vector3)
signal encounter_started(encounter_id: String)
signal chest_opened(gold_amount: int)


func new_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		current_seed = randi()
	else:
		current_seed = seed_value
	floor_index = 1
	gold = 0
