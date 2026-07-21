extends Node3D
## Main scene: fog world + dungeon + player + HUD / minimap.

@onready var dungeon: Node3D = $Dungeon
@onready var player: CharacterBody3D = $Player
@onready var hud_title: Label = $UI/LeftPanel/Margin/VBox/TitleLabel
@onready var hud_floor: Label = $UI/LeftPanel/Margin/VBox/FloorLabel
@onready var hud_gold: Label = $UI/LeftPanel/Margin/VBox/StatsRow/GoldLabel
@onready var hud_hp: Label = $UI/LeftPanel/Margin/VBox/StatsRow/HpLabel
@onready var hud_hint: Label = $UI/BottomBar/Margin/HintLabel
@onready var minimap: Control = $UI/LeftPanel/Margin/VBox/MinimapFrame/Minimap
@onready var hp_bar: ProgressBar = $UI/LeftPanel/Margin/VBox/HpBar

const MAX_HP := 88


func _ready() -> void:
	if player.has_method("setup_dungeon"):
		player.setup_dungeon(dungeon)
	if dungeon.has_signal("generation_finished"):
		dungeon.generation_finished.connect(_on_dungeon_ready)
	if GameState:
		GameState.chest_opened.connect(_on_chest_opened)
		GameState.encounter_started.connect(_on_encounter)
		GameState.dungeon_ready.connect(_on_dungeon_ready)

	if minimap and minimap.has_method("setup"):
		minimap.setup(dungeon, player)

	hp_bar.max_value = MAX_HP
	hp_bar.value = MAX_HP
	_update_hud()
	hud_hint.text = "W/S step · A/D turn 90° · R new dungeon · Esc menu  |  camera locked forward"

	if dungeon.get("start_cell") != null:
		var start: Vector2i = dungeon.start_cell
		_place_player(dungeon.cell_to_world(start))
		if minimap and minimap.has_method("clear_fog"):
			minimap.clear_fog()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("regenerate_dungeon"):
		if minimap and minimap.has_method("clear_fog"):
			minimap.clear_fog()
		if dungeon.has_method("generate"):
			dungeon.generate()


func _on_dungeon_ready(start_world: Vector3) -> void:
	if player.has_method("setup_dungeon"):
		player.setup_dungeon(dungeon)
	_place_player(start_world)
	if minimap and minimap.has_method("setup"):
		minimap.setup(dungeon, player)
	if minimap and minimap.has_method("clear_fog"):
		minimap.clear_fog()
	_update_hud()
	hud_hint.text = "W/S step · A/D turn 90° · R new dungeon · Esc menu"


func _place_player(pos: Vector3) -> void:
	if player.has_method("teleport_to"):
		player.teleport_to(pos)
	else:
		player.global_position = pos


func _on_chest_opened(amount: int) -> void:
	_update_hud()
	hud_hint.text = "Chest +%d gold" % amount


func _on_encounter(encounter_id: String) -> void:
	hud_hint.text = "⚔ Encounter: %s  — card combat in Phase 3" % encounter_id


func _update_hud() -> void:
	var seed_val := 0
	var floor_i := 1
	var gold := 0
	if GameState:
		seed_val = GameState.current_seed
		floor_i = GameState.floor_index
		gold = GameState.gold
	hud_title.text = "Ashen Depths"
	hud_floor.text = "Root Labyrinth  ·  F%d" % floor_i
	hud_gold.text = "🪙  %d" % gold
	hud_hp.text = "❤  %d/%d" % [int(hp_bar.value), MAX_HP]
