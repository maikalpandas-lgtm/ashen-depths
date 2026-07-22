extends CanvasLayer
## Floor shop (after EXIT) and map merchant — DESIGN §8.3 B/C.
## Buy from rack, sell from backpack, reroll stock, card remove/upgrade tabs.

const ItemDB = preload("res://scripts/items/item_db.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const REROLL_COST := 15
const REMOVE_COST := 50
const UPGRADE_COST := 40

var _root: Control = null
var _title: Label = null
var _gold_lbl: Label = null
var _stock_row: HBoxContainer = null
var _pack_row: HBoxContainer = null
var _mode: String = "floor"  ## floor | merchant
var _stock: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	if GameState and GameState.has_signal("shop_requested"):
		GameState.shop_requested.connect(_on_shop_requested)


func _on_shop_requested(mode: String) -> void:
	open(mode)


func open(mode: String = "floor") -> void:
	_mode = mode
	_rng.randomize()
	var count := 4 if mode == "merchant" else 6
	var upscale := mode == "merchant"
	_stock = ItemDB.roll_shop_stock(count, _rng, upscale)
	_title.text = "ТОРГОВЕЦ" if mode == "merchant" else "ЛАГЕРЬ  ·  лавка этажа"
	_refresh()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Sfx:
		Sfx.play("draft_open")
		Sfx.play("gold", -8.0)


func _refresh() -> void:
	if GameState:
		_gold_lbl.text = "🪙 %d" % GameState.gold
	_rebuild_stock()
	_rebuild_pack()


func _rebuild_stock() -> void:
	for c in _stock_row.get_children():
		c.queue_free()
	for i in range(_stock.size()):
		var offer: Dictionary = _stock[i]
		var id: String = str(offer.get("id", ""))
		var def: Dictionary = ItemDB.get_item(id)
		var price: int = int(offer.get("price", def.get("buy", 20)))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.custom_minimum_size = Vector2(150, 0)
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(150, 72)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
		lbl.text = "%s\n[%s]\n%s" % [def.get("name", id), def.get("rarity", "?"), def.get("text", "")]
		box.add_child(lbl)
		var buy := Button.new()
		buy.text = "Купить %d🪙" % price
		buy.custom_minimum_size = Vector2(0, 32)
		var idx := i
		buy.pressed.connect(func(): _buy(idx))
		box.add_child(buy)
		_stock_row.add_child(box)


func _rebuild_pack() -> void:
	for c in _pack_row.get_children():
		c.queue_free()
	if GameState == null or GameState.backpack == null:
		return
	for item in GameState.backpack.list_items():
		var def: Dictionary = item.get("def", {})
		var sell: int = int(def.get("sell", 5))
		var btn := Button.new()
		btn.text = "%s\n%d🪙" % [def.get("name", item["id"]), sell]
		btn.custom_minimum_size = Vector2(100, 56)
		btn.add_theme_font_size_override("font_size", 11)
		var uid: String = str(item["uid"])
		btn.pressed.connect(func(): _sell_uid(uid))
		_pack_row.add_child(btn)


func _buy(index: int) -> void:
	if index < 0 or index >= _stock.size():
		return
	if GameState == null or GameState.backpack == null:
		return
	var offer: Dictionary = _stock[index]
	var id: String = str(offer.get("id", ""))
	var price: int = int(offer.get("price", 20))
	if GameState.gold < price:
		if Sfx:
			Sfx.play("miss")
		_title.text = "Не хватает золота"
		return
	if not GameState.backpack.has_space_for(id):
		if Sfx:
			Sfx.play("miss")
		_title.text = "Рюкзак полон"
		return
	var uid: String = GameState.backpack.auto_place(id)
	if uid.is_empty():
		return
	GameState.gold -= price
	_stock.remove_at(index)
	if Sfx:
		Sfx.play("draft_pick")
		Sfx.play("gold", -6.0)
	_refresh()


func _sell_uid(uid: String) -> void:
	if GameState == null or GameState.backpack == null:
		return
	var gold: int = GameState.backpack.sell_value(uid)
	GameState.backpack.remove(uid)
	GameState.gold += gold
	if Sfx:
		Sfx.play("gold")
	_refresh()


func _reroll() -> void:
	if GameState == null:
		return
	if GameState.gold < REROLL_COST:
		if Sfx:
			Sfx.play("miss")
		return
	GameState.gold -= REROLL_COST
	var count := 4 if _mode == "merchant" else 6
	_stock = ItemDB.roll_shop_stock(count, _rng, _mode == "merchant")
	if Sfx:
		Sfx.play("ui_click")
		Sfx.play("gold", -8.0)
	_refresh()


func _card_remove() -> void:
	if GameState == null or GameState.party == null:
		return
	if GameState.gold < REMOVE_COST:
		if Sfx:
			Sfx.play("miss")
		return
	# Remove a random common-ish card from a random hero (MVP simple sink)
	var members: Array = GameState.party.members
	if members.is_empty():
		return
	var m: Dictionary = members[_rng.randi_range(0, members.size() - 1)]
	var deck: Array = m["deck"]
	if deck.size() <= 6:
		_title.text = "Колода слишком тонкая"
		if Sfx:
			Sfx.play("miss")
		return
	var idx := _rng.randi_range(0, deck.size() - 1)
	var removed = deck[idx]
	deck.remove_at(idx)
	m["deck"] = deck
	GameState.gold -= REMOVE_COST
	if Sfx:
		Sfx.play("card_play")
	var cid: String = str(removed["card"]) if removed is Dictionary else str(removed)
	_title.text = "Удалена карта: %s (−%d🪙)" % [cid, REMOVE_COST]
	_refresh()


func _card_upgrade() -> void:
	if GameState == null or GameState.party == null:
		return
	if GameState.gold < UPGRADE_COST:
		if Sfx:
			Sfx.play("miss")
		return
	var offers: Array = GameState.party.roll_upgrade_offers(1, _rng)
	if offers.is_empty():
		if Sfx:
			Sfx.play("miss")
		return
	var o: Dictionary = offers[0]
	if GameState.party.upgrade_card(str(o["owner"]), int(o["deck_index"])):
		GameState.gold -= UPGRADE_COST
		if Sfx:
			Sfx.play("draft_pick")
		_title.text = "Улучшено: %s (−%d🪙)" % [o.get("card", "?"), UPGRADE_COST]
	_refresh()


func _leave() -> void:
	_root.visible = false
	if Sfx:
		Sfx.play("ui_click")
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _mode == "floor":
		# Descend after camp shop
		if GameState:
			GameState.finish_floor_shop()
	elif GameState and GameState.has_signal("shop_finished"):
		GameState.shop_finished.emit("merchant")


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.03, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	col.offset_left = 28
	col.offset_right = -28
	col.offset_top = 24
	col.offset_bottom = -24
	_root.add_child(col)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	if UiTheme.display_font():
		_title.add_theme_font_override("font", UiTheme.display_font())
	head.add_child(_title)

	_gold_lbl = Label.new()
	_gold_lbl.add_theme_font_size_override("font_size", 20)
	_gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	head.add_child(_gold_lbl)

	var stock_lbl := Label.new()
	stock_lbl.text = "— ВИТРИНА —"
	stock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_lbl.add_theme_font_size_override("font_size", 14)
	stock_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7))
	col.add_child(stock_lbl)

	_stock_row = HBoxContainer.new()
	_stock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stock_row.add_theme_constant_override("separation", 12)
	col.add_child(_stock_row)

	var pack_lbl := Label.new()
	pack_lbl.text = "— ТВОЙ РЮКЗАК (клик = продать) —"
	pack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_lbl.add_theme_font_size_override("font_size", 14)
	pack_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7))
	col.add_child(pack_lbl)

	_pack_row = HBoxContainer.new()
	_pack_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pack_row.add_theme_constant_override("separation", 8)
	col.add_child(_pack_row)

	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 12)
	col.add_child(tools)

	var reroll := Button.new()
	reroll.text = "Reroll  %d🪙" % REROLL_COST
	reroll.pressed.connect(_reroll)
	tools.add_child(reroll)

	var rem := Button.new()
	rem.text = "Удалить карту  %d🪙" % REMOVE_COST
	rem.pressed.connect(_card_remove)
	tools.add_child(rem)

	var up := Button.new()
	up.text = "Улучшить карту  %d🪙" % UPGRADE_COST
	up.pressed.connect(_card_upgrade)
	tools.add_child(up)

	var leave := Button.new()
	leave.text = "Уйти"
	leave.custom_minimum_size = Vector2(140, 40)
	leave.pressed.connect(_leave)
	var leave_c := CenterContainer.new()
	leave_c.add_child(leave)
	col.add_child(leave_c)
