extends RefCounted
## Corridor enemies as 2D sprites (art concept: only the map is 3D).
##
## Billboarded on Y — for a grid crawler that is the design, not a shortcut:
## ROADMAP Phase 3 says "enemies in corridor (billboard)". Unlike the wall
## torch these use Sprite3D's own billboard property, because no shader
## overrides their material.

const ART_DIR := "res://assets/textures/"

## Floor at which the Root Labyrinth breaks through into Навь
const NAV_FROM_FLOOR := 3

## Height in metres, so a rodent and a stone brute are not the same size on
## screen just because their PNGs happen to be similar.
## Two roster halves. The upper floors keep the cave bestiary; the deeper ones
## are Навь, where Slavic folklore lives. Kept as ONE table so a pack can mix
## when a floor sits on the boundary.
const ENEMIES := {
	# --- копи (верхние этажи) ---
	# Phase 5 balance: early packs die in ~2–3 strikes; bosses still bite
	"grub": {"art": "enemy_grub", "height": 1.25, "hp": 7, "name": "Пещерный грызун", "realm": "mine"},
	"brute": {"art": "enemy_brute", "height": 2.25, "hp": 24, "name": "Каменный дед", "realm": "mine"},
	"shade": {"art": "enemy_shade", "height": 1.7, "hp": 12, "name": "Тень рудокопа", "realm": "mine"},
	# --- навь (нижние этажи) ---
	"anchutka": {"art": "enemy_anchutka", "height": 1.1, "hp": 6, "name": "Анчутка", "realm": "nav"},
	"likho": {"art": "enemy_likho", "height": 2.1, "hp": 28, "name": "Лихо Одноглазое", "realm": "nav"},
	"mavka": {"art": "enemy_mavka", "height": 1.75, "hp": 14, "name": "Мавка", "realm": "nav"},
	"poludnitsa": {"art": "enemy_poludnitsa", "height": 1.75, "hp": 18, "name": "Полудница", "realm": "nav"},
	# --- боссы (те же спрайты, жирнее статы) ---
	"cave_warden": {
		"art": "enemy_brute", "height": 2.45, "hp": 42, "name": "Хранитель копи",
		"realm": "mine", "boss": true,
	},
	"nav_host": {
		"art": "enemy_likho", "height": 2.35, "hp": 52, "name": "Воевода Нави",
		"realm": "nav", "boss": true,
	},
}


static func ids_of_realm(realm: String) -> Array:
	return ENEMIES.keys().filter(func(k): return ENEMIES[k]["realm"] == realm)

static var _tex_cache: Dictionary = {}
static var _shadow_tex: Texture2D = null


static func ids() -> Array:
	return ENEMIES.keys()


## Which enemies stand in a pack. Kept deterministic per cell so a dungeon
## looks the same when regenerated from its seed.
## `floor_index` decides the realm: the mines on top, Навь below. Packs never
## mix realms, so a paladin-era grub does not stand beside a mavka by accident.
static func pack_for(cell_hash: int, floor_index: int = 1) -> Array:
	if floor_index >= NAV_FROM_FLOOR:
		match cell_hash % 4:
			0:
				return ["anchutka", "anchutka", "anchutka"]
			1:
				return ["likho"]
			2:
				return ["mavka", "anchutka"]
			_:
				return ["poludnitsa", "mavka"]
	match cell_hash % 4:
		0:
			return ["grub", "grub", "grub"]
		1:
			return ["brute"]
		2:
			return ["shade", "grub"]
		_:
			return ["shade", "shade"]


## Elite mid-floor pack — one fat body, more XP/gold than a normal pack.
static func mini_boss_pack(floor_index: int = 1) -> Array:
	if floor_index >= NAV_FROM_FLOOR:
		return ["likho", "anchutka"]
	return ["brute", "grub"]


## Floor boss near the EXIT campfire — DESIGN Phase 3 mini/floor boss.
static func floor_boss_pack(floor_index: int = 1) -> Array:
	if floor_index >= NAV_FROM_FLOOR:
		return ["nav_host", "mavka"]
	return ["cave_warden", "shade"]


## `ground_y` must be the real floor height at that spot — the cave floor is not
## flat, and a sprite pinned to y=0 hovers or sinks.
static func make_enemy(parent: Node3D, pos: Vector3, enemy_id: String, ground_y: float) -> Node3D:
	var def: Dictionary = ENEMIES.get(enemy_id, ENEMIES["grub"])
	var tex := _load(def["art"])
	if tex == null:
		return null

	var holder := Node3D.new()
	# Name AFTER add_child: setting it first means Godot throws the name away on
	# a collision and invents "@Node3D@3", so a pack of three identical grubs
	# left only ONE node matching an "Enemy_*" scan.
	holder.position = Vector3(pos.x, ground_y, pos.z)
	parent.add_child(holder)
	holder.name = "Enemy_%s" % enemy_id

	var height: float = def["height"]

	# Contact shadow first, so the sprite is never a sticker floating on the rock
	var shadow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(height * 0.9, height * 0.5)
	shadow.mesh = quad
	shadow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	# The cave floor is uneven; too low and parts of the quad sink into rock
	shadow.position = Vector3(0.0, 0.07, 0.0)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = _shadow()
	smat.albedo_color = Color(0.0, 0.0, 0.0, 0.78)
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	smat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	smat.render_priority = 1
	shadow.material_override = smat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(shadow)

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
	holder.add_child(spr)

	return holder


static func _shadow() -> Texture2D:
	if _shadow_tex != null:
		return _shadow_tex
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := Vector2(s * 0.5, s * 0.5)
	for y in range(s):
		for x in range(s):
			var d := Vector2(float(x), float(y)).distance_to(c) / (s * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a * a))
	_shadow_tex = ImageTexture.create_from_image(img)
	return _shadow_tex


static func _load(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var path := ART_DIR + id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = ResourceLoader.load(path, "Texture2D") as Texture2D
	if tex == null:
		var img := Image.new()
		if img.load(path) == OK:
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
		else:
			push_warning("[EnemySprites] missing art: %s" % path)
	_tex_cache[id] = tex
	return tex
