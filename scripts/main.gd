extends Node3D
## Main scene: fog world + dungeon + player + left HUD / minimap.

@onready var dungeon: Node3D = $Dungeon
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var player: CharacterBody3D = $Player
@onready var left_panel: PanelContainer = $UI/LeftPanel
@onready var hud_hint: Label = $UI/BottomBar/Margin/HintLabel
@onready var bottom_bar: PanelContainer = $UI/BottomBar

const SHOT_DIR := "res://shots"
const LeftPanelScript = preload("res://scripts/ui/left_panel.gd")
const EnemySprites = preload("res://scripts/enemy_sprites.gd")
const Party = preload("res://scripts/party.gd")
const KeyHints = preload("res://scripts/ui/key_hints.gd")

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
		if GameState.has_signal("drops_collected"):
			GameState.drops_collected.connect(_on_drops)
	var picker := get_node_or_null("HeroSelectOverlay")
	if picker and picker.has_signal("hero_chosen"):
		picker.hero_chosen.connect(_on_hero_chosen)

	if minimap and minimap.has_method("setup"):
		minimap.setup(dungeon, player)

	_update_hud()
	_build_key_hints()
	# Short and situational now; the permanent controls live in the key caps.
	hud_hint.text = ""

	# Debug entry points, so a visual check does not have to walk the menus:
	#   godot --path . -- --fight          straight into a normal fight
	#   godot --path . -- --fight --forest same, in the forest
	#   godot --path . -- --hero volhv     pick the hero
	# Added because verifying combat art meant clicking through the title, hero
	# select and then hunting for a pack every single time.
	if _debug_args().has("fight"):
		call_deferred("_debug_start_fight")
		return

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
	# Every rebuild, not just a floor change — the first layout of a run is
	# generated before floor_changed ever fires, and it was coming up with cave
	# fog over a forest.
	_apply_biome_environment()
	_apply_biome_sound()
	if player.has_method("setup_dungeon"):
		player.setup_dungeon(dungeon)
	_place_player(start_world)
	if minimap and minimap.has_method("setup"):
		minimap.setup(dungeon, player)
	if minimap and minimap.has_method("clear_fog"):
		minimap.clear_fog()
	_update_hud()


## The first layout is built at scene load — before the player has picked
## anything — so it is always a mine on the default biome. Rebuild once the run
## actually exists, or choosing the forest drops you in a cave with a forest
## label on the HUD.
func _on_hero_chosen(_hero_id: String) -> void:
	await _generate_with_loading()


## Generation is one long BLOCKING frame — maze, meshes, torches, props, forage,
## packs. Straight after the hero pick that froze the window, which reads as a
## crash. So: show the overlay, wait for it to actually be DRAWN, then build.
func _generate_with_loading() -> void:
	var loading := get_node_or_null("LoadingOverlay")
	var where := "НАВЬИ КОПИ"
	if GameState and str(GameState.biome) == "forest":
		where = "ЗАПОВЕДНЫЙ ЛЕС"
	if loading and loading.has_method("show_for"):
		loading.call("show_for", where)
		# Two frames: one to lay the overlay out, one to put it on screen. With
		# a single await the generation still lands before anything is drawn.
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	if minimap and minimap.has_method("clear_fog"):
		minimap.clear_fog()
	var seed_val: int = GameState.current_seed if GameState else randi()
	if dungeon.has_method("generate"):
		dungeon.generate(seed_val)
	_update_hud()
	if loading and loading.has_method("hide_now"):
		loading.call("hide_now")


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


## The cave's fog is a near-black teal that swallows everything past 11m — in a
## forest that reads as walking inside a bin bag. The wood gets a cooler, LONGER
## fog so the treeline on the horizon stays visible, which is the whole reason
## it is there.
func _apply_biome_environment() -> void:
	if world_env == null or world_env.environment == null:
		return
	var env := world_env.environment
	var forest := GameState and str(GameState.biome) == "forest"
	if forest:
		env.background_color = Color(0.05, 0.07, 0.13)
		env.ambient_light_color = Color(0.34, 0.45, 0.62)
		env.ambient_light_energy = 1.35
		env.fog_light_color = Color(0.10, 0.16, 0.26)
		env.fog_depth_begin = 6.0
		env.fog_depth_end = 34.0
	else:
		env.background_color = Color(0.012, 0.03, 0.055)
		env.ambient_light_color = Color(0.2, 0.45, 0.62)
		env.ambient_light_energy = 1.05
		env.fog_light_color = Color(0.07, 0.19, 0.31)
		env.fog_depth_begin = 2.0
		env.fog_depth_end = 11.0


