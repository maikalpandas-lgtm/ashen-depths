extends RefCounted
## Viewmodel + wall torches. Asset catalog: assets/textures/ASSETS.md
## Do NOT regenerate sprites unless the user asks — edit code / reuse masters.


const TORCH_TEX_PATH := "res://assets/textures/torch.png"  # prop_wall_torch
const HAND_TORCH_PATH := "res://assets/textures/hand_torch.png"  # vm_hand_torch
const HAND_KNIFE_PATH := "res://assets/textures/hand_knife.png"  # vm_hand_knife
const GLOW_TEX_PATH := "res://assets/textures/torch_glow.png"  # fx_torch_glow

const FlameFlicker = preload("res://scripts/flame_flicker.gd")

static var _torch_tex: Texture2D
static var _hand_torch_tex: Texture2D
static var _hand_knife_tex: Texture2D
static var _glow_tex: Texture2D
static var _glow_mat: StandardMaterial3D


static func _load_png(path: String) -> Texture2D:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
			if res is Texture2D:
				return res as Texture2D
		push_warning("[TorchSprites] failed to load %s err=%s" % [path, err])
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)


static func _make_fallback_glow() -> Texture2D:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s * 0.5, s * 0.5)
	for y in range(s):
		for x in range(s):
			var d := Vector2(float(x), float(y)).distance_to(c) / (s * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 0.7, 0.3, a * 0.55))
	return ImageTexture.create_from_image(img)


static func _ensure_textures() -> void:
	if _torch_tex == null:
		_torch_tex = _load_png(TORCH_TEX_PATH)
	if _hand_torch_tex == null:
		_hand_torch_tex = _load_png(HAND_TORCH_PATH)
	if _hand_knife_tex == null:
		_hand_knife_tex = _load_png(HAND_KNIFE_PATH)
	if _glow_tex == null:
		_glow_tex = _load_png(GLOW_TEX_PATH)
		if _glow_tex == null:
			_glow_tex = _make_fallback_glow()
	if _glow_mat == null and _glow_tex != null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glow_mat.albedo_texture = _glow_tex
		_glow_mat.albedo_color = Color(1.0, 0.8, 0.4, 0.35)
		_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_glow_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		_glow_mat.render_priority = 2


## Mild squash/stretch on the torch sprite itself (no extra flame object). Lights stay static.
static func _add_torch_stretch(parent: Node, sprite: Node3D, amount: float = 0.08) -> void:
	var fx := FlameFlicker.new()
	fx.name = "FlameFlicker"
	fx.stretch_amount = amount
	fx.wobble_deg = 2.5
	fx.speed = 1.1 + randf() * 0.35
	fx.flicker_lights = false
	parent.add_child(fx)
	fx.setup(sprite, null, null)


## Wall torch — always readable in corridor (Y-billboard), single sprite, stretch anim.
static func make_wall_torch(parent: Node3D, pos: Vector3, wall_dir: Vector2i) -> Node3D:
	_ensure_textures()
	if _torch_tex == null:
		push_warning("[TorchSprites] wall torch texture missing")
		return Node3D.new()

	var holder := Node3D.new()
	holder.name = "WallTorch"
	holder.position = pos
	# Face roughly into corridor so light sits right; sprite billboards on Y for visibility
	if wall_dir.x != 0:
		holder.rotation.y = PI * 0.5 if wall_dir.x > 0 else -PI * 0.5
	else:
		holder.rotation.y = 0.0 if wall_dir.y > 0 else PI
	parent.add_child(holder)

	if _glow_mat:
		var glow := _make_glow_quad(Vector2(0.4, 0.4))
		glow.name = "Glow"
		glow.position = Vector3(0.0, 0.15, -0.08)
		holder.add_child(glow)

	# One sprite only (body + flame + mount) — Y-billboard so always visible
	var body := _make_sprite(_torch_tex, 0.0026, true)
	body.name = "TorchBody"
	body.position = Vector3(0.0, 0.0, -0.08)
	holder.add_child(body)
	# Mild stretch on wall torch only (small prop, not full arm)
	_add_torch_stretch(holder, body, 0.05)

	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 3.4
	light.omni_range = 7.0
	light.omni_attenuation = 1.15
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.2, -0.2)
	holder.add_child(light)

	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color(1.0, 0.55, 0.25)
	fill.light_energy = 0.9
	fill.omni_range = 2.4
	fill.position = Vector3(0.0, 0.1, -0.08)
	holder.add_child(fill)

	return holder


## FPS viewmodel: single hand torch sprite (stretch for fire), knife, no extra flame prop.
static func make_hand_torch(camera: Camera3D) -> Node3D:
	_ensure_textures()
	var root := Node3D.new()
	root.name = "ViewModel"
	camera.add_child(root)

	var left := Node3D.new()
	left.name = "HandTorch"
	# Higher in frame so hand+torch aren't clipped by bottom of screen
	left.position = Vector3(-0.34, -0.18, -0.48)
	left.rotation_degrees = Vector3(2, 8, -3)
	root.add_child(left)

	if _glow_mat:
		var glow := _make_glow_quad(Vector2(0.18, 0.18))
		glow.name = "Glow"
		glow.position = Vector3(0.05, 0.1, 0.02)
		left.add_child(glow)

	if _hand_torch_tex:
		var hand := _make_sprite(_hand_torch_tex, 0.00105, false)
		hand.name = "HandSprite"
		hand.position = Vector3(0.0, 0.0, 0.0)
		left.add_child(hand)
		# No stretch on full hand sprite — whole arm shook. Hand stays solid.

	var light := OmniLight3D.new()
	light.name = "HandTorchLight"
	light.light_color = Color(1.0, 0.78, 0.45)
	light.light_energy = 4.5
	light.omni_range = 8.0
	light.omni_attenuation = 0.9
	light.shadow_enabled = false
	light.position = Vector3(0.08, 0.14, 0.3)
	left.add_child(light)

	var kick := OmniLight3D.new()
	kick.name = "Kick"
	kick.light_color = Color(1.0, 0.65, 0.3)
	kick.light_energy = 1.4
	kick.omni_range = 2.4
	kick.position = Vector3(0.04, 0.08, 0.15)
	left.add_child(kick)

	if _hand_knife_tex:
		var right := Node3D.new()
		right.name = "HandKnife"
		right.position = Vector3(0.32, -0.16, -0.46)
		right.rotation_degrees = Vector3(2, -10, 2)
		root.add_child(right)
		var knife := _make_sprite(_hand_knife_tex, 0.0010, false, false)
		knife.name = "KnifeSprite"
		right.add_child(knife)

	return root


static func _make_sprite(
	tex: Texture2D,
	pixel_size: float,
	fixed_y_billboard: bool,
	use_alpha_scissor: bool = true
) -> Sprite3D:
	var spr := Sprite3D.new()
	spr.texture = tex
	spr.pixel_size = pixel_size
	spr.centered = true
	spr.transparent = true
	spr.shaded = false
	spr.double_sided = true
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.render_priority = 4
	if use_alpha_scissor:
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		spr.alpha_scissor_threshold = 0.12
	else:
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	if fixed_y_billboard:
		spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	else:
		spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	return spr


static func _make_glow_quad(size: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	var mat := _glow_mat.duplicate() as StandardMaterial3D
	mat.albedo_texture = _glow_tex
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
