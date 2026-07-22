extends Node
## Global run state (autoload). Expand in Phase 2–3.

const Party = preload("res://scripts/party.gd")

var current_seed: int = 0
var floor_index: int = 1
var gold: int = 0
## The three heroes of this run. Combat (Phase 3) draws its deck from here.
var party: Party = null

signal dungeon_ready(start_position: Vector3)
signal encounter_started(encounter_id: String)
## Carries WHICH enemies stand there and the node to remove once they are beaten
signal combat_requested(pack: Array, source: Node)
signal chest_opened(gold_amount: int)


func _ready() -> void:
	if party == null:
		party = Party.new()


func new_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		current_seed = randi()
	else:
		current_seed = seed_value
	floor_index = 1
	gold = 0
	party = Party.new()
