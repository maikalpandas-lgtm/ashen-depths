extends SceneTree
## Headless logic tests. NOT the game — no window, no rendering.
##
##   godot --headless --script tests/run_tests.gd
##
## Card/deck maths is the one part of this project that can be verified without
## looking at a frame, so it gets checked here instead of by eye.

const CardDB = preload("res://scripts/cards/card_db.gd")
const Deck = preload("res://scripts/cards/deck.gd")
const Party = preload("res://scripts/party.gd")
const Combat = preload("res://scripts/combat/combat_state.gd")

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_card_db()
	_test_deck_conservation()
	_test_draw_recycles_discard()
	_test_hand_cap()
	_test_seed_is_deterministic()
	_test_party()
	_test_combat_deck()
	_test_combat_basics()
	_test_combat_damage()
	_test_combat_end()

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % what)
	else:
		_failed += 1
		printerr("  FAIL %s" % what)


func _test_card_db() -> void:
	print("card db")
	check(CardDB.ids().size() == 10, "10 MVP cards defined")
	check(CardDB.has_card("slice"), "slice exists")
	check(not CardDB.has_card("nope"), "unknown id reports missing")
	var a := CardDB.get_card("slice")
	a["damage"] = 999
	check(CardDB.get_card("slice")["damage"] == 6, "get_card returns a copy, not the shared def")
	var blood := CardDB.get_card("blood_lash")
	check(blood["blood"] == 4 and blood["energy"] == 0, "blood card costs HP, not energy")


func _test_deck_conservation() -> void:
	print("deck keeps every card")
	var deck: Deck = Deck.new(_entries(20), 1)
	deck.shuffle()
	check(deck.total() == 20, "20 in, 20 present")
	deck.draw(5)
	check(deck.total() == 20 and deck.hand.size() == 5, "drawing moves, never loses")
	deck.discard_at(0)
	check(deck.total() == 20 and deck.hand.size() == 4, "discarding one moves, never loses")
	deck.discard_hand()
	check(deck.total() == 20 and deck.hand.is_empty(), "discarding the hand moves, never loses")
	check(not deck.discard_at(99), "bad index is rejected")


func _test_draw_recycles_discard() -> void:
	print("draw recycles the discard")
	var deck: Deck = Deck.new(_entries(6), 7)
	deck.draw(6)
	deck.discard_hand()
	check(deck.draw_pile.is_empty() and deck.discard_pile.size() == 6, "draw pile emptied")
	var got := deck.draw(4)
	check(got == 4, "refills from the discard instead of returning nothing")
	check(deck.total() == 6, "still 6 cards after recycling")

	# Everything already in hand: nothing left anywhere to draw
	var small: Deck = Deck.new(_entries(3), 3)
	check(small.draw(5) == 3, "cannot draw more than exists")


func _test_hand_cap() -> void:
	print("hand cap")
	var deck: Deck = Deck.new(_entries(30), 5)
	var got := deck.draw(30)
	check(got == Deck.HAND_CAP, "draw stops at the cap (%d)" % Deck.HAND_CAP)
	check(deck.hand.size() == Deck.HAND_CAP, "hand holds exactly the cap")
	check(deck.total() == 30, "capped draw did not burn the rest")


func _test_seed_is_deterministic() -> void:
	print("seeded shuffle")
	var a: Deck = Deck.new(_entries(20), 42)
	var b: Deck = Deck.new(_entries(20), 42)
	var c: Deck = Deck.new(_entries(20), 43)
	a.shuffle()
	b.shuffle()
	c.shuffle()
	check(str(a.draw_pile) == str(b.draw_pile), "same seed gives the same order")
	check(str(a.draw_pile) != str(c.draw_pile), "different seed gives a different order")


func _test_party() -> void:
	print("party")
	var p: Party = Party.new()
	check(p.members.size() == 3, "MVP party has 3 heroes")
	check(p.total_max_hp() == 88, "party HP sums to the 88 the HUD shows")
	for m in p.members:
		var n: int = (m["deck"] as Array).size()
		check(n >= 8 and n <= 10, "%s starter deck is 8-10 cards (%d)" % [m["id"], n])
	p.members[0]["hp"] = 0
	check(p.alive_members().size() == 2, "a downed hero drops out of alive_members")


