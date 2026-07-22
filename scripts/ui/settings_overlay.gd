extends CanvasLayer
## Pause / settings — Esc. Volume buses, resume, regenerate, quit.
## Safe to open over combat: closing restores previous pause state.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _root: Control = null
var _master: HSlider = null
var _music: HSlider = null
var _sfx: HSlider = null
var _was_paused: bool = false
var _was_mouse: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			if _root.visible:
				close()
			else:
				# Title screen owns Esc until dismissed
				var title := get_parent().get_node_or_null("TitleOverlay")
				if title and title.has_method("is_open") and title.call("is_open"):
					return
				open()
			get_viewport().set_input_as_handled()


func open() -> void:
	if _root.visible:
		return
	_was_paused = get_tree().paused
	_was_mouse = Input.mouse_mode
	_sync_sliders()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Sfx:
		Sfx.play("ui_click")


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	if Sfx:
		Sfx.save_settings()
		Sfx.play("ui_click")
	# Restore whatever pause/mouse state we interrupted
	get_tree().paused = _was_paused
	Input.mouse_mode = _was_mouse
	# If a reward modal is still up, keep paused + free mouse
	if _blocking_modal_open():
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_open() -> bool:
	return _root != null and _root.visible


func _blocking_modal_open() -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	for name in ["CombatOverlay", "DraftOverlay", "LevelUpOverlay", "LootOverlay",
			"ShopOverlay", "DefeatOverlay", "BackpackOverlay", "TitleOverlay"]:
		var n := parent.get_node_or_null(name)
		if n and n.has_method("is_open") and bool(n.call("is_open")):
			return true
	return false


func _sync_sliders() -> void:
	if Sfx == null:
		return
	_master.set_value_no_signal(Sfx.master_vol)
	_music.set_value_no_signal(Sfx.music_vol)
	_sfx.set_value_no_signal(Sfx.sfx_vol)


func _on_master(v: float) -> void:
	if Sfx:
		Sfx.set_master_volume(v)


func _on_music(v: float) -> void:
	if Sfx:
		Sfx.set_music_volume(v)


func _on_sfx_vol(v: float) -> void:
	if Sfx:
		Sfx.set_sfx_volume(v)


func _resume() -> void:
	close()


func _regen() -> void:
	var main := get_tree().current_scene
	close()
	if main and main.get("dungeon") and main.dungeon.has_method("generate"):
		if main.get("minimap") and main.minimap.has_method("clear_fog"):
			main.minimap.clear_fog()
		main.dungeon.generate()
		if main.has_method("_update_hud"):
			main.call("_update_hud")


func _quit() -> void:
	get_tree().quit()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 0)
	panel.offset_left = -180
	panel.offset_top = -200
	panel.offset_right = 180
	panel.offset_bottom = 200
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	if UiTheme.display_font():
		title.add_theme_font_override("font", UiTheme.display_font())
	col.add_child(title)

	_master = _add_slider(col, "Общая", 1.0, _on_master)
	_music = _add_slider(col, "Музыка", 0.55, _on_music)
	_sfx = _add_slider(col, "Эффекты", 0.85, _on_sfx_vol)

	var resume := Button.new()
	resume.text = "Продолжить (Esc)"
	resume.custom_minimum_size = Vector2(0, 40)
	resume.pressed.connect(_resume)
	col.add_child(resume)

	var regen := Button.new()
	regen.text = "Новый лабиринт"
	regen.custom_minimum_size = Vector2(0, 36)
	regen.pressed.connect(_regen)
	col.add_child(regen)

	var quit_b := Button.new()
	quit_b.text = "Выход"
	quit_b.custom_minimum_size = Vector2(0, 36)
	quit_b.pressed.connect(_quit)
	col.add_child(quit_b)

	var hint := Label.new()
	hint.text = "B — рюкзак · C — колода · F9 — скрин"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	col.add_child(hint)


func _add_slider(parent: Control, label: String, initial: float, cb: Callable) -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.9))
	row.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = initial
	sl.custom_minimum_size = Vector2(300, 24)
	sl.value_changed.connect(cb)
	row.add_child(sl)
	parent.add_child(row)
	return sl
