extends SceneTree
## Фаза E economy. Node-free rules only.
##
## The failure modes here are quiet ones: a pickup that vanishes because the
## slots were full, a cleanse that strips your own buff, a trophy table that
## hands the same drop to every realm.
const ForageDB = preload("res://scripts/items/forage_db.gd")
const EnemySprites = preload("res://scripts/enemy_sprites.gd")

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
	_test_tables()
	_test_slots()
	_test_spawn()
	_test_drops()
	_test_trophies()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_tables() -> void:
	print("tables")
	# Every forageable must hand back something that EXISTS, or picking it up
	# silently does nothing.
	for id in ForageDB.FORAGE.keys():
		var gives := str(ForageDB.FORAGE[id]["gives"])
		var known: bool = ForageDB.CONSUMABLES.has(gives) or gives == "bones"
		check(known, "%s yields something real (%s)" % [id, gives])
	for id in ForageDB.CONSUMABLES.keys():
		var def: Dictionary = ForageDB.CONSUMABLES[id]
		check(str(def.get("effect", "")) != "", "%s has an effect" % id)
		check(int(def.get("sell", 0)) > 0, "%s is worth something" % id)
	for id in ForageDB.TROPHIES.keys():
		check(int(ForageDB.TROPHIES[id].get("sell", 0)) > 0, "trophy %s sells" % id)


func _test_slots() -> void:
	print("carry slots")
	var bag: Array = []
	for i in range(ForageDB.CARRY_SLOTS):
		check(ForageDB.add_consumable(bag, "broth"), "slot %d accepts a pickup" % i)
	# Full means REFUSED, not silently dropped — the caller has to be able to
	# tell the player why nothing happened.
	check(not ForageDB.add_consumable(bag, "broth"), "a full pouch refuses the pickup")
	check(bag.size() == ForageDB.CARRY_SLOTS, "and does not grow past its cap")
	check(not ForageDB.add_consumable([], "nonsense"), "an unknown consumable is refused")


func _test_spawn() -> void:
	print("spawn")
	# Deterministic: the same cell in the same biome must always grow the same
	# thing, or a regenerated floor rearranges itself under the player.
	for h in range(200):
		if ForageDB.roll_forage(h, "mine") != ForageDB.roll_forage(h, "mine"):
			check(false, "cell %d is not deterministic" % h)
			return
	check(true, "the same cell always grows the same thing")

	# Anything that spawns must belong to the biome it spawned in
	var mine_hits := 0
	var forest_hits := 0
	for h in range(3000):
		var m := ForageDB.roll_forage(h, "mine")
		if m != "":
			mine_hits += 1
			check_silent(str(ForageDB.FORAGE[m]["biome"]) in ["mine", "any"],
				"%s does not belong in the mines" % m)
		var f := ForageDB.roll_forage(h, "forest")
		if f != "":
			forest_hits += 1
			check_silent(str(ForageDB.FORAGE[f]["biome"]) in ["forest", "any"],
				"%s does not belong in the forest" % f)
	check(true, "every spawn belongs to its biome")

	# Density has to be worth walking for but not carpet the floor
	var rate := float(mine_hits) / 3000.0
	check(rate > 0.05 and rate < 0.30,
		"%.0f%% of cells grow something — worth looking for, not a carpet" % (rate * 100.0))
	check(forest_hits > 0, "the forest grows things too")


## Loot from a beaten pack. The failure mode is silence: a potion that drops into
## a full pouch and vanishes is a reward the player never learns they earned.
func _test_drops() -> void:
	print("drops from packs")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# Every kind must be able to drop something, and a boss more than a grub
	var counts := {}
	for kind in ["normal", "mini_boss", "floor_boss"]:
		var got := 0
		for i in range(400):
			got += ForageDB.roll_drops(kind, rng).size()
		counts[kind] = got
		check(got > 0, "%s packs drop potions (%d in 400)" % [kind, got])
	check(int(counts["floor_boss"]) > int(counts["normal"]),
		"a floor boss pays better than a normal pack (%d vs %d)"
			% [counts["floor_boss"], counts["normal"]])
	check(int(counts["mini_boss"]) > int(counts["normal"]),
		"an elite pays better than a normal pack")

	# Everything dropped must be a REAL consumable, or add_consumable refuses it
	# and the reward disappears with no message.
	for kind in ["normal", "mini_boss", "floor_boss"]:
		for i in range(200):
			for id in ForageDB.roll_drops(kind, rng):
				if not ForageDB.CONSUMABLES.has(str(id)):
					check(false, "%s dropped an unknown consumable: %s" % [kind, id])
					return
	check(true, "every drop is a real consumable")

	# A normal pack must not shower the player — the pouch holds three
	var max_at_once := 0
	for i in range(400):
		max_at_once = maxi(max_at_once, ForageDB.roll_drops("normal", rng).size())
	check(max_at_once <= ForageDB.CARRY_SLOTS,
		"one pack never drops more than the pouch can hold (%d)" % max_at_once)


func _test_trophies() -> void:
	print("trophies")
	var seen := {}
	for realm in ["mine", "nav", "forest"]:
		var t := ForageDB.trophy_for_realm(realm)
		check(ForageDB.TROPHIES.has(t), "%s drops a real trophy" % realm)
		seen[t] = true
	# Three realms must not all hand back the same part, or the pouch says
	# nothing about where you have been.
	check(seen.size() == 3, "each realm leaves a different trophy")
	# Every enemy in the game must map to one
	for id in EnemySprites.ids():
		var realm := str(EnemySprites.ENEMIES[id]["realm"])
		check_silent(ForageDB.TROPHIES.has(ForageDB.trophy_for_realm(realm)),
			"%s has no trophy" % id)
	check(true, "every enemy in the bestiary leaves something")


func check_silent(ok: bool, label: String) -> void:
	if not ok:
		check(false, label)