func _test_combat_deck() -> void:
	print("combat deck")
	var p: Party = Party.new()
	var deck: Deck = p.build_combat_deck(11)
	var expected := 0
	for m in p.members:
		expected += (m["deck"] as Array).size()
	check(deck.total() == expected, "all three decks merged (%d cards)" % expected)

	var owners := {}
	for e in deck.draw_pile:
		owners[e["owner"]] = true
		check_silent(CardDB.has_card(e["card"]), "every entry is a real card")
	check(owners.size() == 3, "every card carries an owner tag, all 3 present")


func _combat(pack: Array = ["grub"]) -> Combat:
	return Combat.new(Party.new(), pack, 5)


func _test_combat_basics() -> void:
	print("combat setup")
	var c := _combat(["grub", "brute"])
	check(c.energy == Combat.START_ENERGY, "turn starts on 3 energy")
	check(c.deck.hand.size() == Combat.DRAW_PER_TURN, "opening hand is 5")
	check(c.enemies.size() == 2, "pack has 2 enemies")
	check(c.enemies[1]["hp"] == 26, "brute HP comes from the enemy table")
	check(c.phase == Combat.Phase.PLAYER, "player acts first")
	for e in c.enemies:
		check_silent(not (e["intent"] as Dictionary).is_empty(), "every enemy telegraphs an intent")


func _test_combat_damage() -> void:
	print("combat resolution")
	var c := _combat(["grub"])
	# Force a known hand so the test does not depend on the shuffle
	c.deck.hand = [{"card": "slice", "owner": "kael"}, {"card": "block", "owner": "kael"}]
	var hp_before: int = c.enemies[0]["hp"]
	check(c.play_card(0, 0), "slice resolves")
	check(c.enemies[0]["hp"] == hp_before - 6, "slice deals its 6")
	check(c.energy == Combat.START_ENERGY - 1, "energy was spent")
	check(c.deck.discard_pile.size() == 1, "played card went to the discard")

	check(c.play_card(0, 0), "block resolves")
	check(c.party_block == 5, "block guards the party")

	# Cannot pay what you do not have
	var poor := _combat(["grub"])
	poor.deck.hand = [{"card": "hack", "owner": "kael"}]
	poor.energy = 1
	check(not poor.can_play(0), "a 2-cost card is unplayable on 1 energy")

	# Blood must never be able to wipe the party
	var bleed := _combat(["grub"])
	bleed.deck.hand = [{"card": "blood_lash", "owner": "sera"}]
	for m in bleed.party.members:
		m["hp"] = 1
	check(not bleed.can_play(0), "a blood card cannot kill the party to pay for itself")


func _test_combat_end() -> void:
	print("combat ends")
	var c := _combat(["grub"])
	c.enemies[0]["hp"] = 3
	c.deck.hand = [{"card": "slice", "owner": "kael"}]
	c.play_card(0, 0)
	check(c.phase == Combat.Phase.WON, "killing the last enemy wins")
	check(c.alive_enemies().is_empty(), "no enemies left standing")

	# events must describe what happened, the UI animates off them
	var ev := _combat(["grub"])
	ev.deck.hand = [{"card": "slice", "owner": "kael"}]
	ev.enemies[0]["hp"] = 3
	ev.play_card(0, 0)
	var kinds: Array = ev.events.map(func(e): return e["kind"])
	check(kinds.has("enemy_hit"), "a hit is reported as an event")
	check(kinds.has("enemy_died"), "a kill is reported as an event")

	var atk := _combat(["grub"])
	atk.enemies[0]["intent"] = {"type": "attack", "value": 2}
	atk.end_turn()
	check(atk.events.any(func(e): return e["kind"] == "enemy_attack"),
		"an enemy swing is reported as an event")

	var lose := _combat(["brute"])
	for m in lose.party.members:
		m["hp"] = 1
	lose.enemies[0]["intent"] = {"type": "attack", "value": 99}
	lose.end_turn()
	check(lose.phase == Combat.Phase.LOST, "party wiped ends the fight")

	var survive := _combat(["grub"])
	var turn_before: int = survive.turn
	survive.enemies[0]["intent"] = {"type": "attack", "value": 1}
	survive.end_turn()
	check(survive.turn == turn_before + 1, "surviving the enemy turn starts the next one")
	check(survive.energy == Combat.START_ENERGY, "energy refills each turn")


## Assert without spamming a line per card
func check_silent(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL %s" % what)


func _entries(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({"card": "slice", "owner": "kael", "n": i})
	return out
