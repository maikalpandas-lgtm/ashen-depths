extends SceneTree
## Regression: a card is decoration and must never swallow a click meant for a
## parent button. Panel defaults to MOUSE_FILTER_STOP, so this broke the draft
## the moment the card body became a Panel.
const CardView = preload("res://scripts/ui/card_view.gd")
const CardDB = preload("res://scripts/cards/card_db.gd")


func _init() -> void:
	var failed := 0
	for id in CardDB.ids():
		var card := CardView.build(CardDB.get_card(id), Color.WHITE, Vector2(138, 193))
		root.add_child(card)
		var blockers: Array[String] = []
		_scan(card, blockers)
		if not blockers.is_empty():
			printerr("  FAIL %s blocks the mouse: %s" % [id, blockers])
			failed += 1
		card.queue_free()
	if failed == 0:
		print("  ok   every card is transparent to the mouse (%d checked)" % CardDB.ids().size())
	quit(1 if failed > 0 else 0)


func _scan(n: Node, out: Array) -> void:
	if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		out.append("%s(%s)" % [n.name, n.get_class()])
	for c in n.get_children():
		_scan(c, out)
