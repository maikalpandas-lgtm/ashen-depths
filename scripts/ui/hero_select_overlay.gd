extends CanvasLayer
## Pick the hero for the run. A run is ONE hero (DESIGN §5, revised 22.07.2026),
## so this is the first real decision a player makes and it has to show what the
## choice actually costs: HP, role, and the starting deck.
##
## Opened by the title screen; emits nothing — it starts the run itself, because
## the run cannot begin until a hero exists.

const Party = preload("res://scripts/party.gd")
const CardDB = preload("res://scripts/cards/card_db.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const PORTRAIT := 190
const MINI_CARD := Vector2(74, 104)

signal hero_chosen(hero_id: String)

var _root: Control = null
var _row: HBoxContainer = null
var _picked := false


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root != null and _root.visible


func open() -> void:
	_picked = false
	_render()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _choose(hero_id: String) -> void:
	if _picked:
		return
	_picked = true
	if Sfx:
		Sfx.play("ui_click")
	if GameState:
		GameState.new_run(0, hero_id)
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hero_chosen.emit(hero_id)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 40
	col.offset_bottom = -40
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(col)

	var title := Label.new()
	title.text = "КТО СПУСТИТСЯ"
	UiTheme.as_display(title, 40, Color(1.0, 0.87, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Один герой на весь спуск. Колода и запас сил — его."
	UiTheme.as_title(sub, 16, Color(0.74, 0.72, 0.68))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 26)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_row)


func _render() -> void:
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	for hero_id in Party.PLAYABLE:
		_row.add_child(_make_card(str(hero_id)))


func _make_card(hero_id: String) -> Control:
	var def: Dictionary = Party.HEROES.get(hero_id, {})
	if def.is_empty():
		return Control.new()
	var colour: Color = def["colour"]

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(330, 470)
	btn.focus_mode = Control.FOCUS_NONE
	UiTheme.cartoon_button(btn, 1, Color(0.13, 0.11, 0.15))
	btn.pressed.connect(func(): _choose(hero_id))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_right = -14
	box.offset_top = 12
	box.offset_bottom = -12
	box.add_theme_constant_override("separation", 6)
	# The button owns the click; nothing inside may swallow it (see AGENTS.md)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)

	var portrait := TextureRect.new()
	portrait.texture = CardView.load_art(str(def["portrait"]))
	portrait.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait)

	var name_label := Label.new()
	name_label.text = str(def["name"]).to_upper()
	UiTheme.as_display(name_label, 26, colour)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	var role := Label.new()
	role.text = "%s  ·  ❤ %d" % [def["role"], int(def["hp"])]
	UiTheme.as_title(role, 15, Color(0.86, 0.84, 0.8))
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(role)

	var blurb := Label.new()
	blurb.text = str(def.get("blurb", ""))
	UiTheme.as_title(blurb, 13, Color(0.68, 0.66, 0.63))
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(0, 36)
	box.add_child(blurb)

	# Starting deck, stacked by count — the choice is mostly WHAT YOU DRAW
	var deck_row := HFlowContainer.new()
	deck_row.alignment = FlowContainer.ALIGNMENT_CENTER
	deck_row.add_theme_constant_override("h_separation", 4)
	deck_row.add_theme_constant_override("v_separation", 4)
	deck_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(deck_row)

	var counts := {}
	var order: Array = []
	for card_id in def["deck"]:
		var key := str(card_id)
		if not counts.has(key):
			counts[key] = 0
			order.append(key)
		counts[key] += 1
	for key in order:
		deck_row.add_child(_mini_card(str(key), int(counts[key]), colour))

	return btn


func _mini_card(card_id: String, count: int, colour: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = MINI_CARD
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := CardDB.get_card(card_id)
	if card.is_empty():
		return holder
	holder.add_child(CardView.build(card, colour, MINI_CARD))
	if count > 1:
		var badge := Label.new()
		badge.text = "×%d" % count
		UiTheme.as_title(badge, 15, Color(1.0, 0.95, 0.82))
		badge.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.05))
		badge.add_theme_constant_override("outline_size", 5)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -34
		badge.offset_top = -22
		badge.offset_right = -3
		badge.offset_bottom = -2
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(badge)
	return holder
