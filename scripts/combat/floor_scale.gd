extends RefCounted
## How much tougher a floor is than the first one. Node-free, so it is testable
## and so the generator and combat cannot disagree about it.
##
## Before this, enemy stats did not depend on the floor AT ALL: a grub on floor
## 10 had the same 7 HP as one on floor 1, while the hero gained levels, cards
## and backpack items the whole way down. The run got EASIER the deeper it went,
## which is the opposite of what a descent should feel like.

## Per floor past the first, compounding. 18% is deliberately modest — the hero
## also grows, and the point is to keep pace, not to wall the player.
const HP_PER_FLOOR := 0.18
## Attacks scale slower than health: a floor that kills you in two turns is not
## harder, it is just shorter.
const DMG_PER_FLOOR := 0.10
## Past this the curve flattens, or floor 20 becomes arithmetic rather than play.
const SOFT_CAP_FLOOR := 8


static func _steps(floor_index: int) -> float:
	var f: int = maxi(1, floor_index)
	if f <= SOFT_CAP_FLOOR:
		return float(f - 1)
	# Half rate past the cap
	return float(SOFT_CAP_FLOOR - 1) + float(f - SOFT_CAP_FLOOR) * 0.5


static func hp_mult(floor_index: int) -> float:
	return 1.0 + HP_PER_FLOOR * _steps(floor_index)


static func damage_mult(floor_index: int) -> float:
	return 1.0 + DMG_PER_FLOOR * _steps(floor_index)


## Enemy max HP on this floor. Always at least the base value — a scale must
## never make a monster weaker than its own table entry.
static func scale_hp(base_hp: int, floor_index: int) -> int:
	return maxi(base_hp, int(round(float(base_hp) * hp_mult(floor_index))))


static func scale_damage(base_dmg: int, floor_index: int) -> int:
	return maxi(base_dmg, int(round(float(base_dmg) * damage_mult(floor_index))))
