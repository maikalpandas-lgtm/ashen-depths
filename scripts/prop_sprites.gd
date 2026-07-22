extends RefCounted
## Corridor props as 2D sprites (concept: only the map is 3D).
## Chest + wall brazier — same billboard approach as enemy_sprites / wall torches.

const ART_DIR := "res://assets/textures/"

static var _tex_cache: Dictionary = {}


static func make_chest(parent: Node3D, local_pos: Vector3, ground_y: float = 0.0) -> Node3D:
	var tex := _load("prop_chest")
	if tex == null:
		return null
	var holder := Node3D.new()
	holder.name = "ChestSprite"
	holder.position = local_pos
	parent.add_child(holder)

	var height := 0.85
	var spr := _make_sprite(tex, height)
	spr.name = "Sprite"
	spr.position = Vector3(0.0, height * 0.5 + ground_y, 0.0)
	holder.add_child(spr)
	return holder


## Wall brazier: fixed-Y billboard, cold cyan light (matches mine aesthetic).
static func make_brazier(parent: Node3D, pos: Vector3, wall_dir: Vector2i = Vector2i.ZERO) -> Node3D:
	var tex := _load("prop_brazier")
	if tex == null:
		return null
	var holder := Node3D.new()
	holder.name = "Brazier"
	holder.position = pos
	if wall_dir != Vector2i.ZERO:
		if wall_dir.x != 0:
			holder.rotation.y = PI * 0.5 if wall_dir.x > 0.0 else -PI * 0.5
		else:
			holder.rotation.y = 0.0 if wall_dir.y > 0.0 else PI
	parent.add_child(holder)

	var height := 1.15
	var spr := _make_sprite(tex, height)
	spr.name = "Sprite"
	# Nudge off the wall slightly so the stone bracket reads in free air
	spr.position = Vector3(0.0, height * 0.42, -0.08)
	holder.add_child(spr)

	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(0.55, 0.82, 1.0)
	light.light_energy = 1.55
	light.omni_range = 5.2
	light.omni_attenuation = 1.3
	light.position = Vector3(0.0, 0.75, -0.25)
	holder.add_child(light)
	return holder


static func _make_sprite(tex: Texture2D, height_m: float) -> Sprite3D:
	var spr := Sprite3D.new()
	spr.texture = tex
	spr.pixel_size = height_m / float(tex.get_height())
	spr.centered = true
	spr.transparent = true
	spr.shaded = false
	spr.double_sided = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.alpha_scissor_threshold = 0.15
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.render_priority = 3
	return spr


static func _load(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var path := ART_DIR + id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null and FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		push_warning("[PropSprites] missing: %s" % path)
	_tex_cache[id] = tex
	return tex
