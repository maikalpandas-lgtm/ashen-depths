extends RefCounted
## Viewmodel + wall torches. Asset catalog: assets/textures/ASSETS.md
## Do NOT regenerate sprites unless the user asks — edit code / reuse masters.
##
## Grid crawler: wall props FIXED (no billboard).
## ONE wall sprite only (no V-fold double).
## Flame = slow UV shimmer on upper part of texture (hand/stick solid).
## Viewmodel: gloves low in corners, corridor center open.


const TORCH_TEX_PATH := "res://assets/textures/torch.png"
const HAND_TORCH_PATH := "res://assets/textures/hand_torch.png"
const HAND_KNIFE_PATH := "res://assets/textures/hand_knife.png"
const GLOW_TEX_PATH := "res://assets/textures/torch_glow.png"
const FLAME_SHADER_PATH := "res://shaders/flame_shimmer.gdshader"

static var _torch_tex: Texture2D
static var _hand_torch_tex: Texture2D
static var _hand_knife_tex: Texture2D
static var _glow_tex: Texture2D
static var _glow_mat: StandardMaterial3D
static var _flame_shader: Shader
static var _soft_glow_tex: Texture2D


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
	if _soft_glow_tex == null:
		_soft_glow_tex = _make_fallback_glow()
	if _flame_shader == null and ResourceLoader.exists(FLAME_SHADER_PATH):
		_flame_shader = load(FLAME_SHADER_PATH) as Shader


static func _apply_flame_shimmer(
	spr: Sprite3D,
	tex: Texture2D,
	flame_start: float,
	time_scale: float = 0.7,
	warp: float = 0.018,
	blur: float = 0.009,
	emission: float = 1.6,
	billboard_y: bool = false
) -> void:
	if _flame_shader == null or tex == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = _flame_shader
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("time_scale", time_scale)
	mat.set_shader_parameter("warp_strength", warp)
	mat.set_shader_parameter("blur_strength", blur)
	mat.set_shader_parameter("flame_start", flame_start)
	mat.set_shader_parameter("flame_soft", 0.2)
	mat.set_shader_parameter("alpha_scissor", 0.08)
	mat.set_shader_parameter("emission_strength", emission)
	mat.set_shader_parameter("billboard_y", 1.0 if billboard_y else 0.0)
	spr.material_override = mat
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED


## Wall torch = ONE 2D sprite (art concept: props are 2D, only the map is 3D).
## Anchored to the wall cell, fixed-Y billboard so it never goes edge-on when the
## crawler turns 90°. Depth comes from the halo + emission + real light on rock.
## Local space: +Y up, -Z out into the corridor, +Z into the rock.
static func make_wall_torch(parent: Node3D, pos: Vector3, wall_dir: Vector2i) -> Node3D:
	_ensure_textures()
	if _torch_tex == null:
		push_warning("[TorchSprites] wall torch texture missing")
		return Node3D.new()

	var holder := Node3D.new()
	holder.name = "WallTorch"
	holder.position = pos
	if wall_dir.x != 0:
		holder.rotation.y = PI * 0.5 if wall_dir.x > 0.0 else -PI * 0.5
	else:
		holder.rotation.y = 0.0 if wall_dir.y > 0.0 else PI
	parent.add_child(holder)

	# Soft radial halo — procedural falloff, so no hard quad edge on the rock
	var glow := _make_soft_glow(1.1)
	glow.position = Vector3(0.0, 0.62, -0.1)
	holder.add_child(glow)

	# Art has a single bracket on the right and sits ~0.26 above the mount point,
	# so the sprite is lifted to put that bracket on the holder origin.
	var body := _make_sprite(_torch_tex, 0.00122, false)
	body.name = "TorchBody"
	body.position = Vector3(0.0, 0.26, -0.06)
	body.render_priority = 5
	holder.add_child(body)
	_apply_flame_shimmer(body, _torch_tex, 0.38, 0.65, 0.018, 0.009, 2.8, true)

	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.66, 0.34)
	# Tight warm pool: the rock must stay teal a couple of cells out, otherwise
	# 400 torches wash the whole cave to yellow.
	light.light_energy = 3.2
	light.omni_range = 7.2
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.66, -0.42)
	holder.add_child(light)

	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color(1.0, 0.48, 0.2)
	fill.light_energy = 0.7
	fill.omni_range = 2.0
	fill.position = Vector3(0.0, 0.45, -0.18)
	holder.add_child(fill)

	return holder


## Radial falloff quad — alpha reaches 0 well before the quad edge (no visible rectangle).
static func _make_soft_glow(size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_texture = _soft_glow_tex
	mat.albedo_color = Color(1.0, 0.68, 0.32, 0.5)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.render_priority = 2
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Gloves low in corners — not raised into corridor.
static func make_hand_torch(camera: Camera3D) -> Node3D:
	_ensure_textures()
	var root := Node3D.new()
	root.name = "ViewModel"
	camera.add_child(root)

	# LEFT torch — lower third, glove visible, does not block center
	var left := Node3D.new()
	left.name = "HandTorch"
	left.position = Vector3(-0.32, -0.22, -0.44)
	left.rotation_degrees = Vector3(6, 12, -6)
	root.add_child(left)

	if _glow_mat:
		var glow := _make_glow_quad(Vector2(0.22, 0.22))
		glow.name = "Glow"
		glow.position = Vector3(0.04, 0.12, 0.02)
		left.add_child(glow)

	if _hand_torch_tex:
		var hand := _make_sprite(_hand_torch_tex, 0.00098, false)
		hand.name = "HandSprite"
		hand.position = Vector3.ZERO
		hand.no_depth_test = true
		hand.render_priority = 8
		left.add_child(hand)
		# Flame tip shimmer only — glove solid
		_apply_flame_shimmer(hand, _hand_torch_tex, 0.48, 0.7, 0.018, 0.009, 1.7)

	var light := OmniLight3D.new()
	light.name = "HandTorchLight"
	light.light_color = Color(1.0, 0.78, 0.45)
	light.light_energy = 3.4
	light.omni_range = 7.8
	light.omni_attenuation = 1.15
	light.shadow_enabled = false
	light.position = Vector3(0.06, 0.12, 0.28)
	left.add_child(light)

	var kick := OmniLight3D.new()
	kick.name = "Kick"
	kick.light_color = Color(1.0, 0.65, 0.3)
	kick.light_energy = 0.75
	kick.omni_range = 2.3
	kick.position = Vector3(0.03, 0.08, 0.14)
	left.add_child(kick)

	# RIGHT knife — low right edge, not raised mid-screen
	if _hand_knife_tex:
		var right := Node3D.new()
		right.name = "HandKnife"
		right.position = Vector3(0.40, -0.26, -0.46)
		right.rotation_degrees = Vector3(4, -14, 4)
		root.add_child(right)
		var knife := _make_sprite(_hand_knife_tex, 0.00078, false, false)
		knife.name = "KnifeSprite"
		knife.no_depth_test = true
		knife.render_priority = 8
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
