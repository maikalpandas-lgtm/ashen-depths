extends RefCounted
## Cartoon cave rock like competitor: big stones, thick ink lines, soft fills.


static func cave_wall(size: int = 384) -> ImageTexture:
	return _cartoon_rock(
		size,
		Color(0.12, 0.22, 0.26),  # ink
		Color(0.18, 0.42, 0.46),  # deep fill
		Color(0.28, 0.58, 0.56),  # mid
		Color(0.42, 0.74, 0.68),  # light
		Color(0.55, 0.86, 0.78),  # highlight
		0.09,
		true
	)


static func cave_floor(size: int = 384) -> ImageTexture:
	return _cartoon_rock(
		size,
		Color(0.08, 0.12, 0.16),
		Color(0.12, 0.24, 0.30),
		Color(0.18, 0.34, 0.40),
		Color(0.26, 0.44, 0.48),
		Color(0.34, 0.54, 0.56),
		0.11,
		false
	)


static func cave_ceiling(size: int = 384) -> ImageTexture:
	return _cartoon_rock(
		size,
		Color(0.08, 0.16, 0.18),
		Color(0.14, 0.34, 0.36),
		Color(0.22, 0.48, 0.46),
		Color(0.32, 0.62, 0.56),
		Color(0.42, 0.74, 0.64),
		0.085,
		true
	)


static func _cartoon_rock(
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
	# Jittered grid of stone centers (large chunks like hand-paint)
	var cols := maxi(5, int(1.0 / cell_scale))
	var rows := cols + (1 if drips else 0)
	var pts: Array[Vector2] = []
	var ids: Array[int] = []
	for j in range(rows + 2):
		for i in range(cols + 2):
			var px := (float(i) + 0.12 + _hash(i, j) * 0.76) / float(cols) * float(size)
			var py := (float(j) + 0.12 + _hash(i + 4, j + 2) * 0.76) / float(rows) * float(size)
			pts.append(Vector2(px, py))
			ids.append(i * 97 + j * 31)

	for y in range(size):
		for x in range(size):
			var p := Vector2(float(x), float(y))
			var best := 1e9
			var second := 1e9
			var bid := 0
			for k in range(pts.size()):
				# Elliptical distance → irregular stones
				var q: Vector2 = p - pts[k]
				var stretch := 0.75 + _hash(ids[k], 3) * 0.55
				var d := sqrt(q.x * q.x + (q.y * stretch) * (q.y * stretch))
				if d < best:
					second = best
					best = d
					bid = ids[k]
				elif d < second:
					second = d

			var edge := second - best
			var ink_w := 2.8 + _hash(bid, 5) * 2.2
			# Thick ink border between stones
			if edge < ink_w:
				var t := edge / ink_w
				var c_ink := ink.darkened(_hash(bid, 6) * 0.1)
				# Soft outer ink, hard core
				if t < 0.45:
					img.set_pixel(x, y, c_ink)
					continue
				# Blend into stone
				var fill := _stone_fill(bid, best, size, deep, mid, lite, hi)
				img.set_pixel(x, y, c_ink.lerp(fill, (t - 0.45) / 0.55))
				continue

			var fill2 := _stone_fill(bid, best, size, deep, mid, lite, hi)
			# Inner rim shadow (gives depth like paint)
			if edge < ink_w + 3.5:
				fill2 = fill2.darkened(0.1 * (1.0 - (edge - ink_w) / 3.5))
			img.set_pixel(x, y, fill2)

	# Vertical drip stains (ceiling/wall)
	if drips:
		for x in range(size):
			if _hash(x, 11) < 0.9:
				continue
			var len := 10 + int(_hash(x, 12) * 55.0)
			var x0 := x
			for y in range(mini(len, size)):
				var c := img.get_pixel(x0, y)
				img.set_pixel(x0, y, c.darkened(0.07 + float(y) / float(size) * 0.06))
				if x0 + 1 < size and _hash(x, y) > 0.4:
					img.set_pixel(x0 + 1, y, img.get_pixel(x0 + 1, y).darkened(0.04))

	# No baked skirting bands — contact shadow is mesh-side only at floor–wall joint.
	return _tex_with_mips(img)


static func _stone_fill(bid: int, best: float, size: int, deep: Color, mid: Color, lite: Color, hi: Color) -> Color:
	var t := _hash(bid, 0)
	var t2 := _hash(bid, 1)
	var c := deep.lerp(mid, t).lerp(lite, t2 * 0.5)
	# Soft radial shading inside stone
	var shade := clampf(best / (float(size) * 0.12), 0.0, 1.0)
	c = c.darkened(shade * 0.14)
	# Specular-ish paint blob
	if _hash(bid, 2) > 0.55 and shade < 0.35:
		c = c.lerp(hi, 0.18)
	# Micro variation
	if _hash(bid * 3, int(best * 10.0)) > 0.92:
		c = c.lightened(0.04)
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
