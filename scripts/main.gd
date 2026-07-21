extends Node3D
## Main scene: fog world + dungeon + player.

@onready var dungeon: Node3D = $Dungeon
@onready var player: CharacterBody3D = $Player
@onready var hud_seed: Label = $UI/Margin/Panel/VBox/SeedLabel
@onready var hud_hint: Label = $UI/Margin/Panel/VBox/HintLabel
@onready var hud_gold: Label = $UI/Margin/Panel/VBox/GoldLabel


func _ready() -> void:
	if dungeon.has_signal("generation_finished"):
		dungeon.generation_finished.connect(_on_dungeon_ready)
	if GameState:
		GameState.chest_opened.connect(_on_chest_opened)
		GameState.encounter_started.connect(_on_encounter)
		GameState.dungeon_ready.connect(_on_dungeon_ready)
	_update_hud()
	# Generator may have finished before signal connect (same frame _ready order)
	if dungeon.get("start_cell") != null:
		var start: Vector2i = dungeon.start_cell
		_place_player(dungeon.cell_to_world(start) + Vector3(0, 0.5, 0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("regenerate_dungeon"):
		if dungeon.has_method("generate"):
			dungeon.generate()


func _on_dungeon_ready(start_world: Vector3) -> void:
	_place_player(start_world + Vector3(0, 0.5, 0))
	_update_hud()


func _place_player(pos: Vector3) -> void:
	if player.has_method("teleport_to"):
		player.teleport_to(pos)
	else:
		player.global_position = pos


func _on_chest_opened(amount: int) -> void:
	_update_hud()
	hud_hint.text = "Chest: +%d gold" % amount


func _on_encounter(encounter_id: String) -> void:
	hud_hint.text = "Encounter: %s (combat Phase 3)" % encounter_id


func _update_hud() -> void:
	var seed_val := 0
	var floor_i := 1
	var gold := 0
	if GameState:
		seed_val = GameState.current_seed
		floor_i = GameState.floor_index
		gold = GameState.gold
	hud_seed.text = "Ashen Depths  |  seed %s  |  floor %s" % [str(seed_val), str(floor_i)]
	hud_gold.text = "Gold: %d" % gold
