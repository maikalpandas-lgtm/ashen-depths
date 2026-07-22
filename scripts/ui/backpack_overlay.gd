extends CanvasLayer
## Party backpack editor — B or inventory button. Pause explore, drag-free:
## click an item then click a free cell (or rotate / sell).

const ItemDB = preload("res://scripts/items/item_db.gd")
const Backpack = preload("res://scripts/items/backpack.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const CELL := 52

var _root: Control = null
var _grid: GridContainer = null
var _info: Label = null
var _mods_lbl: Label = null
var _cell_btns: Array = []  ## Button flat cells
var _selected_uid: String = ""


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_B:
			toggle()
			get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root != null and _root.visible


func toggle() -> void:
	if _root.visible:
		close()
	else:
		open()


func open() -> void:
	_selected_uid = ""
	_refresh()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Sfx:
		Sfx.play("ui_click")


func close() -> void:
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Sfx:
		Sfx.play("ui_click")


func _refresh() -> void:
	var bp: Backpack = GameState.backpack if GameState else null
	if bp == null:
		return
	var occ := {}
	for uid in bp.placed.keys():
		var p: Dictionary = bp.placed[uid]
		var sz: Vector2i = bp.size_at(str(p["id"]), int(p["rot"]))
		for dy in range(sz.y):
			for dx in range(sz.x):
				occ[Vector2i(int(p["x"]) + dx, int(p["y"]) + dy)] = uid

	for y in range(Backpack.HEIGHT):
		for x in range(Backpack.WIDTH):
			var i: int = y * Backpack.WIDTH + x
			var btn: Button = _cell_btns[i]
			var cell := Vector2i(x, y)
			if occ.has(cell):
				var uid: String = str(occ[cell])
				var p: Dictionary = bp.placed[uid]
				var def: Dictionary = ItemDB.get_item(str(p["id"]))
				var is_origin: bool = int(p["x"]) == x and int(p["y"]) == y
				btn.text = str(def.get("name", "?")) if is_origin else "·"
				btn.disabled = false
				btn.modulate = Color(1.15, 1.05, 0.75) if uid == _selected_uid else Color(0.85, 0.78, 0.55)
			else:
				btn.text = ""
				btn.disabled = false
				btn.modulate = Color(0.35, 0.4, 0.45) if _selected_uid.is_empty() else Color(0.4, 0.55, 0.45)

	if _selected_uid != "" and bp.placed.has(_selected_uid):
		var p2: Dictionary = bp.placed[_selected_uid]
		var def2: Dictionary = ItemDB.get_item(str(p2["id"]))
		_info.text = "%s  ·  rot %d  ·  клик: клетка / R поворот / Del продать %d🪙" % [
			def2.get("name", p2["id"]), int(p2["rot"]), int(def2.get("sell", 0))]
	else:
		_info.text = "Клик по предмету → выбрать. Клик по пустой клетке → переставить. R — поворот. Del — продать."

	var mods: Dictionary = bp.compute_mods()
	_mods_lbl.text = "Пассивы: удар +%d · закл +%d · старт🛡 %d · ⚡ +%d/+%d · золото +%d%% · кровь −%d" % [
		int(mods.get("strike_dmg", 0)),
		int(mods.get("spell_dmg", 0)),
		int(mods.get("start_block", 0)),
		int(mods.get("energy_first_turn", 0)),
		int(mods.get("energy_each_turn", 0)),
		int(float(mods.get("gold_pct", 0.0)) * 100.0),
		int(mods.get("blood_discount", 0)),
	]


func _on_cell(x: int, y: int) -> void:
	var bp: Backpack = GameState.backpack if GameState else null
	if bp == null:
		return
	var occ_uid := ""
	for uid in bp.placed.keys():
		var p: Dictionary = bp.placed[uid]
		var sz: Vector2i = bp.size_at(str(p["id"]), int(p["rot"]))
		if x >= int(p["x"]) and x < int(p["x"]) + sz.x and y >= int(p["y"]) and y < int(p["y"]) + sz.y:
			occ_uid = uid
			break

	if _selected_uid.is_empty():
		_selected_uid = occ_uid
		_refresh()
		return

	if occ_uid == _selected_uid:
		_selected_uid = ""
		_refresh()
		return

	# Move selected to this cell
	if bp.move(_selected_uid, x, y, -1):
		if Sfx:
			Sfx.play("ui_click")
		_selected_uid = ""
	else:
		if Sfx:
			Sfx.play("miss")
	_refresh()


func _rotate_selected() -> void:
	var bp: Backpack = GameState.backpack if GameState else null
	if bp == null or _selected_uid.is_empty() or not bp.placed.has(_selected_uid):
		return
	var p: Dictionary = bp.placed[_selected_uid]
	var new_rot: int = (int(p["rot"]) + 1) % 2
	if bp.move(_selected_uid, int(p["x"]), int(p["y"]), new_rot):
		if Sfx:
			Sfx.play("ui_click")
	else:
		if Sfx:
			Sfx.play("miss")
	_refresh()


func _sell_selected() -> void:
	var bp: Backpack = GameState.backpack if GameState else null
	if bp == null or _selected_uid.is_empty():
		return
	var gold: int = bp.sell_value(_selected_uid)
	var id: String = bp.remove(_selected_uid)
	_selected_uid = ""
	if GameState and gold > 0:
		GameState.gold += gold
	if Sfx:
		Sfx.play("gold")
	_refresh()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.08, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 12)
	col.offset_left = 80
	col.offset_right = -80
	col.offset_top = 40
	col.offset_bottom = -40
	_root.add_child(col)

	var title := Label.new()
	title.text = "РЮКЗАК  ·  5×4"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	if UiTheme.display_font():
		title.add_theme_font_override("font", UiTheme.display_font())
	col.add_child(title)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 13)
	_info.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	col.add_child(_info)

	var center := CenterContainer.new()
	col.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = Backpack.WIDTH
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	center.add_child(_grid)

	_cell_btns.clear()
	for y in range(Backpack.HEIGHT):
		for x in range(Backpack.WIDTH):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(CELL, CELL)
			btn.clip_text = true
			btn.add_theme_font_size_override("font_size", 10)
			var cx := x
			var cy := y
			btn.pressed.connect(func(): _on_cell(cx, cy))
			_grid.add_child(btn)
			_cell_btns.append(btn)

	_mods_lbl = Label.new()
	_mods_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mods_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mods_lbl.add_theme_font_size_override("font_size", 13)
	_mods_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.75))
	col.add_child(_mods_lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)

	var rot := Button.new()
	rot.text = "Повернуть (R)"
	rot.pressed.connect(_rotate_selected)
	row.add_child(rot)

	var sell := Button.new()
	sell.text = "Продать (Del)"
	sell.pressed.connect(_sell_selected)
	row.add_child(sell)

	var close_b := Button.new()
	close_b.text = "Закрыть (B)"
	close_b.pressed.connect(close)
	row.add_child(close_b)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_R:
			_rotate_selected()
			get_viewport().set_input_as_handled()
		elif k == KEY_DELETE or k == KEY_BACKSPACE:
			_sell_selected()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
