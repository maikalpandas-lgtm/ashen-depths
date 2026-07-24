extends SceneTree
## The hand fan must stay on screen and keep its cards in left-to-right order,
## whatever the hand size — a 10-card hand at the cap must not run off the strip.
const FanLayout = preload("res://scripts/ui/fan_layout.gd")

const AREA := Vector2(900.0, 220.0)


func _init() -> void:
	var failed := 0
	for n in range(1, 11):
		var xs: Array = []
		for i in range(n):
			xs.append(FanLayout.slot(i, n, AREA, false, false)["pos"].x)
		for i in range(1, n):
			if xs[i] <= xs[i - 1]:
				printerr("  FAIL n=%d: card %d is not right of %d" % [n, i, i - 1])
				failed += 1
				break
		if xs[0] < -0.5 or xs[n - 1] + FanLayout.CARD_W > AREA.x + 0.5:
			printerr("  FAIL n=%d: fan runs off (%.0f .. %.0f of %.0f)"
				% [n, xs[0], xs[n - 1] + FanLayout.CARD_W, AREA.x])
			failed += 1
		# a raised card must sit higher and never rotate
		var flat: Dictionary = FanLayout.slot(0, n, AREA, false, false)
		var up: Dictionary = FanLayout.slot(0, n, AREA, true, false)
		if up["pos"].y >= flat["pos"].y or absf(float(up["angle"])) > 0.01:
			printerr("  FAIL n=%d: raised card does not lift and straighten" % n)
			failed += 1
	if failed == 0:
		print("  ok   card fan fits, stays ordered and lifts (1..10 cards)")
	quit(1 if failed > 0 else 0)
