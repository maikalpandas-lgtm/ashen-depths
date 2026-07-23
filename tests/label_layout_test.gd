extends SceneTree
## HP labels must never overlap, whatever the camera does to their projected
## positions — three monsters standing shoulder to shoulder project barely 40px
## apart while a bar is 92-112px wide.
const LabelLayout = preload("res://scripts/ui/label_layout.gd")

const GAP := 102.0
const LEFT := 230.0
const RIGHT := 1870.0


func _init() -> void:
	var failed := 0
	var cases := [
		[Vector2(600, 200), Vector2(640, 200), Vector2(680, 200)],
		[Vector2(300, 200), Vector2(900, 200)],
		[Vector2(700, 200), Vector2(700, 200), Vector2(700, 200), Vector2(700, 200)],
		[Vector2(1900, 200), Vector2(1910, 200)],
		[Vector2(100, 200), Vector2(105, 200)],
		[Vector2(500, 200)],
	]
	for case in cases:
		var spots: Array[Vector2] = []
		for v in case:
			spots.append(v)
		LabelLayout.separate(spots, GAP, LEFT, RIGHT)
		var xs: Array = []
		for v in spots:
			xs.append(v.x)
		xs.sort()
		var bad := ""
		for i in range(1, xs.size()):
			if xs[i] - xs[i - 1] < GAP - 0.5:
				bad = "gap %.1f" % (xs[i] - xs[i - 1])
		# A row that fits must also stay on screen
		if xs.size() > 0 and float(xs.size() - 1) * GAP <= RIGHT - LEFT:
			if xs[0] < LEFT - 0.5 or xs[xs.size() - 1] > RIGHT + 0.5:
				bad = "off screen %.0f..%.0f" % [xs[0], xs[xs.size() - 1]]
		if bad != "":
			printerr("  FAIL %s -> %s" % [case, bad])
			failed += 1
	if failed == 0:
		print("  ok   HP labels never overlap (%d layouts)" % cases.size())
	quit(1 if failed > 0 else 0)
