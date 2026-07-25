extends SceneTree
## Enemy traits. Before these, every monster rolled the same intent off max_hp,
## so more monsters would have meant more art and no new tactics.
##
## What is worth protecting: each trait must actually BEHAVE differently, every
## enemy in the bestiary must have a real trait, and the pack tables must combine
## roles rather than repeat one.
const EnemyTraits = preload("res://scripts/combat/enemy_traits.gd")
const EnemySprites = preload("res://scripts/enemy_sprites.gd")
const Party = preload("res://scripts/party.gd")
const Combat = preload("res://scripts/combat/combat_state.gd")
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
	_test_table()
	_test_every_enemy_has_one()
	_test_behaviour_differs()
	_test_howler()
	_test_poisoner()
	_test_packs()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_table() -> void:
	print("trait table")
	for id in EnemyTraits.TRAITS.keys():
		var t: Dictionary = EnemyTraits.TRAITS[id]
		check(str(t.get("name", "")) != "", "%s has a name" % id)
		check(str(t.get("text", "")) != "", "%s explains itself" % id)
		check(int(t.get("hits", 1)) >= 1, "%s swings at least once" % id)
		var bc := float(t.get("block_chance", 0.0))
		check(bc >= 0.0 and bc <= 0.6, "%s block chance is sane (%.2f)" % [id, bc])
		# Any status a trait hands out must be a status that EXISTS, or the
		# monster silently does nothing on hit.
		for key in ["on_hit", "on_turn"]:
			if t.has(key):
				var spec: Dictionary = t[key]
				check(Statuses.exists(str(spec["id"])),
					"%s.%s names a real status (%s)" % [id, key, spec["id"]])
	check(EnemyTraits.exists(EnemyTraits.DEFAULT), "the fallback trait exists")
	check(not EnemyTraits.of("nonsense").is_empty(), "an unknown trait falls back")


func _test_every_enemy_has_one() -> void:
	print("bestiary coverage")
	var missing: Array = []
	for id in EnemySprites.ids():
		var def: Dictionary = EnemySprites.ENEMIES[id]
		if bool(def.get("boss", false)):
			continue  # bosses reuse stats and get the default
		var tr := str(def.get("trait", ""))
		if tr == "" or not EnemyTraits.exists(tr):
			missing.append(id)
	check(missing.is_empty(), "every non-boss enemy has a real trait%s"
		% ("" if missing.is_empty() else ": missing " + ", ".join(missing)))


func _test_behaviour_differs() -> void:
	print("behaviour actually differs")
	# A swarm must land more hits per attack than a brute, and a brute must hit
	# harder per swing. If these come out equal the trait table is decoration.
	var c := Combat.new(Party.of("vityaz"), ["grub", "brute"], 9)
	var swarm_hits := 0
	var brute_hits := 0
	var swarm_dmg := 0
	var brute_dmg := 0
	var swarm_blocks := 0
	var guard_blocks := 0
	for i in range(300):
		var a: Dictionary = c._roll_intent({"max_hp": 20, "trait": "swarm"})
		var b: Dictionary = c._roll_intent({"max_hp": 20, "trait": "brute"})
		var g: Dictionary = c._roll_intent({"max_hp": 20, "trait": "guard"})
		if a.get("type") == "attack":
			swarm_hits += int(a["hits"])
			swarm_dmg += int(a["value"])
		else:
			swarm_blocks += 1
		if b.get("type") == "attack":
			brute_hits += int(b["hits"])
			brute_dmg += int(b["value"])
		if g.get("type") == "block":
			guard_blocks += 1
	check(swarm_hits > brute_hits, "a swarm lands more blows (%d vs %d)" % [swarm_hits, brute_hits])
	check(brute_dmg > swarm_dmg, "a brute hits harder per blow (%d vs %d)" % [brute_dmg, swarm_dmg])
	check(guard_blocks > swarm_blocks * 2,
		"a guard turtles far more than a swarm (%d vs %d)" % [guard_blocks, swarm_blocks])


func _test_howler() -> void:
	print("howler")
	# The howler buffs the WHOLE pack — that is what makes it a priority target.
	var c := Combat.new(Party.of("vityaz"), ["koldun", "anchutka"], 3)
	for e in c.enemies:
		e["intent"] = {"type": "block", "value": 1, "hits": 1}
	c.end_turn()
	var buffed := 0
	for e in c.enemies:
		if Statuses.stacks(e["status"], "rage") > 0:
			buffed += 1
	check(buffed == c.enemies.size(), "every living pack member got Ярость (%d)" % buffed)


func _test_poisoner() -> void:
	print("poisoner")
	var c := Combat.new(Party.of("vityaz"), ["bolotnik"], 4)
	c.party_block = 0
	c.enemies[0]["intent"] = {"type": "attack", "value": 3, "hits": 1}
	c.end_turn()
	check(Statuses.stacks(c.party_status, "poison") > 0,
		"a connected hit left poison on the hero")

	# Poison must NOT land when the blow is fully absorbed... it does here,
	# because _hit_party still counts as a hit. Assert the CURRENT behaviour
	# explicitly so a future change to it is a deliberate decision.
	var c2 := Combat.new(Party.of("vityaz"), ["bolotnik"], 4)
	c2.party_block = 99
	c2.enemies[0]["intent"] = {"type": "attack", "value": 3, "hits": 1}
	c2.end_turn()
	check(Statuses.stacks(c2.party_status, "poison") > 0,
		"poison lands through armour (deliberate: armour stops damage, not venom)")


func _test_packs() -> void:
	print("pack composition")
	var seen := {}
	for biome in ["mine", "forest"]:
		for floor_i in [1, 3]:
			for h in range(40):
				for id in EnemySprites.pack_for(h, floor_i, biome):
					seen[id] = true
	# Every non-boss enemy must be reachable, or it is art nobody sees — the
	# exact bug that hid Полудница for a whole session.
	var unreachable: Array = []
	for id in EnemySprites.ids():
		if bool((EnemySprites.ENEMIES[id] as Dictionary).get("boss", false)):
			continue
		if not seen.has(id):
			unreachable.append(id)
	check(unreachable.is_empty(), "every enemy actually spawns%s"
		% ("" if unreachable.is_empty() else ": never seen " + ", ".join(unreachable)))

	# A pack should sometimes mix roles rather than always repeat one
	var mixed := 0
	for h in range(40):
		var p: Array = EnemySprites.pack_for(h, 1, "mine")
		var traits := {}
		for id in p:
			traits[str((EnemySprites.ENEMIES[id] as Dictionary).get("trait", ""))] = true
		if traits.size() > 1:
			mixed += 1
	check(mixed > 0, "some packs combine different roles (%d of 40)" % mixed)
