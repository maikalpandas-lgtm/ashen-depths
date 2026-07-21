extends RefCounted
## Procedural textures so the dungeon is not flat grey boxes.
## Use: preload("res://scripts/texture_factory.gd").stone_wall()


static func stone_wall(size: int = 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var mortar := Color(0.18, 0.16, 0.22)
	var brick_a := Color(0.42, 0.38, 0.48)
	var brick_b := Color(0.34, 0.30, 0.40)
	var brick_h := 16
	var brick_w := 32
	for y in range(size):
		var row: int = y / brick_h
		var y_in: int = y % brick_h
		var offset: int = (row % 2) * (brick_w / 2)
		for x in range(size):
			var x_shifted: int = (x + offset) % size
			var x_in: int = x_shifted % brick_w
			# mortar lines
			if y_in == 0 or y_in == brick_h - 1 or x_in == 0 or x_in == brick_w - 1:
				img.set_pixel(x, y, mortar)
			else:
				var n := _hash_noise(x_shifted / brick_w, row)
				var c := brick_a.lerp(brick_b, n)
				# subtle speckles
				if _hash_noise(x, y) > 0.92:
					c = c.darkened(0.15)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func stone_floor(size: int = 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var a := Color(0.20, 0.18, 0.24)
	var b := Color(0.28, 0.25, 0.32)
	var crack := Color(0.12, 0.10, 0.14)
	var tile := 32
	for y in range(size):
		for x in range(size):
			var tx: int = x % tile
			var ty: int = y % tile
			var n := _hash_noise(x / 4, y / 4)
			var c := a.lerp(b, n)
			if tx == 0 or ty == 0:
				c = crack
			elif tx < 2 or ty < 2:
				c = c.darkened(0.08)
			# wear
			if _hash_noise(x * 3, y * 5) > 0.88:
				c = c.lightened(0.06)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func wood_door(size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var n := _hash_noise(x / 2, y)
			var c := Color(0.38, 0.22, 0.12).lerp(Color(0.52, 0.32, 0.16), n)
			if x % 16 == 0:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func ceiling_dark(size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var n := _hash_noise(x, y)
			img.set_pixel(x, y, Color(0.10, 0.08, 0.12).lerp(Color(0.16, 0.13, 0.18), n * 0.5))
	return ImageTexture.create_from_image(img)


static func _hash_noise(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0
