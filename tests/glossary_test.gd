extends SceneTree
## Every coloured word on a card must be explained somewhere.
##
## Colouring a keyword tells the player it MATTERS without telling them what it
## does, which is arguably worse than plain text. This test is the thing that
## stops a new keyword shipping unexplained: add one to CardView.KEYWORDS and
## the suite goes red until the glossary catches up.
const Glossary = preload("res://scripts/cards/glossary.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const CardDB = preload("res://scripts/cards/card_db.gd")
const Statuses = preload("res://scripts/combat/statuses.gd")

var _passed := 0
var _failed := 0


func check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FAIL %s" % label)


func _init() -> void:
	# 1. every coloured keyword is explained
	var unexplained: Array = []
	for pair in CardView.KEYWORDS:
		var word := str(pair[0])
		if not Glossary.has(word):
			unexplained.append(word)
	check(unexplained.is_empty(), "every coloured keyword has an entry%s"
		% ("" if unexplained.is_empty() else ": " + ", ".join(unexplained)))

	# 2. every status name is explained, since they appear in card text
	for id in Statuses.STATUSES.keys():
		var nm := str(Statuses.STATUSES[id]["name"])
		check(Glossary.has(nm), "status %s is explained" % nm)

	# 3. no entry is blank
	var blank: Array = []
	for w in Glossary.ENTRIES.keys():
		if str(Glossary.ENTRIES[w]).strip_edges() == "":
			blank.append(str(w))
	check(blank.is_empty(), "no entry is empty%s"
		% ("" if blank.is_empty() else ": " + ", ".join(blank)))

	# 4. lookup honours longest-first, like colourise does
	var got: Array = Glossary.for_text("5 урона. Пробой брони")
	check(got.has("Пробой брони"), "the long phrase is found")
	check(not got.has("брони"), "and the bare word inside it is not repeated")

	# 5. кость / кости must not print the same line twice
	var bones: Array = Glossary.for_text("Добил — кость, ещё кости")
	var bone_lines := 0
	for w in bones:
		if Glossary.text(str(w)) == Glossary.text("кость"):
			bone_lines += 1
	check(bone_lines <= 1, "synonyms collapse to one line")

	# 6. every real card yields at least one explainable line, or none at all —
	#    never a crash, and never an empty tip for a card full of keywords
	for id in CardDB.ids():
		var card: Dictionary = CardDB.get_card(str(id))
		var rules := str(card.get("text", ""))
		var lines: Array = Glossary.for_text(rules)
		for w in lines:
			if Glossary.text(str(w)) == "":
				check(false, "card %s: '%s' has no text" % [id, w])
				return
	check(true, "all %d cards resolve their keywords" % CardDB.ids().size())

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
