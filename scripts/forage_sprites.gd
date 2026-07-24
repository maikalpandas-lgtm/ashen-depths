extends RefCounted
## Forageable props in the corridor — фаза E.
##
## Concept rule holds: these are 2D sprites, only the ground is 3D (AGENTS.md).
##
## While §3.14 art is outstanding they draw as a small coloured billboard using
## the tint from ForageDB. That is deliberately NOT a grey box: the colour is the
## one the real art will carry, so placement and scale can be judged now and the
## PNG drops straight in later.

const ForageDB = preload("res://scripts/items/forage_db.gd")

static var _blob: Texture2D = null


static func make(parent: Node3D, pos: Vector3, forage_id: String,
		ground_y: float) -> Node3D:
	var def: Dictionary = ForageDB.forage(forage_id)
	if def.is_empty():
		return null
	var height := float(def.get("height", 0.4))

	var holder := Node3D.new()
	holder.position = Vector3(pos.x, ground_y, pos.z)
	parent.add_child(holder)
	# Name AFTER add_child or Godot renames duplicates to @Node3D@N and they
	# become unfindable (AGENTS.md — cost us 405 torches once).
	holder.name = "Forage_%s" % forage_id
	holder.set_meta("forage_id", forage_id)
	holder.add_to_group("forage")

	var tex: Texture2D = ForageDB.art(str(def.get("art", "")))
	var placeholder := tex == null
	if placeholder:
		tex = _blob_tex()

	var spr := Sprite3D.new()
	spr.name = "Sprite"
	spr.texture = tex
	spr.pixel_size = height / float(tex.get_height())
	spr.centered = true
	spr.position = Vector3(0.0, height * 0.5, 0.0)
	spr.transparent = true
	spr.shaded = false
	spr.double_sided = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.alpha_scissor_threshold = 0.2
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.render_priority = 3
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if placeholder:
		spr.modulate = def.get("colour", Color.WHITE)
	holder.add_child(spr)

	# Faint glow so it is spotted in a dark corridor — a pickup nobody sees is
	# the same as no pickup at all.
	var light := OmniLight3D.new()
	light.light_color = def.get("colour", Color(0.8, 0.9, 0.8))
	light.light_energy = 0.55
	light.omni_range = 1.9
	light.shadow_enabled = false
	light.position = Vector3(0.0, height * 0.6, 0.0)
	holder.add_child(light)

	return holder


static func _blob_tex() -> Texture2D:
	if _blob != null:
		return _blob
	var s := 48
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s * 0.5, s * 0.62)
	for y in range(s):
		for x in range(s):
			var d := Vector2(float(x), float(y)).distance_to(c) / (s * 0.42)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_blob = ImageTexture.create_from_image(img)
	return _blob
