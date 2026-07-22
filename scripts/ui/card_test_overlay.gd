extends CanvasLayer
## Debug overlay for the Phase 2 deck model — C toggles it.
##
## Until combat exists (Phase 3) the party and the cards are data nobody draws,
## so none of it could be checked in the running game. This puts the real
## Party/Deck objects on screen: portraits with HP, the actual hand dealt from
## the seeded combat deck, and pile counts, plus buttons to exercise draw /
## discard / reshuffle.
##
## Built in code rather than as a .tscn so the combat UI can replace it wholesale
## without leaving a half-edited scene behind.

const CardDB = preload("res://scripts/cards/card_db.gd")
const Party = preload("res://scripts/party.gd")
const Deck = preload("res://scripts/cards/deck.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

## 5:7, the ratio card_frame.png is authored at
const CARD_W := 150
const CARD_H := 210


var _party: Party = null
var _deck: Deck = null
var _root: Control = null
var _hand_row: HBoxContainer = null
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
	_deck.draw(5)  # §7.5 — draw 5 at the start of combat
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
	title.text = "PARTY & DECK  ·  Phase 2 test view  ·  C to close"
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

	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 10)
	col.add_child(_hand_row)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	_add_button(buttons, "Draw 1", func(): _deck.draw(1); _refresh())
	_add_button(buttons, "Draw 5", func(): _deck.draw(5); _refresh())
	_add_button(buttons, "Discard hand", func(): _deck.discard_hand(); _refresh())
	_add_button(buttons, "New combat", func(): _reset())


func _add_button(parent: Node, text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 34)
	b.pressed.connect(on_press)
	parent.add_child(b)


# ------------------------------------------------------------------- rendering

func _refresh() -> void:
	_render_party()
	_render_hand()
	_pile_label.text = "draw %d   ·   hand %d / %d   ·   discard %d   ·   total %d" % [
		_deck.draw_pile.size(), _deck.hand.size(), Deck.HAND_CAP,
		_deck.discard_pile.size(), _deck.total(),
	]


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
		hp_label.text = "%d / %d HP   ·   %d cards" % [m["hp"], m["max_hp"], (m["deck"] as Array).size()]
		hp_label.add_theme_font_size_override("font_size", 12)
		box.add_child(hp_label)


func _render_hand() -> void:
	for c in _hand_row.get_children():
		c.queue_free()
	for entry in _deck.hand:
		_hand_row.add_child(_make_card(entry))


func _make_card(entry: Dictionary) -> Control:
	var owner_colour: Color = Color(0.7, 0.7, 0.7)
	for m in _party.members:
		if m["id"] == entry["owner"]:
			owner_colour = m["colour"]
	return CardView.build(CardDB.get_card(entry["card"]), owner_colour, Vector2(CARD_W, CARD_H))
