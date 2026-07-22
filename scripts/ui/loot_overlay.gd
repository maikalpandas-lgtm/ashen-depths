extends CanvasLayer
## Post-combat item loot (DESIGN §8.3 step 2): take into backpack or sell.
## Boss offers with pick:true — choose exactly one (take or sell).

const ItemDB = preload("res://scripts/items/item_db.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _root: Control = null
var _title: Label = null
var _row: HBoxContainer = null
var _offers: Array = []
var _must_pick: bool = false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	if GameState and GameState.has_signal("loot_requested"):
		GameState.loot_requested.connect(_on_loot_requested)


func _on_loot_requested(offers: Array) -> void:
	open(offers)


func open(offers: Array) -> void:
	_offers = offers.duplicate(true)
	if _offers.is_empty():
		_close("Нет добычи")
		return
	_must_pick = false
	for o in _offers:
		if bool(o.get("pick", false)):
			_must_pick = true
			break
	_title.text = "ДОБЫЧА  ·  предмет" if not _must_pick else "ДОБЫЧА  ·  выбери 1 предмет"
	_rebuild()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Sfx:
		Sfx.play("draft_open")


func _rebuild() -> void:
	for c in _row.get_children():
		c.queue_free()
	for i in range(_offers.size()):
		var offer: Dictionary = _offers[i]
		var id: String = str(offer.get("id", ""))
		var def: Dictionary = ItemDB.get_item(id)
		if def.is_empty():
			continue
		var sell: int = int(def.get("sell", 5))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.custom_minimum_size = Vector2(200, 0)

		var info := Label.new()
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(200, 100)
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", Color(0.92, 0.9, 0.82))
		info.text = "%s\n[%s]  %dx%d\n%s" % [
			def.get("name", id),
			def.get("rarity", "?"),
			int(def.get("w", 1)), int(def.get("h", 1)),
			def.get("text", ""),
		]
		box.add_child(info)

		var take := Button.new()
		take.text = "В рюкзак"
		take.custom_minimum_size = Vector2(0, 36)
		var ti := i
		take.pressed.connect(func(): _take(ti))
		box.add_child(take)

		var sell_b := Button.new()
		sell_b.text = "Продать  %d🪙" % sell
		sell_b.custom_minimum_size = Vector2(0, 36)
		var si := i
		sell_b.pressed.connect(func(): _sell(si))
		box.add_child(sell_b)

		_row.add_child(box)


func _take(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return
	var id: String = str(_offers[index].get("id", ""))
	if GameState == null or GameState.backpack == null:
		_close("")
		return
	if not GameState.backpack.has_space_for(id):
		if _title:
			_title.text = "Рюкзак полон — продай или освободи (B)"
		if Sfx:
			Sfx.play("miss")
		return
	var uid: String = GameState.backpack.auto_place(id)
	if uid.is_empty():
		if Sfx:
			Sfx.play("miss")
		return
	if Sfx:
		Sfx.play("draft_pick")
	var name_s: String = str(ItemDB.get_item(id).get("name", id))
	if _must_pick:
		_close("Взято: %s" % name_s)
	else:
		_offers.remove_at(index)
		if _offers.is_empty():
			_close("Взято: %s" % name_s)
		else:
			_rebuild()


func _sell(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return
	var id: String = str(_offers[index].get("id", ""))
	var def: Dictionary = ItemDB.get_item(id)
	var sell: int = int(def.get("sell", 5))
	if GameState:
		GameState.gold += sell
	if Sfx:
		Sfx.play("gold")
	var name_s: String = str(def.get("name", id))
	if _must_pick:
		_close("Продано: %s (+%d)" % [name_s, sell])
	else:
		_offers.remove_at(index)
		if _offers.is_empty():
			_close("Продано: %s (+%d)" % [name_s, sell])
		else:
			_rebuild()


func _skip_all() -> void:
	if _must_pick:
		# Must pick one — sell first offer as default skip
		if not _offers.is_empty():
			_sell(0)
		return
	var total := 0
	for o in _offers:
		var def: Dictionary = ItemDB.get_item(str(o.get("id", "")))
		total += int(def.get("sell", 5))
	if GameState and total > 0:
		GameState.gold += total
	if Sfx and total > 0:
		Sfx.play("gold")
	_close("Всё продано (+%d)" % total if total > 0 else "Пусто")


func _close(hint: String) -> void:
	_root.visible = false
	if GameState:
		GameState.clear_pending_loot()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if GameState and GameState.has_signal("loot_finished"):
		GameState.loot_finished.emit(hint)
	if GameState and GameState.has_signal("draft_finished"):
		GameState.draft_finished.emit(hint if not hint.is_empty() else "Добыча")


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.04, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 16)
	col.offset_left = 40
	col.offset_right = -40
	col.offset_top = 50
	col.offset_bottom = -50
	_root.add_child(col)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75))
	if UiTheme.display_font():
		_title.add_theme_font_override("font", UiTheme.display_font())
	col.add_child(_title)

	var hint := Label.new()
	hint.text = "В рюкзак (авто-место)  ·  или продай за золото"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.8, 0.75))
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
	skip.text = "Продать всё / дальше"
	skip.custom_minimum_size = Vector2(240, 40)
	skip.pressed.connect(_skip_all)
	var center := CenterContainer.new()
	center.add_child(skip)
	col.add_child(center)
