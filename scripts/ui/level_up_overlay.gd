extends CanvasLayer
## Layer 2 draft (DESIGN §7.6): after a level-up, pick ONE of:
##   · upgrade a permanent card you own (+2 dmg / +2 block)
##   · add a rare/uncommon card to a random hero
##
## Separate screen from post-combat Layer 1 — never mixed on one panel.

const CardDB = preload("res://scripts/cards/card_db.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const Party = preload("res://scripts/party.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const CARD_W := 132
const CARD_H := 186

var _root: Control = null
var _title: Label = null
var _upgrade_row: HBoxContainer = null
var _rare_row: HBoxContainer = null
var _upgrade_offers: Array = []
var _rare_offers: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 9  # above draft (7) and defeat (8)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false
	if GameState and GameState.has_signal("level_up_requested"):
		GameState.level_up_requested.connect(_on_level_up_requested)


func _on_level_up_requested() -> void:
	open()


func open() -> void:
	if GameState == null or GameState.pending_level_ups <= 0:
		_finish_chain("")
		return
	_rng.randomize()
	_upgrade_offers = []
	_rare_offers = []
	if GameState.party:
		_upgrade_offers = GameState.party.roll_upgrade_offers(3, _rng)
	_rare_offers = _roll_rares(3)
	_title.text = "УРОВЕНЬ %d  ·  выбери награду  ·  (ещё %d)" % [
		GameState.level, GameState.pending_level_ups]
	_rebuild_rows()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Sfx:
		Sfx.play("draft_open")
		Sfx.play("victory", -8.0)


func _roll_rares(count: int) -> Array:
	var pool: Array = CardDB.rare_pool()
	if pool.is_empty():
		pool = CardDB.ids()
	# Shuffle with our rng
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var party: Party = GameState.party if GameState and GameState.party else Party.new()
	var out: Array = []
	for i in range(mini(count, pool.size())):
		var owner_id := "vityaz"
		if not party.members.is_empty():
			owner_id = str(party.members[_rng.randi_range(0, party.members.size() - 1)]["id"])
		out.append({"card": pool[i], "owner": owner_id})
	return out


func _rebuild_rows() -> void:
	_clear_row(_upgrade_row)
	_clear_row(_rare_row)
	var party: Party = GameState.party if GameState and GameState.party else null

	for i in range(_upgrade_offers.size()):
		var offer: Dictionary = _upgrade_offers[i]
		var def := CardDB.resolve_entry({
			"card": offer["card"],
			"plus": int(offer.get("plus", 0)) + 1,  # preview next level
		})
		var colour: Color = offer.get("colour", Color(0.8, 0.8, 0.8))
		var caption := "Улучшить  ·  %s" % offer.get("owner_name", offer["owner"])
		var idx := i
		_upgrade_row.add_child(_make_pick_btn(def, colour, caption, func(): _pick_upgrade(idx)))

	for i in range(_rare_offers.size()):
		var offer: Dictionary = _rare_offers[i]
		var def := CardDB.get_card(str(offer["card"]))
		var colour := Color(0.75, 0.7, 0.9)
		var owner_name := str(offer["owner"])
		if party:
			for m in party.members:
				if str(m["id"]) == str(offer["owner"]):
					colour = m.get("colour", colour)
					owner_name = str(m["name"])
					break
		var rarity := str(def.get("rarity", "rare"))
		var caption := "%s  ·  → %s" % [rarity, owner_name]
		var idx := i
		_rare_row.add_child(_make_pick_btn(def, colour, caption, func(): _pick_rare(idx)))


func _make_pick_btn(def: Dictionary, colour: Color, caption: String, on_press: Callable) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(CARD_W + 8, CARD_H + 40)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(on_press)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(col)
	var face := CardView.build(def, colour, Vector2(CARD_W, CARD_H))
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(face)
	var lbl := Label.new()
	lbl.text = caption
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.86, 0.75))
	if UiTheme.title_font():
		lbl.add_theme_font_override("font", UiTheme.title_font())
	col.add_child(lbl)
	return btn


func _pick_upgrade(index: int) -> void:
	if index < 0 or index >= _upgrade_offers.size():
		return
	var offer: Dictionary = _upgrade_offers[index]
	if GameState and GameState.party:
		GameState.party.upgrade_card(str(offer["owner"]), int(offer["deck_index"]))
	if Sfx:
		Sfx.play("draft_pick")
	var name_s := str(CardDB.get_card(str(offer["card"])).get("name", offer["card"]))
	_consume_and_continue("Улучшено: %s+" % name_s)


func _pick_rare(index: int) -> void:
	if index < 0 or index >= _rare_offers.size():
		return
	var offer: Dictionary = _rare_offers[index]
	if GameState and GameState.party:
		GameState.party.add_card(str(offer["owner"]), str(offer["card"]))
	if Sfx:
		Sfx.play("draft_pick")
	var name_s := str(CardDB.get_card(str(offer["card"])).get("name", offer["card"]))
	_consume_and_continue("Редкая: %s" % name_s)


func _consume_and_continue(hint: String) -> void:
	if GameState:
		GameState.consume_level_up()
	_root.visible = false
	if GameState and GameState.pending_level_ups > 0:
		# Another level stacked — open again
		open()
		return
	_finish_chain(hint)


func _finish_chain(hint: String) -> void:
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if GameState and GameState.has_signal("level_up_finished"):
		GameState.level_up_finished.emit(hint)
	if GameState and GameState.has_signal("draft_finished"):
		# Resume explore HUD path shared with layer 1
		GameState.draft_finished.emit(hint if not hint.is_empty() else "Уровень получен")


func _clear_row(row: HBoxContainer) -> void:
	if row == null:
		return
	for c in row.get_children():
		c.queue_free()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.08, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 12)
	col.offset_left = 36
	col.offset_right = -36
	col.offset_top = 28
	col.offset_bottom = -28
	_root.add_child(col)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	if UiTheme.display_font():
		_title.add_theme_font_override("font", UiTheme.display_font())
	col.add_child(_title)

	var hint := Label.new()
	hint.text = "Одно из двух: улучшить карту из колоды  ·  или  ·  взять редкую/необычную"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	col.add_child(hint)

	var up_lbl := Label.new()
	up_lbl.text = "— УЛУЧШЕНИЕ —"
	up_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_lbl.add_theme_font_size_override("font_size", 15)
	up_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	col.add_child(up_lbl)

	_upgrade_row = HBoxContainer.new()
	_upgrade_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_upgrade_row.add_theme_constant_override("separation", 16)
	col.add_child(_upgrade_row)

	var rare_lbl := Label.new()
	rare_lbl.text = "— РЕДКАЯ КАРТА —"
	rare_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rare_lbl.add_theme_font_size_override("font_size", 15)
	rare_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.55))
	col.add_child(rare_lbl)

	_rare_row = HBoxContainer.new()
	_rare_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_rare_row.add_theme_constant_override("separation", 16)
	col.add_child(_rare_row)
