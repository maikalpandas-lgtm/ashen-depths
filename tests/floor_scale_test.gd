extends SceneTree
## Depth scaling. Фаза F of docs/COMPETITOR_PLAN.md.
##
## Before this, enemy stats ignored the floor entirely: a grub on floor 10 had
## the same 7 HP as one on floor 1 while the hero gained levels, cards and gear
## the whole way down — the run got EASIER the deeper it went.
const FloorScale = preload("res://scripts/combat/floor_scale.gd")

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
	print("floor scaling")
	check(is_equal_approx(FloorScale.hp_mult(1), 1.0), "floor 1 is the baseline, unscaled")
	check(is_equal_approx(FloorScale.damage_mult(1), 1.0), "and its damage too")
	check(FloorScale.scale_hp(24, 1) == 24, "a brute on floor 1 keeps its table HP")

	# Monotonic: deeper is never softer.
	var prev_hp := 0.0
	var prev_dmg := 0.0
	for f in range(1, 21):
		var h: float = FloorScale.hp_mult(f)
		var d: float = FloorScale.damage_mult(f)
		if h < prev_hp - 0.0001 or d < prev_dmg - 0.0001:
			check(false, "floor %d is softer than floor %d" % [f, f - 1])
			return
		prev_hp = h
		prev_dmg = d
	check(true, "difficulty never goes backwards across 20 floors")

	# Health must outgrow damage, or a floor stops being harder and just becomes
	# shorter — dying in two turns is not difficulty, it is a coin flip.
	check(FloorScale.hp_mult(6) > FloorScale.damage_mult(6),
		"HP scales faster than the damage that kills you")

	# Scaling must never REDUCE a stat, whatever the rounding does
	for f in range(1, 15):
		for base in [1, 3, 7, 24, 52]:
			if FloorScale.scale_hp(base, f) < base:
				check(false, "floor %d shrank a %d HP monster" % [f, base])
				return
			if FloorScale.scale_damage(base, f) < base:
				check(false, "floor %d shrank a %d damage swing" % [f, base])
				return
	check(true, "scaling never makes a monster weaker than its table entry")

	# The soft cap has to actually bend the curve, or deep floors run away
	var early: float = FloorScale.hp_mult(FloorScale.SOFT_CAP_FLOOR) - FloorScale.hp_mult(FloorScale.SOFT_CAP_FLOOR - 1)
	var late: float = FloorScale.hp_mult(FloorScale.SOFT_CAP_FLOOR + 2) - FloorScale.hp_mult(FloorScale.SOFT_CAP_FLOOR + 1)
	check(late < early - 0.0001, "growth slows past the soft cap")

	# A sanity ceiling: floor 10 should be a real step up, not a wall
	var m10: float = FloorScale.hp_mult(10)
	check(m10 > 1.9 and m10 < 3.0, "floor 10 is %.2fx — a step up, not a wall" % m10)

	# Bad input must not explode
	check(FloorScale.hp_mult(0) >= 1.0, "floor 0 is clamped, not negative")
	check(FloorScale.hp_mult(-5) >= 1.0, "a negative floor is clamped too")

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
