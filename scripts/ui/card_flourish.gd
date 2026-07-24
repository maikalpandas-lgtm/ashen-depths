extends CanvasLayer
## The card you just gained, shown big in the middle for a beat.
##
## Фаза F of docs/COMPETITOR_PLAN.md. The reference does this on every card
## acquisition and it is the difference between "a line of log text scrolled by"
## and "I got something". Our draft closed instantly and the new card was never
## actually LOOKED at — it went straight into a 27-card pile.
##
## Autoload-free: main.tscn owns one of these and everything that grants a card
## calls `show_card`. Anything that wants it can also just instantiate one.

const CardView = preload("res://scripts/ui/card_view.gd")
const CardDB = preload("res://scripts/cards/card_db.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Flourish = preload("res://scripts/ui/flourish_anim.gd")

const CARD_SIZE := Vector2(268, 375)

var _root: Control = null
var _holder: Control = null
var _caption: Label = null
var _age := 0.0
var _running := false


func _ready() -> void:
	layer = 20
	# Runs while paused: every screen that grants a card pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	set_process(false)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Never eats a click: the overlay underneath is still being used, and a
	# celebratory animation that swallows the next press is worse than none.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.custom_minimum_size = CARD_SIZE
	_holder.size = CARD_SIZE
	# Pivot at the centre so the scale-up grows from the middle, not the corner
	_holder.pivot_offset = CARD_SIZE * 0.5
	_root.add_child(_holder)

	_caption = Label.new()
	UiTheme.as_display(_caption, 26, Color(1.0, 0.88, 0.6))
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_caption)


## `entry` is a card id or a {card, plus} deck entry.
func show_card(entry, caption: String = "", colour: Color = Color(0.9, 0.85, 0.7)) -> void:
	var def: Dictionary = CardDB.resolve_entry(entry)
	if def.is_empty():
		return
	for c in _holder.get_children():
		_holder.remove_child(c)
		c.queue_free()
	var card := CardView.build(def, colour, CARD_SIZE)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.add_child(card)

	_caption.text = caption if caption != "" else str(def.get("name", ""))
	_age = 0.0
	_running = true
	_root.visible = true
	set_process(true)
	_apply(0.0)


func _process(delta: float) -> void:
	if not _running:
		return
	_age += delta
	if _age >= Flourish.TOTAL:
		_running = false
		_root.visible = false
		set_process(false)
		return
	_apply(_age)


func _apply(t: float) -> void:
	var view := get_viewport().get_visible_rect().size
	var f: Dictionary = Flourish.frame(t, view, CARD_SIZE)
	_holder.scale = Vector2.ONE * float(f["scale"])
	_holder.position = f["pos"]
	_holder.modulate = Color(1, 1, 1, float(f["alpha"]))
	_caption.position = Vector2(0.0, float(f["caption_y"]))
	_caption.size = Vector2(view.x, 34.0)
	_caption.modulate = Color(1, 1, 1, float(f["alpha"]))
