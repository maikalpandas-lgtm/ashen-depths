extends SceneTree
## Card flourish timing. Фаза F of docs/COMPETITOR_PLAN.md.
##
## The thing worth protecting is the HOLD: the card must sit still long enough
## to be read. A curve that eases straight through the middle looks slick and
## leaves the player unable to say what they just picked up — which is the exact
## problem the flourish exists to fix.
const Flourish = preload("res://scripts/ui/flourish_anim.gd")

const VIEW := Vector2(1280, 720)
const CARD := Vector2(268, 375)

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
	_test_beats()
	_test_hold()
	_test_placement()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_beats() -> void:
	print("beats")
	var start: Dictionary = Flourish.frame(0.0, VIEW, CARD)
	check(is_equal_approx(float(start["alpha"]), 0.0), "starts invisible")
	check(float(start["scale"]) < Flourish.HOLD_SCALE, "and starts small")

	var mid: Dictionary = Flourish.frame(Flourish.RISE + Flourish.HOLD * 0.5, VIEW, CARD)
	check(is_equal_approx(float(mid["alpha"]), 1.0), "fully opaque while held")
	check(is_equal_approx(float(mid["scale"]), Flourish.HOLD_SCALE), "at full size while held")

	var late: Dictionary = Flourish.frame(Flourish.TOTAL - 0.001, VIEW, CARD)
	check(float(late["alpha"]) < 0.05, "has faded out by the end")

	# Past the end it must stay valid — _process reads one more frame before it
	# stops, and a NaN or a jump there would flash on screen.
	var over: Dictionary = Flourish.frame(Flourish.TOTAL + 1.0, VIEW, CARD)
	check(float(over["alpha"]) <= 0.001, "stays faded past the end")
	check(not is_nan(float(over["scale"])), "no NaN past the end")


func _test_hold() -> void:
	print("hold")
	# The card must be STILL for the whole hold, not merely opaque: a drifting
	# card is as hard to read as a fading one.
	var a: Dictionary = Flourish.frame(Flourish.RISE + 0.01, VIEW, CARD)
	var b: Dictionary = Flourish.frame(Flourish.RISE + Flourish.HOLD - 0.01, VIEW, CARD)
	check((a["pos"] as Vector2).distance_to(b["pos"] as Vector2) < 0.5,
		"the card does not move while it is being read")
	check(Flourish.HOLD >= 0.5, "the hold is long enough to read a card (%.2fs)" % Flourish.HOLD)
	check(Flourish.TOTAL <= 1.6, "but the whole thing stays out of the way (%.2fs)" % Flourish.TOTAL)


func _test_placement() -> void:
	print("placement")
	for t in [0.0, Flourish.RISE, Flourish.RISE + Flourish.HOLD * 0.5, Flourish.TOTAL - 0.01]:
		var f: Dictionary = Flourish.frame(t, VIEW, CARD)
		var pos: Vector2 = f["pos"]
		check(pos.x >= 0.0 and pos.x + CARD.x <= VIEW.x,
			"t=%.2f: stays on screen horizontally" % t)
		# The bottom third is the hand and the draft row. Covering them is what
		# the flourish must NOT do — it would hide the choice it is announcing.
		check(pos.y + CARD.y <= VIEW.y * 0.85,
			"t=%.2f: clears the bottom of the screen" % t)
		check(float(f["caption_y"]) > pos.y + CARD.y,
			"t=%.2f: the caption sits under the card, not on it" % t)

	# A short window must not push the card off the top
	var small: Dictionary = Flourish.frame(Flourish.RISE, Vector2(1024, 600), CARD)
	check((small["pos"] as Vector2).y >= 0.0, "fits a 600px window")
