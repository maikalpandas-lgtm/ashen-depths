extends CanvasLayer
## Shown when the party is wiped in combat. Soft options for MVP:
## continue on 1 HP, or start a fresh run.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _root: Control = null
var _body: Label = null


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	if GameState and GameState.has_signal("defeat_shown"):
		# optional external open
		pass


func show_defeat() -> void:
	var floor_i := 1
	var gold := 0
	var cards := 0
	if GameState:
		floor_i = GameState.floor_index
		gold = GameState.gold
		if GameState.party:
			cards = GameState.party.deck_size()
	_body.text = "Этаж %d  ·  🪙 %d  ·  карт в колоде %d\n\nДружина пала. Можно подняться на 1 HP\nили начать забег заново." % [floor_i, gold, cards]
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Sfx:
		Sfx.play("defeat", -1.0)


func _continue_wounded() -> void:
	if GameState and GameState.party:
		for m in GameState.party.members:
			m["hp"] = maxi(1, int(m["hp"]))
	if Sfx:
		Sfx.play("ui_click")
	_close()
	if GameState and GameState.has_signal("defeat_finished"):
		GameState.defeat_finished.emit("continue")


func _restart_run() -> void:
	if GameState:
		GameState.new_run()
	if Sfx:
		Sfx.play("ui_click")
	_close()
	if GameState and GameState.has_signal("defeat_finished"):
		GameState.defeat_finished.emit("restart")


func _close() -> void:
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.03, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 20)
	col.offset_left = 60
	col.offset_right = -60
	col.offset_top = 80
	col.offset_bottom = -80
	_root.add_child(col)

	var title := Label.new()
	title.text = "ПОРАЖЕНИЕ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.32))
	if UiTheme.display_font():
		title.add_theme_font_override("font", UiTheme.display_font())
	col.add_child(title)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 16)
	_body.add_theme_color_override("font_color", Color(0.85, 0.8, 0.78))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_body)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)

	var cont := Button.new()
	cont.text = "Встать (1 HP)"
	cont.custom_minimum_size = Vector2(200, 44)
	cont.pressed.connect(_continue_wounded)
	row.add_child(cont)

	var restart := Button.new()
	restart.text = "Новый забег"
	restart.custom_minimum_size = Vector2(200, 44)
	restart.pressed.connect(_restart_run)
	row.add_child(restart)
