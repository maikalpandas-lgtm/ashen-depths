extends SceneTree
## The hand fan must stay on screen and keep its cards in left-to-right order,
## whatever the hand size — a 10-card hand at the cap must not run off the strip.
const LabelLayout = preload("res://scripts/ui/label_layout.gd")

const CARD_W := 112.0
const OVERLAP := 0.80
const AREA_W := 900.0


## Mirror of CombatOverlay._fan_slot x maths. Kept here because importing the
## overlay into a headless test hangs the run (see AGENTS.md).
func slot_x(index: int, n: int) -> float:
	var step: float = CARD_W * OVERLAP
	var span: float = step * float(maxi(0, n - 1))
	if span > AREA_W - CARD_W:
		step = (AREA_W - CARD_W) / float(maxi(1, n - 1))
		span = step * float(maxi(0, n - 1))
	var t: float = 0.0 if n <= 1 else (float(index) / float(n - 1)) * 2.0 - 1.0
	return AREA_W * 0.5 + t * span * 0.5 - CARD_W * 0.5


func _init() -> void:
	var failed := 0
	for n in range(1, 11):
		var xs: Array = []
		for i in range(n):
			xs.append(slot_x(i, n))
		# in order
		for i in range(1, n):
			if xs[i] <= xs[i - 1]:
				printerr("  FAIL n=%d: card %d is not right of %d" % [n, i, i - 1])
				failed += 1
				break
		# on screen
		if xs[0] < -0.5 or xs[n - 1] + CARD_W > AREA_W + 0.5:
			printerr("  FAIL n=%d: fan runs off (%.0f .. %.0f of %.0f)"
				% [n, xs[0], xs[n - 1] + CARD_W, AREA_W])
			failed += 1
	if failed == 0:
		print("  ok   card fan fits and stays ordered (1..10 cards)")
	quit(1 if failed > 0 else 0)
