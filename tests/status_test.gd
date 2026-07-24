extends SceneTree
## Status rules. These are the foundation the rest of the card depth hangs off
## (docs/COMPETITOR_PLAN.md фаза A), so they get the heaviest test in the repo.
##
## The failure mode being guarded against is silence: a status that decays a
## turn early, or ticks after decaying, changes every fight subtly and nothing
## visibly breaks.
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
	_test_bag()
	_test_outgoing()
	_test_incoming()
	_test_tick()
	_test_row()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_bag() -> void:
	print("status bag")
	var bag := {}
	Statuses.apply(bag, "poison", 3)
	check(Statuses.stacks(bag, "poison") == 3, "applying gives stacks")
	Statuses.apply(bag, "poison", 2)
	check(Statuses.stacks(bag, "poison") == 5, "stacks add up")
	Statuses.apply(bag, "poison", -5)
	# Zero-stack keys must be ERASED, not kept: the UI iterates the bag directly,
	# and a 0 entry would draw an icon for a status nobody has.
	check(not bag.has("poison"), "a spent status leaves no dead key behind")
	Statuses.apply(bag, "nonsense", 4)
	check(bag.is_empty(), "an unknown status is refused, not stored")
	Statuses.apply(bag, "weak", 0)
	check(bag.is_empty(), "applying zero does nothing")


func _test_outgoing() -> void:
	print("damage dealt")
	check(Statuses.outgoing({}, 10) == 10, "no status changes nothing")
	check(Statuses.outgoing({"rage": 3}, 10) == 13, "Ярость adds its stacks")
	check(Statuses.outgoing({"weak": 1}, 10) == 7, "Немощь cuts a quarter")
	# Rage is added BEFORE weak multiplies. The other order would let a raging
	# weakened attacker out-damage a healthy one, which reads as a bug.
	check(Statuses.outgoing({"rage": 4, "weak": 1}, 10) == 10,
		"Немощь bites the buff too, not just the base")
	check(Statuses.outgoing({"weak": 1}, 1) == 0, "a tiny weakened hit can reach 0")
	check(Statuses.outgoing({"weak": 9}, 10) == 7, "Немощь does not stack up")


func _test_incoming() -> void:
	print("damage received")
	check(Statuses.incoming({}, 10) == 10, "no status changes nothing")
	check(Statuses.incoming({"frail": 1}, 10) == 15, "Порча adds half again")
	check(Statuses.incoming({"frail": 1}, 5) == 8, "Порча rounds UP, in the victim's disfavour")
	check(Statuses.incoming({"frail": 7}, 10) == 15, "Порча does not stack up")


func _test_tick() -> void:
	print("end of turn")
	var bag := {"poison": 3}
	var dot := Statuses.tick(bag)
	# Reading the DOT before decaying is the whole point: decay-first would rob
	# the first tick and 3 stacks would only ever deal 2.
	check(dot == 3, "3 stacks of Отрава deal 3, not 2")
	check(Statuses.stacks(bag, "poison") == 2, "then it wears down by one")

	var b2 := {"poison": 1}
	check(Statuses.tick(b2) == 1, "the last stack still bites")
	check(b2.is_empty(), "and then it is gone")

	var b3 := {"weak": 2, "frail": 1}
	check(Statuses.tick(b3) == 0, "non-DOT statuses deal nothing")
	check(Statuses.stacks(b3, "weak") == 1, "Немощь wears off")
	check(not b3.has("frail"), "Порча wore off entirely")

	# Ярость has decay 0 — it is meant to build over a fight
	var b4 := {"rage": 2}
	Statuses.tick(b4)
	Statuses.tick(b4)
	check(Statuses.stacks(b4, "rage") == 2, "Ярость holds for the whole fight")

	check(Statuses.tick({}) == 0, "an empty bag ticks harmlessly")


func _test_row() -> void:
	print("ui row")
	var row: Array = Statuses.to_row({"rage": 2, "poison": 5})
	check(row.size() == 2, "every live status gets a slot")
	# Harmful first, so the player's eye lands on the threat, and the ORDER is
	# stable — an icon row that reshuffles as stacks change is unreadable.
	check(bool(row[0]["harm"]), "harmful statuses come first")
	check(not bool(row[1]["harm"]), "boons come after")
	check(int(row[0]["stacks"]) == 5, "the row carries its stack count")
	check(Statuses.to_row({}).is_empty(), "an empty bag draws nothing")
	# Every status must survive the trip to the UI
	for id in Statuses.STATUSES.keys():
		var one: Array = Statuses.to_row({id: 1})
		check(one.size() == 1 and str(one[0]["icon"]) != "",
			"%s has an icon the HUD can draw" % id)
