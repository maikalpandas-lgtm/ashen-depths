extends CanvasLayer
## Post-combat draft layer 1 (DESIGN §7.6): pick 1 of 3 cards, or skip → gold.
##
## Opens after a pack is cleared. The chosen card is permanently appended to one
## hero's deck (owner colour on the card face). Skip pays gold instead of a card.

const CardDB = preload("res://scripts/cards/card_db.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const Party = preload("res://scripts/party.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const CARD_W := 150
const CARD_H := 210
const SKIP_GOLD := 12

var _root: Control = null
var _row: HBoxContainer = null
var _title: Label = null
var _offers: Array = []  ## [{card, owner}]


func _ready() -> void:
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false
	if GameState and GameState.has_signal("draft_requested"):
		GameState.draft_requested.connect(_on_draft_requested)


func is_open() -> bool:
	return _root != null and _root.visible


func _on_draft_requested(kill_gold: int) -> void:
	open(kill_gold)


func open(kill_gold: int = 0) -> void:
	_offers = _roll_offers()
	_title.text = "ДОБЫЧА  ·  выбери карту  ·  (+%d золота за стаю)" % kill_gold
	_rebuild_row()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Sfx:
		Sfx.play("draft_open")
		if kill_gold > 0:
			Sfx.play("gold", -4.0)


func _roll_offers() -> Array:
	var pool: Array = CardDB.ids()
	pool.shuffle()
	var party: Party = GameState.party if GameState and GameState.party else Party.new()
	var out: Array = []
	var n := mini(3, pool.size())
	for i in range(n):
		var owner_id: String = "kael"
		if not party.members.is_empty():
			owner_id = str(party.members[i % party.members.size()]["id"])
		out.append({"card": pool[i], "owner": owner_id})
	return out


func _rebuild_row() -> void:
	for c in _row.get_children():
		c.queue_free()
	var party: Party = GameState.party if GameState and GameState.party else null
	for i in range(_offers.size()):
		var offer: Dictionary = _offers[i]
		var def: Dictionary = CardDB.get_card(offer["card"])
		if def.is_empty():
			continue
		var colour := Color(0.8, 0.8, 0.8)
		if party:
			for m in party.members:
				if str(m["id"]) == str(offer["owner"]):
					colour = m.get("colour", colour)
					break
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(CARD_W + 8, CARD_H + 36)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(col)
		var face := CardView.build(def, colour, Vector2(CARD_W, CARD_H))
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(face)
		var owner_lbl := Label.new()
		owner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		owner_lbl.add_theme_font_size_override("font_size", 12)
		owner_lbl.add_theme_color_override("font_color", colour)
		var owner_name := str(offer["owner"])
		if party:
			for m in party.members:
				if str(m["id"]) == str(offer["owner"]):
					owner_name = str(m["name"])
					break
		owner_lbl.text = "→ %s" % owner_name
		if UiTheme.title_font():
			owner_lbl.add_theme_font_override("font", UiTheme.title_font())
		col.add_child(owner_lbl)
		var idx := i
		btn.pressed.connect(func(): _pick(idx))
		_row.add_child(btn)


func _pick(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return
	var offer: Dictionary = _offers[index]
	if GameState and GameState.party:
		GameState.party.add_card(str(offer["owner"]), str(offer["card"]))
		print("[Draft] +%s → %s" % [offer["card"], offer["owner"]])
	if Sfx:
		Sfx.play("draft_pick")
	_close("Карта взята: %s" % CardDB.get_card(offer["card"]).get("name", offer["card"]))


func _skip() -> void:
	if GameState:
		GameState.gold += SKIP_GOLD
	print("[Draft] skip +%d gold" % SKIP_GOLD)
	if Sfx:
		Sfx.play("draft_skip")
		Sfx.play("gold", -4.0)
	_close("Пропуск · +%d золота" % SKIP_GOLD)


func _close(hint: String = "") -> void:
	_root.visible = false
	# Reward chain: level-up → item loot → explore (DESIGN §7.6 + §8.3)
	if GameState and (GameState.pending_level_ups > 0 or not GameState.pending_loot.is_empty()):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameState.continue_reward_chain(hint)
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if GameState and GameState.has_signal("draft_finished"):
		GameState.draft_finished.emit(hint)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.07, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 18)
	col.offset_left = 48
	col.offset_right = -48
	col.offset_top = 40
	col.offset_bottom = -40
	_root.add_child(col)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	if UiTheme.display_font():
		_title.add_theme_font_override("font", UiTheme.display_font())
	col.add_child(_title)

	var hint := Label.new()
	hint.text = "1 из 3 в колоду героя  ·  или пропуск за золото"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.88))
	col.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 22)
	col.add_child(_row)

	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer2)

	var skip := Button.new()
	skip.text = "Пропуск  ·  +%d 🪙" % SKIP_GOLD
	skip.custom_minimum_size = Vector2(220, 40)
	skip.pressed.connect(_skip)
	var center := CenterContainer.new()
	center.add_child(skip)
	col.add_child(center)
