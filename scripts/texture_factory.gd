extends RefCounted
## Procedural cave textures — teal/stone like competitor reference.


static func cave_wall(size: int = 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var deep := Color(0.18, 0.32, 0.38)
	var mid := Color(0.28, 0.48, 0.52)
	var lite := Color(0.40, 0.62, 0.58)
	var dark := Color(0.10, 0.18, 0.22)
	for y in range(size):
		for x in range(size):
			var n := _fbm(x, y, 0.07)
			var n2 := _fbm(x + 40, y + 20, 0.15)
			var c := deep.lerp(mid, n).lerp(lite, n2 * 0.35)
			# organic cracks
			if n2 > 0.78:
				c = dark
			# wet sheen speckles
			if _hash(x * 3, y * 7) > 0.94:
				c = c.lightened(0.12)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func cave_floor(size: int = 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var a := Color(0.14, 0.22, 0.30)
	var b := Color(0.22, 0.34, 0.40)
	var crack := Color(0.08, 0.12, 0.16)
	for y in range(size):
		for x in range(size):
			var n := _fbm(x, y, 0.09)
			var c := a.lerp(b, n)
			# irregular stone plates
			var cell := int(x / 18) + int(y / 18) * 17
			if _hash(cell, cell * 3) > 0.55 and (x % 18 < 2 or y % 18 < 2):
				c = crack
			if _hash(x, y) > 0.9:
				c = c.lightened(0.08)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func cave_ceiling(size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var n := _fbm(x, y, 0.12)
			var c := Color(0.12, 0.22, 0.28).lerp(Color(0.22, 0.38, 0.40), n)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func crystal(size: int = 32) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var n := _hash(x, y)
			img.set_pixel(x, y, Color(0.45, 0.75, 0.95).lerp(Color(0.7, 0.9, 1.0), n))
	return ImageTexture.create_from_image(img)


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
	for _i in range(3):
		var ix := int(xf)
		var iy := int(yf)
		var fx := xf - float(ix)
		var fy := yf - float(iy)
		var a := _hash(ix, iy)
		var b := _hash(ix + 1, iy)
		var c := _hash(ix, iy + 1)
		var d := _hash(ix + 1, iy + 1)
		var u := fx * fx * (3.0 - 2.0 * fx)
		var w := fy * fy * (3.0 - 2.0 * fy)
		var i1 := lerpf(a, b, u)
		var i2 := lerpf(c, d, u)
		v += lerpf(i1, i2, w) * amp
		xf *= 2.0
		yf *= 2.0
		amp *= 0.5
	return clampf(v, 0.0, 1.0)
