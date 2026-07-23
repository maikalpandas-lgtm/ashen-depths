extends CanvasLayer
## Deck book — C toggles it.
##
## Shows the WHOLE run deck as a scrollable grid, the way the reference shows
## its upgrade screen, because that is the question a player actually has:
## "what is in my deck", not "what is in my hand right now". Cards are grouped
## by hero and duplicates are stacked with a ×N badge, so a 27-card deck reads
## as a dozen entries rather than a wall.

const CardDB = preload("res://scripts/cards/card_db.gd")
const Party = preload("res://scripts/party.gd")
const Deck = preload("res://scripts/cards/deck.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const CARD_W := 132
const CARD_H := 185


var _party: Party = null
var _deck: Deck = null
var _root: Control = null
var _deck_box: VBoxContainer = null
var _party_row: HBoxContainer = null
var _pile_label: Label = null
var _tex_cache: Dictionary = {}


func _ready() -> void:
	layer = 5
	# Must keep running while the game is paused, or the key that closes it
	# would never arrive.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_reset()
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# C, not TAB: TAB is ui_focus_next, and the GUI eats it before this runs
		# once a button has focus.
		if (event as InputEventKey).keycode == KEY_C:
			_toggle()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	var showing := not _root.visible
	_root.visible = showing
	# Freeze the crawler so WASD does not walk behind the overlay, and release
	# the mouse so the buttons are clickable.
	get_tree().paused = showing
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if showing else Input.MOUSE_MODE_CAPTURED


func _reset() -> void:
	_party = GameState.party if GameState and GameState.party else Party.new()
	var run_seed: int = GameState.current_seed if GameState else 1
	_deck = _party.build_combat_deck(run_seed)
	_refresh()


# ---------------------------------------------------------------- construction

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 14)
	col.offset_left = 40
	col.offset_right = -40
	col.offset_top = 28
	col.offset_bottom = -28
	_root.add_child(col)

	var title := Label.new()
	title.text = "КНИГА КОЛОДЫ  ·  C — закрыть"
	UiTheme.as_title(title, 20, Color(1.0, 0.86, 0.6))
	col.add_child(title)

	_party_row = HBoxContainer.new()
	_party_row.add_theme_constant_override("separation", 18)
	col.add_child(_party_row)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	_pile_label = Label.new()
	_pile_label.add_theme_font_size_override("font_size", 16)
	_pile_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.9))
	col.add_child(_pile_label)

	# Scrolls, because a late-run deck will not fit a screen
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_deck_box = VBoxContainer.new()
	_deck_box.add_theme_constant_override("separation", 12)
	_deck_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_deck_box)


# ------------------------------------------------------------------- rendering

func _refresh() -> void:
	_render_party()
	_render_deck()
	var total := 0
	for m in _party.members:
		total += (m["deck"] as Array).size()
	_pile_label.text = "всего карт в колоде: %d" % total


func _render_party() -> void:
	for c in _party_row.get_children():
		c.queue_free()
	for m in _party.members:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(150, 0)
		_party_row.add_child(box)

		var portrait := TextureRect.new()
		portrait.texture = CardView.load_art(m["portrait"])
		portrait.custom_minimum_size = Vector2(150, 150)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(portrait)

		var name_label := Label.new()
		name_label.text = "%s — %s" % [m["name"], m["role"]]
		UiTheme.as_title(name_label, 13, m["colour"])
		box.add_child(name_label)

		var hp := ProgressBar.new()
		hp.max_value = m["max_hp"]
		hp.value = m["hp"]
		hp.show_percentage = false
		hp.custom_minimum_size = Vector2(150, 14)
		box.add_child(hp)

		var hp_label := Label.new()
		hp_label.text = "%d / %d HP   ·   карт: %d" % [m["hp"], m["max_hp"], (m["deck"] as Array).size()]
		hp_label.add_theme_font_size_override("font_size", 12)
		box.add_child(hp_label)


## One row of cards per hero, duplicates stacked with a count badge.
func _render_deck() -> void:
	for c in _deck_box.get_children():
		c.queue_free()

	for m in _party.members:
		var header := Label.new()
		var cards: Array = m["deck"]
		header.text = "%s  ·  %d карт" % [m["name"], cards.size()]
		UiTheme.as_title(header, 16, m["colour"])
		_deck_box.add_child(header)

		# Stack duplicates: "Сеча ×3" instead of three identical faces.
		# A deck entry is either an id or {card, plus} once it has been upgraded,
		# so an upgraded copy counts as its own entry — that IS a different card.
		var counts := {}
		var order: Array = []
		var samples := {}
		for entry in cards:
			var key := str(entry)
			if not counts.has(key):
				counts[key] = 0
				samples[key] = entry
				order.append(key)
			counts[key] += 1

		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_deck_box.add_child(grid)
		for key in order:
			grid.add_child(_make_card_entry(samples[key], int(counts[key]), m["colour"]))


func _make_card_entry(entry, count: int, colour: Color) -> Control:
	var def := CardDB.resolve_entry(entry)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(CARD_W, CARD_H)
	if def.is_empty():
		return holder
	holder.add_child(CardView.build(def, colour, Vector2(CARD_W, CARD_H)))
	if count > 1:
		var badge := Label.new()
		badge.text = "×%d" % count
		UiTheme.as_title(badge, 19, Color(1.0, 0.94, 0.8))
		badge.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.06))
		badge.add_theme_constant_override("outline_size", 6)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -46
		badge.offset_top = -30
		badge.offset_right = -6
		badge.offset_bottom = -4
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(badge)
	return holder
