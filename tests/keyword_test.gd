extends SceneTree
## Keyword colouring must not nest or corrupt a card's rules text.
const CardView = preload("res://scripts/ui/card_view.gd")
const CardDB = preload("res://scripts/cards/card_db.gd")


func _init() -> void:
	var failed := 0
	for id in CardDB.ids():
		var raw: String = str(CardDB.get_card(id)["text"])
		var out := CardView.colourise(raw)
		var opens := out.count("[color=")
		var closes := out.count("[/color]")
		if opens != closes:
			printerr("  FAIL %s: %d open vs %d close tags" % [id, opens, closes])
			failed += 1
		# Stripping the tags must give the original text back
		var stripped := out
		while stripped.find("[color=") >= 0:
			var a := stripped.find("[color=")
			var b := stripped.find("]", a)
			stripped = stripped.substr(0, a) + stripped.substr(b + 1)
		stripped = stripped.replace("[/color]", "")
		if stripped != raw:
			printerr("  FAIL %s: text changed\n    was: %s\n    now: %s" % [id, raw, stripped])
			failed += 1
	if failed == 0:
		print("  ok   keyword colouring is lossless (%d cards)" % CardDB.ids().size())
	quit(1 if failed > 0 else 0)
