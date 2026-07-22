extends RefCounted
## SUPERSEDED by shaders/cave_rock.gdshader — kept for reference only.
##
## Baking rock to a bitmap capped detail: 320px stretched over 7.2m of wall is
## 44 px/m, so stones went to mush up close, and a bigger bitmap cost seconds of
## load time on every dungeon. The shader draws the same stones per pixel.
##
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


## Toroidal (wrap) delta so rock texture tiles without visible square seams.
static func _wrap_d(d: float, period: float) -> float:
	var h := period * 0.5
	if d > h:
		d -= period
	elif d < -h:
		d += period
	return d


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
	var sf := float(size)
	# Interior lattice only — wrap distance makes edges seamless
	var cols := maxi(6, int(1.0 / cell_scale))
	var rows := cols
	var pts: Array[Vector2] = []
	var ids: Array[int] = []
	for j in range(rows):
		for i in range(cols):
			var px := (float(i) + 0.1 + _hash(i, j) * 0.8) / float(cols) * sf
			var py := (float(j) + 0.1 + _hash(i + 4, j + 2) * 0.8) / float(rows) * sf
			pts.append(Vector2(px, py))
			ids.append(i * 97 + j * 31)

	# Per-lattice-cell lookup: a pixel can only be near points in the 5x5 block
	# around it. Scanning all cols*rows points per pixel is what made the dungeon
	# take seconds to load.
	var cw := sf / float(cols)
	var ch := sf / float(rows)
	for y in range(size):
		var cj := int(float(y) / ch)
		for x in range(size):
			var ci := int(float(x) / cw)
			var px := float(x)
			var py := float(y)
			var best := 1e9
			var second := 1e9
			var bid := 0
			for dj in range(-2, 3):
				for di in range(-2, 3):
					var k := ((cj + dj + rows * 2) % rows) * cols + ((ci + di + cols * 2) % cols)
					var qx := _wrap_d(px - pts[k].x, sf)
					var qy := _wrap_d(py - pts[k].y, sf)
					# Faceted rocky cells (not round pebbles)
					var ax := absf(qx)
					var ay := absf(qy) * (0.72 + _hash(ids[k], 3) * 0.55)
					var d_box := maxf(ax, ay)
					var d_man := (ax + ay) * 0.52
					var d: float = d_box * 0.58 + d_man * 0.32 + sqrt(ax * ax + ay * ay) * 0.1
					if d < best:
						second = best
						best = d
						bid = ids[k]
					elif d < second:
						second = d

			var edge := second - best
			var ink_w := 3.4 + _hash(bid, 5) * 3.0
			if edge < ink_w:
				var t := edge / ink_w
				var c_ink := ink.darkened(_hash(bid, 6) * 0.12)
				if t < 0.38:
					img.set_pixel(x, y, c_ink)
					continue
				var fill := _stone_fill(bid, best, size, deep, mid, lite, hi)
				img.set_pixel(x, y, c_ink.lerp(fill, (t - 0.38) / 0.62))
				continue

			var fill2 := _stone_fill(bid, best, size, deep, mid, lite, hi)
			if edge < ink_w + 4.5:
				fill2 = fill2.darkened(0.16 * (1.0 - (edge - ink_w) / 4.5))
			if _hash(bid, 9) > 0.8 and int(best * 0.4 + float(x + y) * 0.03) % 13 == 0:
				fill2 = fill2.darkened(0.2)
			img.set_pixel(x, y, fill2)

	# Seamless drips: darken vertical veins that wrap in X
	if drips:
		for i in range(cols):
			if _hash(i, 11) < 0.72:
				continue
			var x0 := int((float(i) + 0.5) / float(cols) * sf) % size
			var len := 14 + int(_hash(i, 12) * 50.0)
			for yy in range(len):
				var y0 := yy % size
				img.set_pixel(x0, y0, img.get_pixel(x0, y0).darkened(0.12))
				var x1 := (x0 + 1) % size
				img.set_pixel(x1, y0, img.get_pixel(x1, y0).darkened(0.07))

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
