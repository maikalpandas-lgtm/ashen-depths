extends RefCounted
## Hand-painted-ish cave tiles: large stone chunks + dark grout (not noise static).


static func cave_wall(size: int = 256) -> ImageTexture:
	## Softer stones — less ink contrast (avoids moire / aliasing up close).
	return _stone_tile(
		size,
		Color(0.16, 0.32, 0.36),
		Color(0.26, 0.48, 0.50),
		Color(0.36, 0.60, 0.58),
		Color(0.48, 0.72, 0.68),
		0.14,
		true
	)


static func cave_floor(size: int = 256) -> ImageTexture:
	return _stone_tile(
		size,
		Color(0.10, 0.18, 0.22),
		Color(0.18, 0.32, 0.38),
		Color(0.26, 0.42, 0.46),
		Color(0.34, 0.52, 0.54),
		0.15,
		false
	)


static func cave_ceiling(size: int = 256) -> ImageTexture:
	var img := _stone_tile_image(
		size,
		Color(0.08, 0.14, 0.16),
		Color(0.16, 0.30, 0.34),
		Color(0.24, 0.40, 0.40),
		Color(0.30, 0.48, 0.46),
		0.13,
		false
	)
	for x in range(size):
		if _hash(x, 7) < 0.88:
			continue
		var len := 6 + int(_hash(x, 9) * 28.0)
		for y in range(mini(len, size)):
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c.darkened(0.08))
	return _tex_with_mips(img)


static func _stone_tile(
	size: int,
	grout: Color,
	base: Color,
	mid: Color,
	hi: Color,
	cell_scale: float,
	vertical: bool
) -> ImageTexture:
	return _tex_with_mips(_stone_tile_image(size, grout, base, mid, hi, cell_scale, vertical))


static func _tex_with_mips(img: Image) -> ImageTexture:
	## Mipmaps kill close-up aliasing / “3D sparkle” on walls.
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	return tex


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

			# Soft edge blend (hard grout = moire when close)
			var edge := second_d - best_d
			var edge_w := 4.5 + _hash(best_id, 2) * 2.5
			var blend := clampf(1.0 - edge / edge_w, 0.0, 1.0)
			blend = blend * blend  # smoother falloff

			var t := _hash(best_id, 0)
			var t2 := _hash(best_id, 1)
			var c := base.lerp(mid, t).lerp(hi, t2 * 0.28)
			var shade := clampf(best_d / (float(size) * cell_scale * 4.0), 0.0, 1.0)
			c = c.darkened(shade * 0.12)
			if _hash(x, y) > 0.96:
				c = c.lightened(0.04)
			# Soft grout, not razor ink lines
			c = c.lerp(grout, blend * 0.75)
			img.set_pixel(x, y, c)
	return img


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
	return _tex_with_mips(img)


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
