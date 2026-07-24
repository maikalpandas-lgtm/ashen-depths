extends RefCounted
## Pure layout maths for on-screen labels. No nodes, no scene dependencies, so
## it can be tested headlessly — importing the combat overlay into a test hangs
## the run, and this is the part actually worth testing anyway.


## One shared baseline for the whole pack: a feet row for name + HP bar, and a
## head row for the intent.
##
## Labels used to be projected per monster, which looked wrong the moment two
## IDENTICAL enemies stood side by side: each stands on its own patch of an
## undulating cave floor, so their feet — and therefore their bars and intents —
## landed at different screen heights. A shipped frame had two identical shades
## with their intents 17px apart. The reference lines the whole row up.
##
## The feet row takes the LOWEST feet and the head row the HIGHEST head, so no
## label is ever drawn on top of the sprite it belongs to.
static func rows(feet_ys: Array, head_ys: Array) -> Dictionary:
	var feet := 0.0
	var head := 0.0
	var have := false
	for y in feet_ys:
		feet = float(y) if not have else maxf(feet, float(y))
		have = true
	have = false
	for y in head_ys:
		head = float(y) if not have else minf(head, float(y))
		have = true
	return {"feet": feet, "head": head}


## Push a row of label positions apart so none overlap, keeping each as close to
## its own anchor as the spacing allows, and pull the row inside [left, right].
##
## Bars are wider than the gap between monsters standing shoulder to shoulder:
## three grubs project about 40px apart while a bar is ~100px wide, so drawing
## each label straight over its owner made them collide.
static func separate(spots: Array[Vector2], min_gap: float,
		left: float, right: float) -> void:
	var n := spots.size()
	if n == 0:
		return
	if n == 1:
		spots[0] = Vector2(clampf(spots[0].x, left, right), spots[0].y)
		return

	# Sort by x so neighbours really are neighbours on screen
	var order: Array = []
	for i in range(n):
		order.append(i)
	order.sort_custom(func(a, b): return spots[a].x < spots[b].x)

	# Two passes: spread rightwards, then pull back inside. Enough for a handful
	# of labels, and it cannot oscillate.
	for _pass in range(2):
		for k in range(1, n):
			var cur: int = order[k]
			var prev: int = order[k - 1]
			var want: float = spots[prev].x + min_gap
			if spots[cur].x < want:
				spots[cur] = Vector2(want, spots[cur].y)
		var last: int = order[n - 1]
		if spots[last].x > right:
			spots[last] = Vector2(right, spots[last].y)
		for k in range(n - 2, -1, -1):
			var cur2: int = order[k]
			var next2: int = order[k + 1]
			var limit: float = spots[next2].x - min_gap
			if spots[cur2].x > limit:
				spots[cur2] = Vector2(limit, spots[cur2].y)
		var first: int = order[0]
		if spots[first].x < left:
			spots[first] = Vector2(left, spots[first].y)