func _on_floor_changed(new_floor: int) -> void:
	_apply_biome_environment()
	await _generate_with_loading()
	hud_hint.text = "↓ Этаж %d · %s" % [new_floor, _realm_name(new_floor)]
	_apply_biome_sound()


## Realm label — delegated, so the words always match the mobs that spawn.
func _realm_name(floor_i: int) -> String:
	return EnemySprites.realm_name(floor_i, str(GameState.biome) if GameState else "mine")


## Soundscape follows the same realm split as the bestiary, so the wood and the
## mobs change together (EnemySprites.realm_for).
func _apply_biome_sound() -> void:
	if Sfx == null or GameState == null:
		return
	Sfx.set_biome(EnemySprites.realm_for(GameState.floor_index, str(GameState.biome)))


func _update_hud() -> void:
	if left_panel and left_panel.has_method("refresh"):
		left_panel.call("refresh")


# ------------------------------------------------------------------ debug entry

## Command-line switches after `--`, as a set. Godot hands these back via
## OS.get_cmdline_user_args(), which is separate from the engine's own flags.
func _debug_args() -> Dictionary:
	var out := {}
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		var a := str(args[i]).lstrip("-")
		out[a] = str(args[i + 1]) if i + 1 < args.size() \
			and not str(args[i + 1]).begins_with("-") else ""
	return out


## Skip the menus, start a run, walk to a pack, open the fight.
func _debug_start_fight() -> void:
	var args := _debug_args()
	var hero := str(args.get("hero", ""))
	if hero == "":
		hero = Party.DEFAULT_HERO
	var biome := "forest" if args.has("forest") else "mine"
	var floor_i := int(args.get("floor", "1"))

	for n in ["TitleOverlay", "HeroSelectOverlay"]:
		var ov := get_node_or_null(n)
		if ov and ov.has_method("is_open") and ov.call("is_open"):
			ov.set("visible", false)
		if ov:
			var root = ov.get("_root")
			if root:
				root.visible = false
	get_tree().paused = false

	if GameState:
		GameState.new_run(0, hero, biome)
		# Floors above 1 change the bestiary and the difficulty scale, so this is
		# how a deep fight gets tested without playing to it.
		GameState.floor_index = maxi(1, floor_i)
	_apply_biome_environment()
	_apply_biome_sound()
	if dungeon.has_method("generate"):
		dungeon.generate(0)
	await get_tree().process_frame

	# Stand on a normal pack. Not a boss: bosses are a separate check.
	var kinds: Dictionary = dungeon.get("encounter_kinds")
	var target := Vector2i(-1, -1)
	if kinds:
		for cell in kinds.keys():
			if str(kinds[cell]) == "normal":
				target = cell
				break
	if target.x < 0:
		push_warning("[Debug] no normal pack on this floor")
		return
	_place_player(dungeon.cell_to_world(target))
	print("[Debug] fight: hero=%s biome=%s floor=%d cell=%s" % [hero, biome, floor_i, target])


## Key caps along the bottom bar. The old single string listed every control as
## prose and got skipped; a cap is a shape and the eye finds shapes.
func _build_key_hints() -> void:
	var existing := get_node_or_null("UI/KeyHints")
	if existing:
		existing.queue_free()
	var hints := KeyHints.new()
	hints.name = "KeyHints"
	get_node("UI").add_child(hints)
	hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# Clear of the left panel (212px) and sitting on the bottom bar
	# Derived from the panel, like the combat HUD does (see _hud_left there)
	hints.position = Vector2(left_panel.position.x + left_panel.size.x + 16.0, -34.0)
	# Explicit size and a raised z: the bottom bar Panel is a sibling drawn after
	# it, so at zero size behind that panel the caps were invisible.
	hints.size = Vector2(760.0, 26.0)
	hints.z_index = 10
	hints.set_hints([
		{"key": "W/S", "label": "шаг"},
		{"key": "A/D", "label": "поворот"},
		{"key": "B", "label": "рюкзак"},
		{"key": "C", "label": "колода"},
		{"key": "Esc", "label": "пауза"},
	])


## Hidden during a fight: the crawler keys do nothing there, and the fight has
## its own caps on the potion slots.
func set_key_hints_visible(on: bool) -> void:
	var hints := get_node_or_null("UI/KeyHints")
	if hints:
		(hints as Control).visible = on


## Potions a pack dropped. Said out loud in the bar — a reward the player never
## sees might as well not have dropped.
func _on_drops(hint: String) -> void:
	if hint != "":
		hud_hint.text = hint
	_update_hud()
