extends CanvasLayer
## Card combat screen. Opens when the crawler walks into a pack.
##
## No board (DESIGN §7.0): pick a card, pick a target, it resolves from hand.
## All rules live in combat_state.gd — this file only draws and forwards clicks,
## so the maths stays testable without a window.

const CardDB = preload("res://scripts/cards/card_db.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const Combat = preload("res://scripts/combat/combat_state.gd")
const Party = preload("res://scripts/party.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const CARD_W := 132
const CARD_H := 185

var _combat: Combat = null
var _source: Node = null  ## the pack node in the world, freed on victory
var _selected: int = -1  ## index into the hand, -1 = nothing picked

var _root: Control = null
var _enemy_row: HBoxContainer = null
var _hand_row: HBoxContainer = null
var _status: Label = null
var _log: Label = null
var _end_button: Button = null
var _banner: Label = null


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false
	if GameState and GameState.has_signal("combat_requested"):
		GameState.combat_requested.connect(_on_combat_requested)


func _on_combat_requested(pack: Array, source: Node) -> void:
	if _root.visible:
		return  # already fighting
	_source = source
	var party: Party = GameState.party if GameState and GameState.party else Party.new()
	var fight_seed: int = (GameState.current_seed if GameState else 1) + Time.get_ticks_msec()
	_combat = Combat.new(party, pack, fight_seed)
	_selected = -1
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _close() -> void:
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_combat = null
	_source = null


# ---------------------------------------------------------------- construction

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 30
	col.offset_right = -30
	col.offset_top = 20
	col.offset_bottom = -18
	col.add_theme_constant_override("separation", 10)
	_root.add_child(col)

	_banner = Label.new()
	UiTheme.as_title(_banner, 22, Color(1.0, 0.86, 0.6))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_banner)

	_enemy_row = HBoxContainer.new()
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_row.add_theme_constant_override("separation", 26)
	_enemy_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_enemy_row)

	_log = Label.new()
	_log.add_theme_font_size_override("font_size", 12)
	_log.add_theme_color_override("font_color", Color(0.68, 0.76, 0.82))
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_log)

	_status = Label.new()
	UiTheme.as_title(_status, 17, Color(0.9, 0.94, 1.0))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	col.add_child(bottom)

	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 8)
	bottom.add_child(_hand_row)

	_end_button = Button.new()
	_end_button.text = "КОНЕЦ ХОДА"
	UiTheme.style_button(_end_button, 18)
	_end_button.custom_minimum_size = Vector2(150, 52)
	_end_button.pressed.connect(_on_end_turn)
	bottom.add_child(_end_button)


# ------------------------------------------------------------------- rendering

func _refresh() -> void:
	if _combat == null:
		return
	_render_enemies()
	_render_hand()

	_status.text = "⚡ %d / %d      🛡 броня %d      🦴 кости %d      🗡 шипы %d      ❤ %d" % [
		_combat.energy, Combat.START_ENERGY, _combat.party_block,
		_combat.bones, _combat.thorns, _party_hp(),
	]
	_log.text = "   ".join(_combat.log_lines.slice(maxi(0, _combat.log_lines.size() - 3)))

	match _combat.phase:
		Combat.Phase.WON:
			_banner.text = "СТАЯ ПОБИТА"
			_end_button.text = "ДАЛЬШЕ"
		Combat.Phase.LOST:
			_banner.text = "ДРУЖИНА ПАЛА"
			_end_button.text = "ДАЛЬШЕ"
		_:
			_banner.text = "ХОД %d  —  выбери карту, затем цель" % _combat.turn
			_end_button.text = "КОНЕЦ ХОДА"


func _render_enemies() -> void:
	for c in _enemy_row.get_children():
		c.queue_free()
	for i in range(_combat.enemies.size()):
		_enemy_row.add_child(_make_enemy(i))


