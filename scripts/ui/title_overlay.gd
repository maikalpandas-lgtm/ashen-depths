extends CanvasLayer
## Boot splash — demo entry. Space / click starts the run with explore music.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _root: Control = null
var _started: bool = false


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Soft title sting once the tree is ready
	call_deferred("_intro_audio")


func _intro_audio() -> void:
	if Music:
		Music.play_jingle("title", -6.0)


func _unhandled_input(event: InputEvent) -> void:
	if _started or not _root.visible:
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_SPACE or k == KEY_ENTER or k == KEY_ESCAPE:
			go = true
	if event is InputEventMouseButton and event.pressed:
		go = true
	if go:
		_start()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root != null and _root.visible


func _start() -> void:
	if _started:
		return
	_started = true
	_root.visible = false
	if Sfx:
		Sfx.play("ui_click")
	# Hero select owns the hand-off: a run cannot begin before a hero exists,
	# so it starts the run itself and unpauses when a card is clicked.
	var picker := get_tree().current_scene.get_node_or_null("HeroSelectOverlay")
	if picker and picker.has_method("open"):
		picker.open()
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Music:
		Music.play_explore(true)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.07, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 14)
	col.offset_left = 60
	col.offset_right = -60
	col.offset_top = 100
	col.offset_bottom = -80
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(col)

	var title := Label.new()
	title.text = "НАВЬИ КОПИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	if UiTheme.display_font():
		title.add_theme_font_override("font", UiTheme.display_font())
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Ashen Depths  ·  demo"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85))
	col.add_child(sub)

	var blurb := Label.new()
	blurb.text = "Спускайся в Лабиринты Корня.\nБей стаи картами · собирай колоду и рюкзак · ищи стража у костра."
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 15)
	blurb.add_theme_color_override("font_color", Color(0.8, 0.84, 0.88))
	col.add_child(blurb)

	var controls := Label.new()
	controls.text = "W/S шаг · A/D поворот · drag карты в бою · B рюкзак · Esc пауза"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 13)
	controls.add_theme_color_override("font_color", Color(0.6, 0.68, 0.72))
	col.add_child(controls)

	var go := Button.new()
	go.text = "Начать  ·  Space"
	go.custom_minimum_size = Vector2(260, 48)
	go.pressed.connect(_start)
	var center := CenterContainer.new()
	center.add_child(go)
	col.add_child(center)
