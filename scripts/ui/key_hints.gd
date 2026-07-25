extends Control
## Small key-cap hints: [B] рюкзак · [C] колода · …
##
## The bottom bar used to carry one long string —
## "W/S · A/D · B рюкзак · C колода · костёр → лавка → этаж" — which reads as a
## sentence and gets skipped. A key-cap is a SHAPE, and the eye finds a shape.
##
## Drawn rather than built from Controls so the caps line up on the pixel and
## nothing can reflow them; there is no interaction to hook up either.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const CAP_H := 22.0
const CAP_PAD := 7.0
const GAP := 8.0
const GROUP_GAP := 16.0

## {key, label}. Order is by how often a new player needs it.
var hints: Array = []
## Draw the caps in a row (HUD) or a column (overlay corner).
var vertical := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Redraw whenever the set changes; nothing here animates.
	queue_redraw()


func set_hints(list: Array) -> void:
	hints = list
	queue_redraw()


func _draw() -> void:
	var font := UiTheme.title_font()
	var caps := UiTheme.number_font()
	if font == null or caps == null or hints.is_empty():
		return
	var x := 0.0
	var y := 0.0
	for item in hints:
		var key := str((item as Dictionary).get("key", ""))
		var label := str((item as Dictionary).get("label", ""))
		var kw: float = maxf(CAP_H, caps.get_string_size(key,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + CAP_PAD * 2.0)
		var cap := Rect2(x, y, kw, CAP_H)
		# Dark cap with a lighter top edge — reads as a physical key, and the
		# same trick UiTheme.cartoon_button uses on buttons.
		draw_rect(cap.grow(1.0), Color(0.05, 0.04, 0.05, 0.9), true)
		draw_rect(cap, Color(0.24, 0.21, 0.24, 0.97), true)
		draw_rect(Rect2(cap.position, Vector2(cap.size.x, 2.0)),
			Color(0.42, 0.38, 0.40, 0.9), true)
		draw_string(caps, Vector2(cap.position.x, cap.position.y + 16.0), key,
			HORIZONTAL_ALIGNMENT_CENTER, kw, 13, Color(0.96, 0.93, 0.88))
		var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 13).x
		draw_string(font, Vector2(cap.end.x + 6.0, cap.position.y + 16.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.78, 0.74, 0.70))
		if vertical:
			y += CAP_H + GAP
		else:
			x = cap.end.x + 6.0 + lw + GROUP_GAP
	custom_minimum_size = Vector2(x if not vertical else 160.0,
		y + CAP_H if vertical else CAP_H)
