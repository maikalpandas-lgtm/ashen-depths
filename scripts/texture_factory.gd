extends RefCounted
## Painted-style cave textures (art-first, organic — not brick boxes).


static func cave_wall(size: int = 256) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var deep := Color(0.14, 0.32, 0.36)
	var mid := Color(0.26, 0.52, 0.50)
	var lite := Color(0.42, 0.70, 0.62)
	var foam := Color(0.55, 0.82, 0.72)
	var crack := Color(0.08, 0.16, 0.18)
	for y in range(size):
		for x in range(size):
			var n := _fbm(x, y, 0.045)
			var n2 := _fbm(x + 90, y - 40, 0.11)
			var n3 := _fbm(x * 2, y * 2, 0.2)
			# organic blobs like painted rock
			var blob := smoothstep(0.35, 0.75, n)
			var c := deep.lerp(mid, blob).lerp(lite, n2 * 0.4)
			# highlight ridges
			if n3 > 0.72 and n > 0.5:
				c = c.lerp(foam, 0.35)
			# dark crevices
			if n2 < 0.28 or (n3 < 0.22 and n < 0.45):
				c = c.lerp(crack, 0.55)
			# wet drip streaks
			var drip := _hash(x, y / 3)
			if drip > 0.93 and x % 7 < 2:
				c = c.darkened(0.12).lerp(Color(0.2, 0.45, 0.48), 0.3)
			img.set_pixel(x, y, c)
	_outline_boost(img, 0.08)
	return ImageTexture.create_from_image(img)


static func cave_floor(size: int = 256) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var a := Color(0.12, 0.22, 0.30)
	var b := Color(0.22, 0.38, 0.42)
	var c3 := Color(0.30, 0.48, 0.50)
	var dark := Color(0.06, 0.12, 0.16)
	for y in range(size):
		for x in range(size):
			var n := _fbm(x, y, 0.06)
			var n2 := _fbm(x + 30, y + 50, 0.14)
			var c := a.lerp(b, n).lerp(c3, n2 * 0.3)
			# irregular plates
			var cellx := x / 22
			var celly := y / 22
			var edge := mini(x % 22, y % 22)
			if edge < 2 and _hash(cellx, celly) > 0.4:
				c = dark.lerp(c, 0.35)
			if n2 > 0.8:
				c = c.lightened(0.07)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func cave_ceiling(size: int = 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var n := _fbm(x, y, 0.08)
			var c := Color(0.10, 0.24, 0.28).lerp(Color(0.22, 0.42, 0.40), n)
			if n > 0.7:
				c = c.lightened(0.08)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func crystal_sprite(size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := size / 2.0
	var cy := size * 0.62
	for y in range(size):
		for x in range(size):
			var dx := (float(x) - cx) / (size * 0.22)
			var dy := (float(y) - cy) / (size * 0.55)
			# diamond-ish crystal
			var d := absf(dx) + absf(dy)
			if d < 1.0 and dy < 0.85:
				var t := 1.0 - d
				var c := Color(0.45, 0.85, 1.0, 0.95).lerp(Color(0.85, 0.95, 1.0, 1.0), t)
				if absf(dx) < 0.12:
					c = c.lightened(0.2)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func rock_pile_sprite(size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# three overlapping blobs
	_soft_circle(img, size * 0.35, size * 0.62, size * 0.22, Color(0.25, 0.42, 0.45, 1))
	_soft_circle(img, size * 0.55, size * 0.58, size * 0.2, Color(0.32, 0.52, 0.50, 1))
	_soft_circle(img, size * 0.45, size * 0.72, size * 0.18, Color(0.2, 0.35, 0.38, 1))
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
				img.set_pixel(x, y, out)


static func _outline_boost(img: Image, amount: float) -> void:
	# cheap contrast on crevices already present
	var size := img.get_width()
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			if l < 0.25:
				img.set_pixel(x, y, c.darkened(amount))


static func _hash(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


static func _fbm(x: int, y: int, freq: float) -> float:
	var xf := float(x) * freq
	var yf := float(y) * freq
	var v := 0.0
	var amp := 0.5
	for _i in range(4):
		var ix := int(floor(xf))
		var iy := int(floor(yf))
		var fx := xf - float(ix)
		var fy := yf - float(iy)
		var a := _hash(ix, iy)
		var b := _hash(ix + 1, iy)
		var c := _hash(ix, iy + 1)
		var d := _hash(ix + 1, iy + 1)
		var u := fx * fx * (3.0 - 2.0 * fx)
		var w := fy * fy * (3.0 - 2.0 * fy)
		v += lerpf(lerpf(a, b, u), lerpf(c, d, u), w) * amp
		xf *= 2.0
		yf *= 2.0
		amp *= 0.5
	return clampf(v, 0.0, 1.0)


static func smoothstep(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