func _make_enemy(index: int) -> Control:
	var e: Dictionary = _combat.enemies[index]
	var dead := int(e["hp"]) <= 0

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(190, 0)
	box.alignment = BoxContainer.ALIGNMENT_END

	var intent := Label.new()
	var it: Dictionary = e["intent"]
	if dead:
		intent.text = ""
	elif it.get("type", "attack") == "block":
		intent.text = "🛡 %d" % it.get("value", 0)
		intent.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	else:
		intent.text = "🗡 %d" % it.get("value", 0)
		intent.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	intent.add_theme_font_size_override("font_size", 20)
	intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(intent)

	# The enemy is a button so the whole sprite is the target hitbox
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(180, 190)
	btn.flat = true
	btn.icon = CardView.load_art("enemy_%s" % e["id"])
	btn.expand_icon = true
	btn.disabled = dead or _selected < 0 or _combat.phase != Combat.Phase.PLAYER
	btn.modulate = Color(0.35, 0.3, 0.3, 0.55) if dead else Color.WHITE
	btn.pressed.connect(func(): _on_enemy_clicked(index))
	box.add_child(btn)

	var name_label := Label.new()
	name_label.text = str(e["name"])
	UiTheme.as_title(name_label, 13)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	var bar := ProgressBar.new()
	bar.max_value = e["max_hp"]
	bar.value = e["hp"]
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(170, 16)
	box.add_child(bar)

	var hp_label := Label.new()
	hp_label.text = "%d / %d%s" % [e["hp"], e["max_hp"],
		("   🛡 %d" % e["block"]) if int(e["block"]) > 0 else ""]
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hp_label)

	return box


func _render_hand() -> void:
	for c in _hand_row.get_children():
		c.queue_free()
	for i in range(_combat.deck.hand.size()):
		_hand_row.add_child(_make_hand_card(i))


func _make_hand_card(index: int) -> Control:
	var entry: Dictionary = _combat.deck.hand[index]
	var card: Dictionary = CardDB.get_card(entry["card"])
	var owner_colour := Color(0.7, 0.7, 0.7)
	for m in _combat.party.members:
		if m["id"] == entry["owner"]:
			owner_colour = m["colour"]

	var playable := _combat.can_play(index)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(CARD_W, CARD_H + 18)

	var view := CardView.build(card, owner_colour, Vector2(CARD_W, CARD_H))
	# Unplayable cards grey out rather than disappear (§7.4)
	view.modulate = Color.WHITE if playable else Color(0.5, 0.5, 0.55, 0.8)
	# Selected card lifts, the way it reads in the reference
	view.position = Vector2(0, 0 if index != _selected else -16)
	holder.add_child(view)

	var hit := Button.new()
	hit.flat = true
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.disabled = not playable
	hit.pressed.connect(func(): _on_card_clicked(index))
	holder.add_child(hit)

	return holder


# ---------------------------------------------------------------- interaction

func _on_card_clicked(index: int) -> void:
	if _combat == null or _combat.phase != Combat.Phase.PLAYER:
		return
	var card := CardDB.get_card(_combat.deck.hand[index]["card"])
	# Guards and utility have no target — no reason to make the player pick one
	if int(card["damage"]) <= 0:
		_combat.play_card(index, 0)
		_selected = -1
	else:
		_selected = -1 if _selected == index else index
	_refresh()


func _on_enemy_clicked(index: int) -> void:
	if _combat == null or _selected < 0:
		return
	if int(_combat.enemies[index]["hp"]) <= 0:
		return
	_combat.play_card(_selected, index)
	_selected = -1
	_refresh()


func _on_end_turn() -> void:
	if _combat == null:
		return
	match _combat.phase:
		Combat.Phase.WON:
			_finish_victory()
		Combat.Phase.LOST:
			_finish_defeat()
		_:
			_selected = -1
			_combat.end_turn()
			_refresh()


func _finish_victory() -> void:
	var reward := 10 + _combat.turn * 2
	if GameState:
		GameState.gold += reward
	if is_instance_valid(_source):
		# Clear the grid cell too, or the minimap keeps its skull forever
		var node := _source as Node3D
		var dungeon := node.get_parent().get_parent() if node.get_parent() else null
		if dungeon and dungeon.has_method("clear_encounter_at"):
			dungeon.call("clear_encounter_at", node.global_position)
		_source.queue_free()  # the pack is gone from the corridor for good
	_close()


func _finish_defeat() -> void:
	# No death screen yet: leave the party on its feet with 1 HP each so the
	# run can continue while the meta layer does not exist.
	if GameState and GameState.party:
		for m in GameState.party.members:
			m["hp"] = maxi(1, int(m["hp"]))
	_close()


func _party_hp() -> int:
	var sum := 0
	for m in _combat.party.members:
		sum += maxi(0, int(m["hp"]))
	return sum
