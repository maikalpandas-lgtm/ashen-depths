extends CanvasLayer
## Shown while a floor is being built.
##
## Generation is SYNCHRONOUS — one long frame that carves the maze, builds the
## meshes, spawns torches, props, forage and packs. Without this the game simply
## froze for that frame straight after the hero was picked, which reads as a
## crash rather than as work being done.
##
## The trick is that the overlay must be VISIBLE for one drawn frame before the
## work starts, so the caller shows it, awaits a frame, and only then generates.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const LINES := [
	"Куём кирки…",
	"Считаем кости в отвалах…",
	"Ставим факелы по правой стене…",
	"Расселяем нежить…",
	"Прячем схроны…",
]

var _root: Control = null
var _title: Label = null
var _line: Label = null
var _bar: Control = null
var _age := 0.0


func _ready() -> void:
	# Above everything except the fight banner; must draw while paused.
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	set_process(false)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_root.add_child(col)

	_title = Label.new()
	UiTheme.as_display(_title, 40, Color(1.0, 0.87, 0.6))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_line = Label.new()
	UiTheme.as_title(_line, 16, Color(0.72, 0.69, 0.65))
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_line)

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.draw.connect(_draw_bar)
	col.add_child(_bar)


func _draw_bar() -> void:
	var w := _bar.size.x
	if w < 20.0:
		return
	# Indeterminate sweep: the work is one blocking frame, so a real percentage
	# would be a lie — this only says "the game is alive".
	var span := 200.0
	var t: float = fmod(_age * 0.9, 1.0)
	var x: float = lerpf(-span, w, t)
	_bar.draw_rect(Rect2(w * 0.5 - 300.0, 3.0, 600.0, 4.0),
		Color(0.16, 0.14, 0.16, 1.0), true)
	_bar.draw_rect(Rect2(maxf(w * 0.5 - 300.0, x), 3.0,
		minf(span, w * 0.5 + 300.0 - x), 4.0), Color(0.85, 0.66, 0.28, 1.0), true)


func show_for(title: String) -> void:
	_title.text = title
	_line.text = str(LINES[randi() % LINES.size()])
	_age = 0.0
	_root.visible = true
	set_process(true)


func hide_now() -> void:
	_root.visible = false
	set_process(false)


func _process(delta: float) -> void:
	_age += delta
	if _bar:
		_bar.queue_redraw()
