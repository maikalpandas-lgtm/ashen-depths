extends CanvasLayer
## Deck book — `C` toggles it. Фаза D of docs/COMPETITOR_PLAN.md.
##
## Two jobs, and the second one is new:
##   1. answer "what is in my deck", which is the question a player actually has
##   2. let them UPGRADE a chosen card for gold
##
## (2) matters because the shop's upgrade is RANDOM: pay 40 and it improves
## whatever roll_upgrade_offers hands back. The reference lets you pick, and
## picking is the whole decision — a +2 on the card you actually draw is worth
## far more than a +2 somewhere in the pile.
##
## Duplicates are stacked with a ×N badge, but a stack remembers its real deck
## indices, because upgrading needs one — and an upgraded copy stops being part
## of the stack, which is correct: it IS a different card now.

const CardDB = preload("res://scripts/cards/card_db.gd")
const Party = preload("res://scripts/party.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const DeckLayout = preload("res://scripts/ui/deck_layout.gd")

## Same price as the shop, so the choice between them is convenience versus
## having to walk to a camp, not cost.
const UPGRADE_COST := 40

var _party: RefCounted = null
var _root: Control = null
var _grid: HFlowContainer = null
var _title: Label = null
var _hint: Label = null
var _filter_row: HBoxContainer = null
var _filter_buttons: Array = []
var _filter: int = -1  ## -1 = all, otherwise CardDB.Type
var _card_size := Vector2(132, 185)


func _ready() -> void:
	layer = 5
	# Must keep running while the game is paused, or the key that closes it
	# would never arrive.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# C, not TAB: TAB is ui_focus_next, and the GUI eats it before this runs
		# once a button has focus.
		if (event as InputEventKey).keycode == KEY_C:
			_toggle()
			get_viewport().set_input_as_handled()
		elif (event as InputEventKey).keycode == KEY_ESCAPE and _root.visible:
			_toggle()
			get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root != null and _root.visible


func _toggle() -> void:
	var showing := not _root.visible
	_root.visible = showing
	# Freeze the crawler so WASD does not walk behind the overlay, and release
	# the mouse so the buttons are clickable.
	get_tree().paused = showing
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if showing else Input.MOUSE_MODE_CAPTURED
	if showing:
		_refresh()


# ---------------------------------------------------------------- construction

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.93)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	col.offset_left = 30
	col.offset_right = -30
	col.offset_top = 20
	col.offset_bottom = -20
	_root.add_child(col)

	_title = Label.new()
	UiTheme.as_display(_title, 30, Color(1.0, 0.87, 0.6))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_hint = Label.new()
	UiTheme.as_title(_hint, 15, Color(0.76, 0.74, 0.70))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)

	_filter_row = HBoxContainer.new()
	_filter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_filter_row.add_theme_constant_override("separation", 8)
	col.add_child(_filter_row)
	_build_filters()

	# Scrolls, because a late-run deck will not fit a screen
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", int(DeckLayout.GAP))
	_grid.add_theme_constant_override("v_separation", int(DeckLayout.GAP))
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)


## Built ONCE and only restyled on click — rebuilding a button row inside that
## row's own `pressed` handler frees the node mid-signal (see AGENTS.md).
func _build_filters() -> void:
	_filter_buttons.clear()
	for entry in DeckLayout.FILTERS:
		var btn := Button.new()
		btn.text = str(entry["label"])
		btn.focus_mode = Control.FOCUS_NONE
		var t: int = int(entry["type"])
		btn.set_meta("type", t)
		btn.pressed.connect(func(): _set_filter(t))
		_filter_row.add_child(btn)
		_filter_buttons.append(btn)
	_paint_filters()


func _paint_filters() -> void:
	for btn in _filter_buttons:
		if not is_instance_valid(btn):
			continue
		var on: bool = int(btn.get_meta("type", -1)) == _filter
		UiTheme.cartoon_button(btn as Button, 14,
			Color(0.30, 0.52, 0.40) if on else Color(0.17, 0.15, 0.19))


