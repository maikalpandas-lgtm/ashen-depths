extends RefCounted
## Dark angular cave rock: faceted stones, thick ink, drip stains (Spice Mines-ish).


static func cave_wall(size: int = 384) -> ImageTexture:
	return _angular_rock(
		size,
		Color(0.04, 0.08, 0.10),  # ink
		Color(0.06, 0.16, 0.18),  # deep
		Color(0.10, 0.26, 0.28),  # mid
		Color(0.16, 0.38, 0.36),  # lite
		Color(0.22, 0.48, 0.44),  # hi
		0.085,
		true
	)


static func cave_floor(size: int = 384) -> ImageTexture:
	return _angular_rock(
		size,
		Color(0.03, 0.05, 0.07),
		Color(0.05, 0.10, 0.14),
		Color(0.08, 0.16, 0.20),
		Color(0.12, 0.24, 0.28),
		Color(0.16, 0.30, 0.32),
		0.1,
		false
	)


static func cave_ceiling(size: int = 384) -> ImageTexture:
	return _angular_rock(
		size,
		Color(0.03, 0.06, 0.07),
		Color(0.05, 0.12, 0.14),
		Color(0.08, 0.20, 0.20),
		Color(0.12, 0.30, 0.28),
		Color(0.16, 0.38, 0.34),
		0.08,
		true
	)


static func _angular_rock(
	size: int,
	ink: Color,
	deep: Color,
	mid: Color,
	lite: Color,
	hi: Color,
	cell_scale: float,
	drips: bool
) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cols := maxi(5, int(1.0 / cell_scale))
	var rows := cols + (1 if drips else 0)
	var pts: Array[Vector2] = []
	var ids: Array[int] = []
	for j in range(rows + 2):
		for i in range(cols + 2):
			# Stronger jitter → irregular angular blocks
			var px := (float(i) + 0.08 + _hash(i, j) * 0.84) / float(cols) * float(size)
			var py := (float(j) + 0.08 + _hash(i + 4, j + 2) * 0.84) / float(rows) * float(size)
			pts.append(Vector2(px, py))
			ids.append(i * 97 + j * 31)

	for y in range(size):
		for x in range(size):
			var p := Vector2(float(x), float(y))
			var best := 1e9
			var second := 1e9
			var bid := 0
			for k in range(pts.size()):
				var q: Vector2 = p - pts[k]
				# Faceted distance: mix Chebyshev + Manhattan → angular stones, not round pebbles
				var ax := absf(q.x)
				var ay := absf(q.y) * (0.7 + _hash(ids[k], 3) * 0.6)
				var d_box := maxf(ax, ay)
				var d_man := (ax + ay) * 0.55
				var d := d_box * 0.62 + d_man * 0.38
				# Slight euclidean to avoid pure diamonds
				d = d * 0.78 + sqrt(ax * ax + ay * ay) * 0.22
				if d < best:
					second = best
					best = d
					bid = ids[k]
				elif d < second:
					second = d

			var edge := second - best
			var ink_w := 3.2 + _hash(bid, 5) * 2.8  # thicker cracks
			if edge < ink_w:
				var t := edge / ink_w
				var c_ink := ink.darkened(_hash(bid, 6) * 0.12)
				if t < 0.4:
					img.set_pixel(x, y, c_ink)
					continue
				var fill := _stone_fill(bid, best, size, deep, mid, lite, hi)
				img.set_pixel(x, y, c_ink.lerp(fill, (t - 0.4) / 0.6))
				continue

			var fill2 := _stone_fill(bid, best, size, deep, mid, lite, hi)
			# Harder inner rim (faceted depth)
			if edge < ink_w + 4.0:
				fill2 = fill2.darkened(0.14 * (1.0 - (edge - ink_w) / 4.0))
			# Extra crack lines across large faces
			if _hash(bid, 9) > 0.82 and int(best * 0.35 + float(x + y) * 0.02) % 17 == 0:
				fill2 = fill2.darkened(0.18)
			img.set_pixel(x, y, fill2)

	if drips:
		for x in range(size):
			if _hash(x, 11) < 0.88:
				continue
			var len := 12 + int(_hash(x, 12) * 70.0)
			var x0 := x
			for y in range(mini(len, size)):
				var c := img.get_pixel(x0, y)
				img.set_pixel(x0, y, c.darkened(0.1 + float(y) / float(size) * 0.08))
				if x0 + 1 < size and _hash(x, y) > 0.35:
					img.set_pixel(x0 + 1, y, img.get_pixel(x0 + 1, y).darkened(0.06))

	return _tex_with_mips(img)


static func _stone_fill(bid: int, best: float, size: int, deep: Color, mid: Color, lite: Color, hi: Color) -> Color:
	var t := _hash(bid, 0)
	var t2 := _hash(bid, 1)
	# Prefer deeper fills — only rare stones get lite highlight
	var c := deep.lerp(mid, t * 0.85).lerp(lite, t2 * 0.28)
	var shade := clampf(best / (float(size) * 0.11), 0.0, 1.0)
	c = c.darkened(shade * 0.2)
	# Flat facet highlight (angular plane, not soft blob)
	if _hash(bid, 2) > 0.62 and shade < 0.28:
		c = c.lerp(hi, 0.12)
	if _hash(bid * 3, int(best * 8.0)) > 0.94:
		c = c.lightened(0.03)
	return c


static func _tex_with_mips(img: Image) -> ImageTexture:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func crystal_sprite(size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return _tex_with_mips(img)


static func rock_pile_sprite(size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return _tex_with_mips(img)


static func _hash(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0
