extends RefCounted
## Organic cave paint — flowing rock, cracks, wet sheen (competitor-like).


static func cave_wall(size: int = 256) -> ImageTexture:
	return _organic_rock(
		size,
		Color(0.10, 0.28, 0.32),
		Color(0.20, 0.48, 0.50),
		Color(0.34, 0.66, 0.60),
		Color(0.50, 0.82, 0.72),
		Color(0.06, 0.14, 0.16),
		true
	)


static func cave_floor(size: int = 256) -> ImageTexture:
	return _organic_rock(
		size,
		Color(0.08, 0.16, 0.22),
		Color(0.14, 0.28, 0.34),
		Color(0.22, 0.40, 0.44),
		Color(0.32, 0.52, 0.54),
		Color(0.05, 0.10, 0.14),
		false
	)


static func cave_ceiling(size: int = 256) -> ImageTexture:
	var tex := _organic_rock(
		size,
		Color(0.08, 0.22, 0.26),
		Color(0.16, 0.38, 0.40),
		Color(0.26, 0.52, 0.48),
		Color(0.36, 0.64, 0.56),
		Color(0.05, 0.12, 0.14),
		true
	)
	return tex


static func _organic_rock(
	size: int,
	deep: Color,
	base: Color,
	mid: Color,
	hi: Color,
	crack: Color,
	drips: bool
) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			# Domain-warped FBM → flowing “painted” rock
			var wx := float(x) + _fbm(x, y, 0.04) * 28.0
			var wy := float(y) + _fbm(x + 50, y + 20, 0.05) * 28.0
			var n1 := _fbm(int(wx), int(wy), 0.035)
			var n2 := _fbm(int(wx * 1.7), int(wy * 1.7), 0.08)
			var n3 := _fbm(x * 3, y * 3, 0.15)

			var ridge := absf(n1 - 0.5) * 2.0
			var c := deep.lerp(base, n1).lerp(mid, n2 * 0.55)
			c = c.lerp(hi, (1.0 - ridge) * n2 * 0.35)

			# Dark cracks along low ridges
			if ridge > 0.72 or n3 < 0.18:
				c = c.lerp(crack, 0.55)
			elif ridge > 0.55:
				c = c.lerp(crack, 0.22)

			# Soft highlight blobs (wet rock)
			if n2 > 0.7 and ridge < 0.4:
				c = c.lerp(hi, 0.2)

			# Subtle grain
			if _hash(x, y) > 0.97:
				c = c.lightened(0.05)

			# Ceiling drips
			if drips and _hash(x, 3) > 0.94:
				var drip_len := int(12.0 + _hash(x, 9) * 50.0)
				if y < drip_len:
					c = c.darkened(0.1 + float(y) / float(size) * 0.08)

			img.set_pixel(x, y, c)

	# Soft ink outline pass (hand-paint edge)
	var out := img.duplicate()
	for y in range(1, size - 1):
		for x in range(1, size - 1):
			var c := img.get_pixel(x, y)
			var l := c.get_luminance()
			var dl := absf(l - img.get_pixel(x + 1, y).get_luminance()) + absf(l - img.get_pixel(x, y + 1).get_luminance())
			if dl > 0.08:
				out.set_pixel(x, y, c.darkened(0.12))
			else:
				out.set_pixel(x, y, c)
	return _tex_with_mips(out)


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
