extends SceneTree
## Each hero's starting deck must actually feel like theirs.
##
## All three used to run Сеча ×4 and Заслон ×4, so the opening turns played the
## same whoever you picked — and the pick is the run's first real decision. This
## pins the two properties that make it a decision: every hero owns cards nobody
## else has, and no hero is mostly shared basics.
const Party = preload("res://scripts/party.gd")
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
	var decks := {}
	for hero in Party.PLAYABLE:
		var ids := {}
		for entry in (Party.HEROES[hero] as Dictionary)["deck"]:
			ids[str(entry)] = int(ids.get(str(entry), 0)) + 1
		decks[hero] = ids

	for hero in Party.PLAYABLE:
		var mine: Dictionary = decks[hero]
		# every card must exist
		for id in mine.keys():
			check(CardDB.has_card(str(id)), "%s: %s is a real card" % [hero, id])

		# cards nobody else starts with
		var exclusive: Array = []
		for id in mine.keys():
			var shared := false
			for other in Party.PLAYABLE:
				if other != hero and (decks[other] as Dictionary).has(id):
					shared = true
					break
			if not shared:
				exclusive.append(str(id))
		check(exclusive.size() >= 3,
			"%s owns at least 3 cards nobody else does (%d: %s)"
				% [hero, exclusive.size(), ", ".join(exclusive)])

		# and is not MOSTLY shared filler
		var total := 0
		var shared_count := 0
		for id in mine.keys():
			var n: int = int(mine[id])
			total += n
			if not exclusive.has(str(id)):
				shared_count += n
		check(float(shared_count) / float(total) < 0.6,
			"%s is not mostly shared basics (%d of %d shared)"
				% [hero, shared_count, total])

		# one plain strike and one plain guard to learn from
		check(mine.has("slice"), "%s has a plain strike to read the others against" % hero)
		check(mine.has("block"), "%s has a plain guard" % hero)

		check(total >= 10 and total <= 13, "%s deck size is sane (%d)" % [hero, total])

	# the three decks must differ from each other, not just from a baseline
	for a in Party.PLAYABLE:
		for b in Party.PLAYABLE:
			if a >= b:
				continue
			var same := 0
			for id in (decks[a] as Dictionary).keys():
				if (decks[b] as Dictionary).has(id):
					same += 1
			check(same <= 3, "%s and %s share at most 3 card types (%d)" % [a, b, same])

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