func _set_filter(t: int) -> void:
	if _filter == t:
		return
	_filter = t
	if Sfx:
		Sfx.play("ui_click")
	_paint_filters()
	_render()


# ------------------------------------------------------------------- rendering

func _refresh() -> void:
	_party = GameState.party if GameState and GameState.party else Party.of(Party.DEFAULT_HERO)
	_card_size = DeckLayout.card_size(get_viewport().get_visible_rect().size)
	_paint_filters()
	_render()


func _render() -> void:
	var hero: Dictionary = _party.hero() if _party.has_method("hero") else {}
	var cards: Array = hero.get("deck", [])
	var gold: int = GameState.gold if GameState else 0

	_title.text = "КОЛОДА  ·  %d карт" % cards.size()
	_hint.text = "Клик по карте — улучшить за %d🪙   ·   золота: %d   ·   C или Esc — закрыть" % [
		UPGRADE_COST, gold]

	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()

	# Group duplicates but keep the real deck indices — upgrading needs one.
	var groups: Array = DeckLayout.group(cards, _filter)
	if groups.is_empty():
		var empty := Label.new()
		empty.text = "нет карт этого вида"
		UiTheme.as_title(empty, 16, Color(0.6, 0.58, 0.55))
		_grid.add_child(empty)
		return
	for g in groups:
		_grid.add_child(_make_entry(g, str(hero.get("id", "")), gold))


func _make_entry(group: Dictionary, owner_id: String, gold: int) -> Control:
	var def: Dictionary = CardDB.resolve_entry(group["entry"])
	var holder := Control.new()
	holder.custom_minimum_size = _card_size
	if def.is_empty():
		return holder

	var colour: Color = _party.hero().get("colour", Color(0.8, 0.8, 0.8))
	var can_upgrade: bool = DeckLayout.upgradeable(def) and gold >= UPGRADE_COST

	# A Button UNDER the card so the whole tile is clickable. The card itself is
	# MOUSE_FILTER_IGNORE throughout (CardView._ignore_mouse), so it does not
	# swallow the press.
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not can_upgrade
	btn.tooltip_text = _tooltip(def, can_upgrade, gold)
	if can_upgrade:
		btn.pressed.connect(func(): _upgrade(owner_id, int(group["index"])))
	holder.add_child(btn)

	var card := CardView.build(def, colour, _card_size)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(card)

	# Gold ribbon on an upgraded copy, like the reference marks its own
	if int(def.get("plus", 0)) > 0:
		var ribbon := Panel.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.92, 0.72, 0.26, 0.0)
		st.border_color = Color(0.98, 0.80, 0.32)
		st.set_border_width_all(3)
		st.set_corner_radius_all(9)
		ribbon.add_theme_stylebox_override("panel", st)
		ribbon.set_anchors_preset(Control.PRESET_FULL_RECT)
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(ribbon)

	if int(group["count"]) > 1:
		var badge := Label.new()
		badge.text = "×%d" % int(group["count"])
		UiTheme.as_title(badge, 18, Color(1.0, 0.94, 0.8))
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


func _tooltip(def: Dictionary, can_upgrade: bool, gold: int) -> String:
	if DeckLayout.upgradeable(def):
		if gold < UPGRADE_COST:
			return "Нужно %d🪙 (есть %d)" % [UPGRADE_COST, gold]
		return "Улучшить за %d🪙: +%d урона / +%d брони" % [
			UPGRADE_COST, CardDB.UPGRADE_DAMAGE, CardDB.UPGRADE_BLOCK]
	return "Эту карту не улучшить"


func _upgrade(owner_id: String, deck_index: int) -> void:
	if GameState == null or _party == null:
		return
	if GameState.gold < UPGRADE_COST:
		return
	if not _party.upgrade_card(owner_id, deck_index):
		return
	GameState.gold -= UPGRADE_COST
	if Sfx:
		Sfx.play("draft_pick")
	# Deferred: this runs inside a button's own `pressed`, and _render frees
	# that button (AGENTS.md — the bug that made the combat hand vanish).
	call_deferred("_render")
