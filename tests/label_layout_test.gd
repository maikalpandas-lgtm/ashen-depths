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
	failed += _rows_are_shared()
	quit(1 if failed > 0 else 0)


## Two identical monsters on uneven floor must still get ONE row of labels.
func _rows_are_shared() -> int:
	var bad := 0
	# feet at different heights (undulating floor), heads likewise
	var r: Dictionary = LabelLayout.rows([490.0, 507.0], [305.0, 322.0])
	if not is_equal_approx(float(r["feet"]), 507.0):
		printerr("  FAIL feet row %s, want the LOWEST feet (507)" % r["feet"])
		bad += 1
	if not is_equal_approx(float(r["head"]), 305.0):
		printerr("  FAIL head row %s, want the HIGHEST head (305)" % r["head"])
		bad += 1
	# a mixed pack: the row must clear the tall one, not the average
	var r2: Dictionary = LabelLayout.rows([500.0, 480.0, 512.0], [400.0, 210.0, 395.0])
	if not is_equal_approx(float(r2["feet"]), 512.0) or not is_equal_approx(float(r2["head"]), 210.0):
		printerr("  FAIL mixed pack rows %s" % r2)
		bad += 1
	if LabelLayout.rows([], []).is_empty():
		printerr("  FAIL empty pack should still return a dictionary")
		bad += 1
	if bad == 0:
		print("  ok   name / HP / intent share one row per pack")
	return bad
