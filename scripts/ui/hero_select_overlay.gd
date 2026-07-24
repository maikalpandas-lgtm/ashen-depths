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
const HeroCardLayout = preload("res://scripts/ui/hero_card_layout.gd")

const CIRCLE_MASK = preload("res://shaders/circle_mask.gdshader")

signal hero_chosen(hero_id: String)

## Where the run happens. A second map type (open forest) sits on the SAME grid
## as the mines, so this is a one-word choice, not a different game mode.
const BIOMES := [
	{"id": "mine", "name": "НАВЬИ КОПИ", "blurb": "Тесные штольни. Тьма в двух шагах."},
	{"id": "forest", "name": "ЗАПОВЕДНЫЙ ЛЕС", "blurb": "Открытый лес под луной. Видно далеко."},
]

var _root: Control = null
var _row: HBoxContainer = null
var _biome_row: HBoxContainer = null
var _biome_buttons: Array = []
var _biome_note: Label = null
var _biome := "mine"
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
		GameState.new_run(0, hero_id, _biome)
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

	_biome_row = HBoxContainer.new()
	_biome_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_biome_row.add_theme_constant_override("separation", 14)
	col.add_child(_biome_row)

	_biome_note = Label.new()
	UiTheme.as_title(_biome_note, 14, Color(0.66, 0.64, 0.6))
	_biome_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_biome_note)
	_build_biomes()

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 26)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_row)


func _choose_biome(id: String) -> void:
	if _biome == id:
		return
	_biome = id
	if Sfx:
		Sfx.play("ui_click")
	_paint_biomes()


## Buttons are built ONCE. Selecting a biome only restyles them.
##
## The first version rebuilt the row inside the button's own `pressed` handler,
## which frees the node that is mid-signal — the exact bug that made the combat
## hand vanish when a card was played. Never free a control from its own signal.
func _build_biomes() -> void:
	_biome_buttons.clear()
	for entry in BIOMES:
		var id := str(entry["id"])
		var btn := Button.new()
		btn.text = str(entry["name"])
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func(): _choose_biome(id))
		btn.set_meta("biome", id)
		_biome_row.add_child(btn)
		_biome_buttons.append(btn)
	_paint_biomes()


func _paint_biomes() -> void:
	for btn in _biome_buttons:
		if not is_instance_valid(btn):
			continue
		var on: bool = str(btn.get_meta("biome", "")) == _biome
		UiTheme.cartoon_button(btn as Button, 16,
			Color(0.30, 0.52, 0.40) if on else Color(0.17, 0.15, 0.19))
	for entry in BIOMES:
		if str(entry["id"]) == _biome and _biome_note:
			_biome_note.text = str(entry["blurb"])


func _render() -> void:
	_paint_biomes()
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	# Size every card for the HEAVIEST deck, so the three stay identical — a row
	# of cards that each shrank to their own content looks broken.
	var worst := 0
	for hero_id in Party.PLAYABLE:
		worst = maxi(worst, _distinct_cards(str(hero_id)))
	var vp := get_viewport().get_visible_rect().size.y
	var m: Dictionary = HeroCardLayout.metrics(vp, worst)
	if bool(m.get("overflow", false)):
		push_warning("[HeroSelect] card content %.0fpx > budget %.0fpx at %dpx tall"
			% [m["content"], m["budget"], int(vp)])
	for hero_id in Party.PLAYABLE:
		_row.add_child(_make_card(str(hero_id), m))


func _distinct_cards(hero_id: String) -> int:
	var def: Dictionary = Party.HEROES.get(hero_id, {})
	var seen := {}
	for card_id in def.get("deck", []):
		seen[str(card_id)] = true
	return seen.size()


func _make_card(hero_id: String, m: Dictionary) -> Control:
	var def: Dictionary = Party.HEROES.get(hero_id, {})
	if def.is_empty():
		return Control.new()
	var colour: Color = def["colour"]

	var btn := Button.new()
	var portrait_px: float = float(m["portrait"])
	var mini: Vector2 = m["mini"]
	btn.custom_minimum_size = m["card"]
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

	# Ring + circular crop, matching the in-game panel
	var ring := PanelContainer.new()
	ring.custom_minimum_size = Vector2(portrait_px + HeroCardLayout.RING, portrait_px + HeroCardLayout.RING)
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0.10, 0.08, 0.07)
	ring_style.border_color = Color(colour, 0.9)
	ring_style.set_border_width_all(4)
	ring_style.set_corner_radius_all(int(portrait_px))
	ring_style.set_content_margin_all(5.0)
	ring.add_theme_stylebox_override("panel", ring_style)
	box.add_child(ring)

	var portrait := TextureRect.new()
	portrait.texture = CardView.load_art(str(def["portrait"]))
	portrait.custom_minimum_size = Vector2(portrait_px, portrait_px)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := ShaderMaterial.new()
	mask.shader = CIRCLE_MASK
	portrait.material = mask
	ring.add_child(portrait)

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
	blurb.custom_minimum_size = Vector2(0, HeroCardLayout.BLURB_H)
	box.add_child(blurb)

	# Starting deck, stacked by count — the choice is mostly WHAT YOU DRAW
	var deck_row := HFlowContainer.new()
	deck_row.alignment = FlowContainer.ALIGNMENT_CENTER
	deck_row.add_theme_constant_override("h_separation", int(HeroCardLayout.DECK_SEP))
	deck_row.add_theme_constant_override("v_separation", int(HeroCardLayout.DECK_SEP))
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
		deck_row.add_child(_mini_card(str(key), int(counts[key]), colour, mini))

	return btn


func _mini_card(card_id: String, count: int, colour: Color, mini: Vector2) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = mini
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := CardDB.get_card(card_id)
	if card.is_empty():
		return holder
	holder.add_child(CardView.build(card, colour, mini))
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
