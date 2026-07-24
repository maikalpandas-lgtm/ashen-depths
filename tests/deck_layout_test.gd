extends SceneTree
## Deck book grouping and sizing. Фаза D of docs/COMPETITOR_PLAN.md.
##
## The dangerous one here is GROUPING. An upgraded copy must not hide inside the
## stack of plain ones — if it does, clicking the stack upgrades the wrong index
## and the player pays 40 gold to improve a card they were not looking at.
const DeckLayout = preload("res://scripts/ui/deck_layout.gd")
const CardDB = preload("res://scripts/cards/card_db.gd")

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
	_test_group()
	_test_filter()
	_test_upgradeable()
	_test_size()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_group() -> void:
	print("grouping")
	var cards := [
		{"card": "slice", "plus": 0},
		{"card": "slice", "plus": 0},
		{"card": "slice", "plus": 0},
		{"card": "block", "plus": 0},
	]
	var g: Array = DeckLayout.group(cards)
	check(g.size() == 2, "three identical cards collapse into one tile")
	check(int(g[0]["count"]) == 3, "the stack carries its count")
	check(int(g[0]["index"]) == 0, "and a real deck index to act on")

	# An upgraded copy is a DIFFERENT card and must get its own tile.
	var mixed := [
		{"card": "slice", "plus": 0},
		{"card": "slice", "plus": 1},
		{"card": "slice", "plus": 0},
	]
	var g2: Array = DeckLayout.group(mixed)
	check(g2.size() == 2, "an upgraded copy does not hide inside the plain stack")
	var plus_group := {}
	for entry in g2:
		if int((entry["entry"] as Dictionary).get("plus", 0)) == 1:
			plus_group = entry
	check(not plus_group.is_empty(), "the upgraded tile exists")
	check(int(plus_group["index"]) == 1,
		"and points at the upgraded copy, not at a plain one")

	# Bare-string entries (a deck that predates {card, plus}) must still group
	var legacy: Array = DeckLayout.group(["slice", "slice"])
	check(legacy.size() == 1 and int(legacy[0]["count"]) == 2,
		"plain string entries still group")

	check(DeckLayout.group([]).is_empty(), "an empty deck groups to nothing")
	check(DeckLayout.group(["no_such_card"]).is_empty(),
		"an unknown id is dropped, not shown as a blank tile")


func _test_filter() -> void:
	print("filters")
	var cards := [
		{"card": "slice", "plus": 0},     # STRIKE
		{"card": "block", "plus": 0},     # GUARD
		{"card": "firebolt", "plus": 0},  # SPELL
	]
	check(DeckLayout.group(cards, -1).size() == 3, "no filter shows everything")
	var only_strikes: Array = DeckLayout.group(cards, CardDB.Type.STRIKE)
	check(only_strikes.size() == 1, "a type filter narrows the grid")
	var def: Dictionary = CardDB.resolve_entry(only_strikes[0]["entry"])
	check(int(def["type"]) == CardDB.Type.STRIKE, "and keeps the right type")
	# Indices must stay pointing into the ORIGINAL deck, not the filtered view —
	# otherwise a filtered click upgrades whatever sits at that spot unfiltered.
	var spells: Array = DeckLayout.group(cards, CardDB.Type.SPELL)
	check(int(spells[0]["index"]) == 2,
		"a filtered tile still carries its real deck index")
	# Every filter in the row must be a type the cards can actually have
	for entry in DeckLayout.FILTERS:
		var t: int = int(entry["type"])
		check(t == -1 or CardDB.Type.values().has(t),
			"filter '%s' names a real card type" % entry["label"])


func _test_upgradeable() -> void:
	print("upgradeable")
	# +N only touches damage and block, so a card with neither gains NOTHING —
	# offering that for 40 gold is taking the player's money for no effect.
	check(DeckLayout.upgradeable(CardDB.get_card("slice")), "a strike can improve")
	check(DeckLayout.upgradeable(CardDB.get_card("block")), "a guard can improve")
	check(not DeckLayout.upgradeable(CardDB.get_card("offering")),
		"a 0/0 skill is not offered an upgrade that would do nothing")
	check(not DeckLayout.upgradeable(CardDB.get_card("raven")),
		"a pure draw card is not offered one either")
	check(not DeckLayout.upgradeable({}), "an empty definition is refused")


func _test_size() -> void:
	print("sizing")
	for vp in [Vector2(1280, 600), Vector2(1280, 720), Vector2(1920, 1080)]:
		var card: Vector2 = DeckLayout.card_size(vp)
		var rows_h: float = float(DeckLayout.WANT_ROWS) * card.y \
			+ float(DeckLayout.WANT_ROWS - 1) * DeckLayout.GAP
		var budget: float = vp.y - DeckLayout.CHROME_H
		check(rows_h <= budget + 0.5 or card.y <= DeckLayout.MIN_CARD.y + 0.5,
			"%dx%d: three rows fit, or the card is already at its floor" % [vp.x, vp.y])
		check(card.y >= DeckLayout.MIN_CARD.y - 0.5,
			"%dpx: the card never shrinks past readable" % int(vp.y))
		check(DeckLayout.columns(vp, card) >= 4,
			"%dpx wide: at least four cards across" % int(vp.x))
	# A tall window must not inflate cards past the art's resolution
	var big: Vector2 = DeckLayout.card_size(Vector2(1920, 1440))
	check(big.y <= DeckLayout.MAX_CARD.y + 0.5, "cards stop growing at their cap")
