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
const SHOT_DIR := "res://shots"
const UiTheme = preload("res://scripts/ui/ui_theme.gd")


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
	UiTheme.as_display(hud_title, 20, Color(0.95, 0.88, 0.7))
	UiTheme.as_title(hud_floor, 12, Color(0.7, 0.65, 0.78))
	hud_hint.text = "W/S шаг · A/D поворот 90° · R новый данж · C колода · F9 снимок · Esc меню"

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
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_F9:
			_save_shot()


## F9 — dump the current frame to shots/. Lets the look be reviewed from the
## actual screen instead of guessing at shading maths that only shows up when
## it renders. Seed is in the name so a shot can be reproduced.
func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		hud_hint.text = "F9: no frame to capture"
		return
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var seed_val := 0
	if GameState:
		seed_val = GameState.current_seed
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/%s_seed%d.png" % [SHOT_DIR, stamp, seed_val]
	var err := img.save_png(path)
	if err == OK:
		print("[Shot] %s" % path)
		hud_hint.text = "📸 %s" % path.get_file()
	else:
		push_warning("[Shot] save failed err=%s" % err)
		hud_hint.text = "F9: save failed (%s)" % err


func _on_dungeon_ready(start_world: Vector3) -> void:
	if player.has_method("setup_dungeon"):
		player.setup_dungeon(dungeon)
	_place_player(start_world)
	if minimap and minimap.has_method("setup"):
		minimap.setup(dungeon, player)
	if minimap and minimap.has_method("clear_fog"):
		minimap.clear_fog()
	_update_hud()
	hud_hint.text = "W/S шаг · A/D поворот 90° · R новый данж · C колода · F9 снимок · Esc меню"


func _place_player(pos: Vector3) -> void:
	if player.has_method("teleport_to"):
		player.teleport_to(pos)
	else:
		player.global_position = pos


func _on_chest_opened(amount: int) -> void:
	_update_hud()
	hud_hint.text = "Сундук: +%d золота" % amount


func _on_encounter(encounter_id: String) -> void:
	hud_hint.text = "⚔ Стая: %s" % encounter_id


func _update_hud() -> void:
	var seed_val := 0
	var floor_i := 1
	var gold := 0
	if GameState:
		seed_val = GameState.current_seed
		floor_i = GameState.floor_index
		gold = GameState.gold
	hud_title.text = "Навьи Копи"
	hud_floor.text = "Лабиринты Корня  ·  этаж %d" % floor_i
	hud_gold.text = "🪙  %d" % gold
	hud_hp.text = "❤  %d/%d" % [int(hp_bar.value), MAX_HP]
