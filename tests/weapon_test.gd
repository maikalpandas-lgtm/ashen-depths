extends SceneTree
## Equipping a weapon. Фаза 3 of the loot work.
##
## The property worth protecting: a weapon must give NOTHING while merely carried.
## Otherwise the grid becomes a rack of stacking swords and the single slot stops
## being a decision — which is the whole reason it exists.
const ItemDB = preload("res://scripts/items/item_db.gd")
const Backpack = preload("res://scripts/items/backpack.gd")

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
	# every weapon must be well formed
	var weapons: Array = []
	for id in ItemDB.ids():
		if ItemDB.is_weapon(str(id)):
			weapons.append(str(id))
	check(weapons.size() >= 3, "there are weapons to choose between (%d)" % weapons.size())
	for id in weapons:
		var def: Dictionary = ItemDB.get_item(id)
		check(ItemDB.hand_art(id) != "", "%s names a hand sprite" % id)
		check(not (def.get("base", {}) as Dictionary).is_empty(),
			"%s actually does something" % id)
		check(int(def.get("sell", 0)) > 0, "%s can be sold" % id)

	var bp := Backpack.new()
	var sword: String = weapons[0]
	var uid := bp.auto_place(sword)
	check(uid != "", "a weapon fits in the bag")

	# CARRIED but not worn: no bonus at all
	var carried: Dictionary = bp.compute_mods()
	var idle_strike := int(carried.get("strike_dmg", 0))
	check(idle_strike == 0, "a carried weapon grants nothing (strike +%d)" % idle_strike)

	# WORN: bonus appears
	check(bp.equip(uid), "the weapon can be equipped")
	check(bp.equipped_id() == sword, "and reports itself as worn")
	var worn: Dictionary = bp.compute_mods()
	check(int(worn.get("strike_dmg", 0)) > 0,
		"a worn weapon grants its bonus (strike +%d)" % int(worn.get("strike_dmg", 0)))

	# taking it off removes the bonus again
	bp.unequip()
	check(bp.equipped_id() == "", "unequipping clears the slot")
	check(int(bp.compute_mods().get("strike_dmg", 0)) == 0,
		"and the bonus goes with it")

	# only ONE weapon at a time
	if weapons.size() >= 2:
		var uid2 := bp.auto_place(str(weapons[1]))
		if uid2 != "":
			bp.equip(uid)
			bp.equip(uid2)
			check(bp.equipped_uid == uid2, "equipping replaces the previous weapon")
			var both: Dictionary = bp.compute_mods()
			var def1: Dictionary = ItemDB.get_item(sword)
			var def2: Dictionary = ItemDB.get_item(str(weapons[1]))
			var sum_both := int((def1.get("base", {}) as Dictionary).get("strike_dmg", 0)) \
				+ int((def2.get("base", {}) as Dictionary).get("strike_dmg", 0))
			check(int(both.get("strike_dmg", 0)) < sum_both or sum_both == 0,
				"two weapons in the bag do NOT stack")

	# a non-weapon must be refused rather than silently equipped
	var bp2 := Backpack.new()
	var stone := bp2.auto_place("whetstone")
	if stone != "":
		check(not bp2.equip(stone), "a whetstone cannot be equipped")
		check(bp2.equipped_id() == "", "and the slot stays empty")

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
