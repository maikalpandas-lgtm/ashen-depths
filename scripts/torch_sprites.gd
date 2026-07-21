extends RefCounted
## Viewmodel + wall torches. Asset catalog: assets/textures/ASSETS.md
## Do NOT regenerate sprites unless the user asks — edit code / reuse masters.
##
## Grid crawler: player only steps forward/back and turns 90°.
## Wall props are FIXED (no camera billboard) so they stay "nailed" to walls.


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
static var _glow_mat_fixed: StandardMaterial3D


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
	if _glow_mat_fixed == null and _glow_tex != null:
		_glow_mat_fixed = _glow_mat.duplicate() as StandardMaterial3D
		_glow_mat_fixed.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED


static func _add_torch_stretch(parent: Node, sprite: Node3D, amount: float = 0.05) -> void:
	var fx := FlameFlicker.new()
	fx.name = "FlameFlicker"
	fx.stretch_amount = amount
	fx.wobble_deg = 2.0
	fx.speed = 1.1 + randf() * 0.3
	fx.flicker_lights = false
	parent.add_child(fx)
	fx.setup(sprite, null, null)


## Wall torch FIXED to wall (no camera billboard). Grid crawler only faces 4 dirs.
## wall_dir = grid step from floor cell into the wall (normal of wall facing out of rock).
static func make_wall_torch(parent: Node3D, pos: Vector3, wall_dir: Vector2i) -> Node3D:
	_ensure_textures()
	if _torch_tex == null:
		push_warning("[TorchSprites] wall torch texture missing")
		return Node3D.new()

	var holder := Node3D.new()
	holder.name = "WallTorch"
	holder.position = pos
	# Sprite3D faces -Z by default. Point -Z into corridor (= -wall_dir).
	if wall_dir.x != 0:
		holder.rotation.y = PI * 0.5 if wall_dir.x > 0.0 else -PI * 0.5
	else:
		holder.rotation.y = 0.0 if wall_dir.y > 0.0 else PI
	parent.add_child(holder)

	# Fixed glow (not billboard) — sits with the torch
	if _glow_mat_fixed:
		var glow := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.35, 0.35)
		glow.mesh = quad
		glow.material_override = _glow_mat_fixed
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = Vector3(0.0, 0.12, -0.06)
		holder.add_child(glow)

	# Fixed sprite — nailed to wall, double-sided for side views
	var body := _make_sprite(_torch_tex, 0.0024, false)
	body.name = "TorchBody"
	body.position = Vector3(0.0, 0.0, -0.02)
	# Mirror when on certain walls so bracket art reads correctly
	if wall_dir.x < 0 or wall_dir.y < 0:
		body.flip_h = true
	holder.add_child(body)
	_add_torch_stretch(holder, body, 0.05)

	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 3.4
	light.omni_range = 7.0
	light.omni_attenuation = 1.15
	light.shadow_enabled = false
	# Light into the corridor
	light.position = Vector3(0.0, 0.18, -0.25)
	holder.add_child(light)

	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color(1.0, 0.55, 0.25)
	fill.light_energy = 0.9
	fill.omni_range = 2.4
	fill.position = Vector3(0.0, 0.1, -0.1)
	holder.add_child(fill)

	return holder


## FPS viewmodel: solid hand (no shake), knife.
static func make_hand_torch(camera: Camera3D) -> Node3D:
	_ensure_textures()
	var root := Node3D.new()
	root.name = "ViewModel"
	camera.add_child(root)

	var left := Node3D.new()
	left.name = "HandTorch"
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
		# Hand stays solid — no full-body stretch/shake

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
