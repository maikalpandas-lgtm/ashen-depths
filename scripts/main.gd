extends Node3D
## Main scene: fog world + dungeon + player + left HUD / minimap.

@onready var dungeon: Node3D = $Dungeon
@onready var player: CharacterBody3D = $Player
@onready var left_panel: PanelContainer = $UI/LeftPanel
@onready var hud_hint: Label = $UI/BottomBar/Margin/HintLabel
@onready var bottom_bar: PanelContainer = $UI/BottomBar

const SHOT_DIR := "res://shots"
const LeftPanelScript = preload("res://scripts/ui/left_panel.gd")

var minimap: Control = null


func _ready() -> void:
	# Grab minimap before left panel rebuild destroys the old tree
	minimap = get_node_or_null("UI/LeftPanel/Margin/VBox/MinimapFrame/Minimap") as Control
	_setup_left_hud()

	if player.has_method("setup_dungeon"):
		player.setup_dungeon(dungeon)
	if dungeon.has_signal("generation_finished"):
		dungeon.generation_finished.connect(_on_dungeon_ready)
	if GameState:
		GameState.chest_opened.connect(_on_chest_opened)
		GameState.encounter_started.connect(_on_encounter)
		GameState.dungeon_ready.connect(_on_dungeon_ready)
		if GameState.has_signal("floor_changed"):
			GameState.floor_changed.connect(_on_floor_changed)
		if GameState.has_signal("draft_finished"):
			GameState.draft_finished.connect(_on_draft_finished)
		if GameState.has_signal("defeat_finished"):
			GameState.defeat_finished.connect(_on_defeat_finished)

	if minimap and minimap.has_method("setup"):
		minimap.setup(dungeon, player)

	_update_hud()
	hud_hint.text = "W/S · A/D · B рюкзак · C колода · костёр → лавка → этаж"

	if dungeon.get("start_cell") != null:
		var start: Vector2i = dungeon.start_cell
		_place_player(dungeon.cell_to_world(start))
		if minimap and minimap.has_method("clear_fog"):
			minimap.clear_fog()


## Rebuild left column like the competitor: big map, portrait, gold, inv, gear.
func _setup_left_hud() -> void:
	var held_map: Control = minimap
	if held_map and held_map.get_parent():
		held_map.get_parent().remove_child(held_map)

	# Replace panel content with competitor-style layout
	left_panel.set_script(LeftPanelScript)
	# set_script does not re-call _ready if the node already entered the tree
	if left_panel.has_method("_build"):
		left_panel.call("_build")

	# Compact competitor-scale panel (~188px wide)
	left_panel.offset_left = 10.0
	left_panel.offset_top = 10.0
	left_panel.offset_right = 200.0
	left_panel.offset_bottom = 560.0

	if held_map:
		var slot: Control = left_panel.call("take_minimap_slot") as Control
		if slot:
			slot.add_child(held_map)
			held_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			held_map.offset_left = 0
			held_map.offset_top = 0
			held_map.offset_right = 0
			held_map.offset_bottom = 0
		minimap = held_map
		if left_panel.has_method("bind_minimap"):
			left_panel.call("bind_minimap", minimap)

	if left_panel.has_signal("inventory_pressed"):
		if not left_panel.inventory_pressed.is_connected(_on_inventory):
			left_panel.inventory_pressed.connect(_on_inventory)
	if left_panel.has_signal("settings_pressed"):
		if not left_panel.settings_pressed.is_connected(_on_settings):
			left_panel.settings_pressed.connect(_on_settings)

	bottom_bar.offset_left = 212.0


func _on_inventory() -> void:
	if Sfx:
		Sfx.play("ui_click")
	var pack := get_node_or_null("BackpackOverlay")
	if pack and pack.has_method("toggle"):
		pack.call("toggle")
	else:
		hud_hint.text = "Рюкзак (B) · колода (C)"


func _on_settings() -> void:
	if Sfx:
		Sfx.play("ui_click")
	var settings := get_node_or_null("SettingsOverlay")
	if settings and settings.has_method("open"):
		settings.call("open")
	else:
		hud_hint.text = "Esc — пауза / громкость"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("regenerate_dungeon"):
		if minimap and minimap.has_method("clear_fog"):
			minimap.clear_fog()
		if dungeon.has_method("generate"):
			dungeon.generate()
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_F9:
			_save_shot()


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


func _on_draft_finished(hint: String) -> void:
	_update_hud()
	if hint != "":
		hud_hint.text = hint


func _on_defeat_finished(choice: String) -> void:
	if choice == "restart":
		if minimap and minimap.has_method("clear_fog"):
			minimap.clear_fog()
		var seed_val: int = GameState.current_seed if GameState else randi()
		if dungeon.has_method("generate"):
			dungeon.generate(seed_val)
		hud_hint.text = "Новый забег"
	_update_hud()


func _on_floor_changed(new_floor: int) -> void:
	if minimap and minimap.has_method("clear_fog"):
		minimap.clear_fog()
	var seed_val: int = GameState.current_seed if GameState else randi()
	if dungeon.has_method("generate"):
		dungeon.generate(seed_val)
	_update_hud()
	var realm := "Рудники" if new_floor < 3 else "Навь"
	hud_hint.text = "↓ Этаж %d · %s" % [new_floor, realm]
	# Soundscape follows the realm — same boundary as the bestiary
	# (EnemySprites.NAV_FROM_FLOOR), so the wood and the mobs change together.
	if Sfx:
		Sfx.set_biome("mine" if new_floor < 3 else "nav")


func _update_hud() -> void:
	if left_panel and left_panel.has_method("refresh"):
		left_panel.call("refresh")
