extends RefCounted
## Hand-painted-ish cave tiles: large stone chunks + dark grout (not noise static).


static func cave_wall(size: int = 256) -> ImageTexture:
	## Vertical rock face — big teal stones, ink cracks, soft highlights.
	return _stone_tile(
		size,
		Color(0.12, 0.28, 0.32),   # grout
		Color(0.22, 0.48, 0.50),   # base stone
		Color(0.38, 0.68, 0.62),   # mid
		Color(0.55, 0.82, 0.72),   # highlight
		0.11,  # cell scale → fewer, bigger rocks
		true   # vertical stretch (wall grain)
	)


static func cave_floor(size: int = 256) -> ImageTexture:
	## Floor — cooler, flatter cobble plates.
	return _stone_tile(
		size,
		Color(0.08, 0.14, 0.18),
		Color(0.16, 0.30, 0.36),
		Color(0.24, 0.42, 0.46),
		Color(0.34, 0.55, 0.58),
		0.13,
		false
	)


static func cave_ceiling(size: int = 256) -> ImageTexture:
	## Ceiling — darker, mottled, slight drip stains.
	var img := _stone_tile_image(
		size,
		Color(0.06, 0.12, 0.14),
		Color(0.14, 0.30, 0.34),
		Color(0.22, 0.42, 0.42),
		Color(0.30, 0.52, 0.48),
		0.10,
		false
	)
	# drip streaks
	for x in range(size):
		if _hash(x, 7) < 0.82:
			continue
		var x0 := x
		var len := 8 + int(_hash(x, 9) * 40.0)
		for y in range(mini(len, size)):
			var c := img.get_pixel(x0, y)
			img.set_pixel(x0, y, c.darkened(0.12 + float(y) / float(size) * 0.1))
			if x0 + 1 < size:
				var c2 := img.get_pixel(x0 + 1, y)
				img.set_pixel(x0 + 1, y, c2.darkened(0.06))
	return ImageTexture.create_from_image(img)


static func _stone_tile(
	size: int,
	grout: Color,
	base: Color,
	mid: Color,
	hi: Color,
	cell_scale: float,
	vertical: bool
) -> ImageTexture:
	return ImageTexture.create_from_image(
		_stone_tile_image(size, grout, base, mid, hi, cell_scale, vertical)
	)


static func _stone_tile_image(
	size: int,
	grout: Color,
	base: Color,
	mid: Color,
	hi: Color,
	cell_scale: float,
	vertical: bool
) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Precompute Worley feature points on a coarse grid
	var gw := maxi(4, int(1.0 / cell_scale) + 2)
	var gh := gw
	if vertical:
		gh = maxi(5, int(1.0 / (cell_scale * 0.75)) + 2)
	var points: Array[Vector2] = []
	var point_ids: Array[int] = []
	for j in range(gh):
		for i in range(gw):
			var px := (float(i) + 0.15 + _hash(i, j) * 0.7) / float(gw) * float(size)
			var py := (float(j) + 0.15 + _hash(i + 3, j + 5) * 0.7) / float(gh) * float(size)
			points.append(Vector2(px, py))
			point_ids.append(i * 31 + j * 17)

	for y in range(size):
		for x in range(size):
			var p := Vector2(float(x), float(y))
			var best_d := 1e9
			var second_d := 1e9
			var best_id := 0
			for k in range(points.size()):
				var d: float = p.distance_to(points[k])
				if d < best_d:
					second_d = best_d
					best_d = d
					best_id = point_ids[k]
				elif d < second_d:
					second_d = d

			# Edge factor: near boundary between stones → grout
			var edge := second_d - best_d
			var edge_w := 3.2 + _hash(best_id, 2) * 2.0
			var is_grout := edge < edge_w

			if is_grout:
				var g := grout.darkened(_hash(x / 3, y / 3) * 0.15)
				img.set_pixel(x, y, g)
				continue

			# Stone body color variation per cell
			var t := _hash(best_id, 0)
			var t2 := _hash(best_id, 1)
			var c := base.lerp(mid, t).lerp(hi, t2 * 0.35)
			# Soft inner shading from cell center
			var shade := clampf(best_d / (float(size) * cell_scale * 3.5), 0.0, 1.0)
			c = c.darkened(shade * 0.18)
			# Speckle (paint grain, subtle)
			if _hash(x, y) > 0.92:
				c = c.lightened(0.06)
			elif _hash(x + 1, y + 3) > 0.94:
				c = c.darkened(0.07)
			# Rim light on upper side of stone (hand-paint feel)
			if not is_grout and y > 0:
				var up := img.get_pixel(x, y)  # not yet; use noise
				if _hash(best_id, y / 8) > 0.55 and shade < 0.35:
					c = c.lerp(hi, 0.12)
			# Dark outline just inside edge
			if edge < edge_w + 1.8:
				c = c.lerp(grout, 0.35)
			img.set_pixel(x, y, c)

	# Second pass: strengthen ink outlines where grout meets stone
	var out := img.duplicate()
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var c := img.get_pixel(x, y)
			var lum := c.get_luminance()
			var n_dark := 0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if img.get_pixel(x + ox, y + oy).get_luminance() < 0.2:
						n_dark += 1
			if n_dark >= 2 and lum > 0.25:
				out.set_pixel(x, y, c.darkened(0.2))
			else:
				out.set_pixel(x, y, c)
	return out


static func crystal_sprite(size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := size / 2.0
	var cy := size * 0.62
	for y in range(size):
		for x in range(size):
			var dx := (float(x) - cx) / (size * 0.22)
			var dy := (float(y) - cy) / (size * 0.55)
			var d := absf(dx) + absf(dy)
			if d < 1.0 and dy < 0.85:
				var t := 1.0 - d
				var c := Color(0.45, 0.85, 1.0, 0.95).lerp(Color(0.9, 0.97, 1.0, 1.0), t)
				if absf(dx) < 0.12:
					c = c.lightened(0.25)
				# dark outline
				if d > 0.88:
					c = Color(0.15, 0.25, 0.3, 0.9)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func rock_pile_sprite(size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_soft_circle(img, size * 0.35, size * 0.62, size * 0.22, Color(0.2, 0.4, 0.42, 1))
	_soft_circle(img, size * 0.55, size * 0.58, size * 0.2, Color(0.28, 0.5, 0.48, 1))
	_soft_circle(img, size * 0.45, size * 0.72, size * 0.18, Color(0.16, 0.32, 0.36, 1))
	return ImageTexture.create_from_image(img)


static func _soft_circle(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var size := img.get_width()
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) - cx, float(y) - cy).length() / r
			if d < 1.0:
				var a := clampf(1.0 - d * d, 0.0, 1.0)
				var prev := img.get_pixel(x, y)
				var out := col
				out.a = maxf(prev.a, a * col.a)
				if prev.a > 0.01:
					out = prev.lerp(col, a * 0.7)
					out.a = maxf(prev.a, a)
				# outline
				if d > 0.85:
					out = out.darkened(0.25)
				img.set_pixel(x, y, out)


static func _hash(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0
