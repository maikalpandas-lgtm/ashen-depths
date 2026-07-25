extends RefCounted
## Corridor enemies as 2D sprites (art concept: only the map is 3D).
##
## Billboarded on Y — for a grid crawler that is the design, not a shortcut:
## ROADMAP Phase 3 says "enemies in corridor (billboard)". Unlike the wall
## torch these use Sprite3D's own billboard property, because no shader
## overrides their material.

const ART_DIR := "res://assets/textures/"

## Formation across the corridor — ONE definition, used both when the pack is
## spawned in the world and when combat re-forms it, so a pack looks the same
## walking up to it as it does in the fight.
##
## Sized against the sprites that must fit: grub 1.34m wide, shade 1.48m,
## stone brute 2.36m, against ~3.5m of corridor clear of the rock bulge.
## Corridor width available to a row, after the worst-case rock bulge.
const CLEAR_WIDTH := 3.5
const MIN_SCALE := 0.6


## Widest sprite in a pack, in metres. Sizing a row by member COUNT alone was
## wrong: two grubs and two stone brutes are both "n = 2" but 2.7m and 4.7m of
## silhouette, so the brute pair always hung through the walls.
static func pack_widest(pack: Array) -> float:
	var widest := 0.0
	for id in pack:
		var def: Dictionary = ENEMIES.get(id, {})
		var px := art_size(str(def.get("art", "")))
		if px == Vector2i.ZERO or int(px.y) == 0:
			continue
		widest = maxf(widest, float(def["height"]) * float(px.x) / float(px.y))
	return widest if widest > 0.0 else 1.3


## Spacing and scale for a row of `pack`, fitted to the corridor.
static func form_layout(pack: Array) -> Dictionary:
	var n: int = maxi(1, pack.size())
	var w := pack_widest(pack)
	# Shrink only as far as the row actually needs
	var scale_f: float = clampf(CLEAR_WIDTH / (float(n) * w), MIN_SCALE, 1.0)
	var used := w * scale_f
	var spacing := 0.0
	if n > 1:
		# Spread across what is left, but never further apart than a body width
		# plus a little air — a pair should read as a pair, not as two loners.
		spacing = minf((CLEAR_WIDTH - used) / float(n - 1), used * 1.15)
	return {"spacing": spacing, "scale": scale_f}


static func form_spacing(pack: Array) -> float:
	return float(form_layout(pack)["spacing"])


static func form_scale(pack: Array) -> float:
	return float(form_layout(pack)["scale"])


## Floor at which the Root Labyrinth breaks through into Навь.
##
## Was 3, moved to 2 on 24.07.2026: the whole Slavic roster (анчутка, лихо,
## мавка, полудница) sat behind two floor clears, so a normal session never saw
## any of it — the mines were the entire game.
##
## THE one source of this number. The HUD used to hard-code `floor < 3` in two
## more places, which meant a change here would have left the panel saying
## "Рудники" while Навь mobs walked around in it.
const NAV_FROM_FLOOR := 2


## Human-readable realm for the HUD, so labels can never drift from the
## bestiary they describe.
static func realm_name(floor_index: int, biome: String = "mine") -> String:
	match realm_for(floor_index, biome):
		"forest":
			return "Лес"
		"nav":
			return "Навь"
		_:
			return "Рудники"

## Targeting rim (see shaders/sprite_outline.gdshader). Thickness is in SOURCE
## PIXELS and converted to UV per texture, so every monster gets the same rim
## however big its PNG happens to be.
const OUTLINE_SHADER := "res://shaders/sprite_outline.gdshader"
## Hit flash lives on the sprite's OWN material (shaders/sprite_flash.gdshader):
## the reference fills the silhouette white, which modulate cannot do.
const FLASH_SHADER := "res://shaders/sprite_flash.gdshader"
const RIM_COLOUR := Color(1.0, 0.66, 0.2, 1.0)
const RIM_PIXELS := 9.0

## Height in metres, so a rodent and a stone brute are not the same size on
## screen just because their PNGs happen to be similar.
## Two roster halves. The upper floors keep the cave bestiary; the deeper ones
## are Навь, where Slavic folklore lives. Kept as ONE table so a pack can mix
## when a floor sits on the boundary.
const ENEMIES := {
	# --- копи (верхние этажи) ---
	# HP roughly x1.8 on 25.07.2026. The starter Сеча deals 7, so a 7 HP grub
	# died to ONE card — the fight was over before any trait could act and the
	# whole trait system was invisible. A grub now takes two strikes, a stone
	# brute six, a boss a dozen.
	"grub": {"art": "enemy_grub", "height": 1.25, "hp": 14, "name": "Пещерный грызун",
		"realm": "mine", "trait": "swarm"},
	"brute": {"art": "enemy_brute", "height": 2.25, "hp": 40, "name": "Каменный дед",
		"realm": "mine", "trait": "guard"},
	"shade": {"art": "enemy_shade", "height": 1.7, "hp": 22, "name": "Тень рудокопа",
		"realm": "mine", "trait": "hexer"},
	"slug": {"art": "enemy_slug", "height": 1.15, "hp": 26, "name": "Рудный слизень",
		"realm": "mine", "trait": "poisoner"},
	"bat_swarm": {"art": "enemy_bat_swarm", "height": 1.5, "hp": 18, "name": "Нетопыри",
		"realm": "mine", "trait": "swarm"},
	# --- навь (нижние этажи) ---
	"anchutka": {"art": "enemy_anchutka", "height": 1.1, "hp": 13, "name": "Анчутка",
		"realm": "nav", "trait": "swarm"},
	"likho": {"art": "enemy_likho", "height": 2.1, "hp": 46, "name": "Лихо Одноглазое",
		"realm": "nav", "trait": "brute"},
	"mavka": {"art": "enemy_mavka", "height": 1.75, "hp": 25, "name": "Мавка",
		"realm": "nav", "trait": "hexer"},
	"poludnitsa": {"art": "enemy_poludnitsa", "height": 1.75, "hp": 30, "name": "Полудница",
		"realm": "nav", "trait": "weaver"},
	"bolotnik": {"art": "enemy_bolotnik", "height": 1.9, "hp": 34, "name": "Болотник",
		"realm": "nav", "trait": "poisoner"},
	"koldun": {"art": "enemy_koldun", "height": 1.8, "hp": 26, "name": "Мёртвый колдун",
		"realm": "nav", "trait": "howler"},
	# --- сказочный лес (второй тип карты, не этаж) ---
	"wolf": {"art": "enemy_wolf", "height": 1.3, "hp": 17, "name": "Волк",
		"realm": "forest", "trait": "swarm"},
	"kikimora": {"art": "enemy_kikimora", "height": 1.5, "hp": 23, "name": "Кикимора",
		"realm": "forest", "trait": "hexer"},
	"leshy": {"art": "enemy_leshy", "height": 2.3, "hp": 42, "name": "Леший",
		"realm": "forest", "trait": "howler"},
	"boar": {"art": "enemy_boar", "height": 1.5, "hp": 33, "name": "Вепрь",
		"realm": "forest", "trait": "brute"},
	"raven_flock": {"art": "enemy_raven_flock", "height": 1.4, "hp": 20, "name": "Вороньё",
		"realm": "forest", "trait": "weaver"},
	"bereginya": {"art": "enemy_bereginya", "height": 1.8, "hp": 38, "name": "Берегиня",
		"realm": "forest", "trait": "guard"},
	# --- боссы (те же спрайты, жирнее статы) ---
	"cave_warden": {
		"art": "enemy_brute", "height": 2.45, "hp": 78, "name": "Хранитель копи",
		"realm": "mine", "boss": true,
	},
	"nav_host": {
		"art": "enemy_likho", "height": 2.35, "hp": 95, "name": "Воевода Нави",
		"realm": "nav", "boss": true,
	},
	# Reuses the Леший art at a bigger scale, exactly like cave_warden reuses
	# the brute — a boss costs stats and a name, not another Grok batch.
	"forest_lord": {
		"art": "enemy_leshy", "height": 2.6, "hp": 88, "name": "Лесной хозяин",
		"realm": "forest", "boss": true,
	},
}


static func ids_of_realm(realm: String) -> Array:
	return ENEMIES.keys().filter(func(k): return ENEMIES[k]["realm"] == realm)

static var _tex_cache: Dictionary = {}
static var _shadow_tex: Texture2D = null


## PNG dimensions for an art id, so layout maths can reason about how wide a
## sprite actually is instead of assuming it is square.
static func art_size(art_id: String) -> Vector2i:
	var tex := _load(art_id)
	return Vector2i(tex.get_width(), tex.get_height()) if tex else Vector2i.ZERO


static func ids() -> Array:
	return ENEMIES.keys()


## Which realm a pack is drawn from. The forest is a MAP TYPE, not a depth, so
## it cannot be derived from floor_index the way Навь is — that is exactly the
## assumption that had to be broken to add it.
static func realm_for(floor_index: int, biome: String = "mine") -> String:
	if biome == "forest":
		return "forest"
	return "nav" if floor_index >= NAV_FROM_FLOOR else "mine"


## Which enemies stand in a pack. Kept deterministic per cell so a dungeon
## looks the same when regenerated from its seed.
## Packs never mix realms, so a paladin-era grub does not stand beside a mavka
## by accident.
static func pack_for(cell_hash: int, floor_index: int = 1, biome: String = "mine") -> Array:
	var realm := realm_for(floor_index, biome)
	# Packs are built as ROLE COMBINATIONS, not random picks: a howler beside a
	# brute is a different problem from two brutes, and that is the point of
	# traits existing at all (scripts/combat/enemy_traits.gd).
	if realm == "forest":
		match cell_hash % 7:
			0:
				return ["wolf", "wolf"]
			1:
				return ["leshy"]              # howler alone — easy
			2:
				return ["kikimora", "wolf"]
			3:
				return ["boar"]               # one heavy hit
			4:
				return ["leshy", "wolf", "wolf"]   # howler + swarm: kill it first
			5:
				return ["bereginya", "raven_flock"]  # guard + frail weaver
			_:
				return ["kikimora", "kikimora", "wolf"]
	if realm == "nav":
		match cell_hash % 7:
			0:
				return ["anchutka", "anchutka", "anchutka"]
			1:
				return ["likho"]
			2:
				return ["mavka", "anchutka"]
			3:
				return ["bolotnik"]           # poison, armour does not help
			4:
				return ["koldun", "anchutka", "anchutka"]  # howler + swarm
			5:
				return ["poludnitsa", "likho"]  # frail + heavy = the nasty one
			_:
				return ["bolotnik", "mavka"]
	match cell_hash % 7:
		0:
			return ["grub", "grub", "grub"]
		1:
			return ["brute"]
		2:
			return ["shade", "grub"]
		3:
			return ["slug"]                   # poison introduced gently
		4:
			return ["bat_swarm", "bat_swarm"]
		5:
			return ["brute", "slug"]          # guard + poison
		_:
			return ["shade", "shade"]


## Elite mid-floor pack — one fat body, more XP/gold than a normal pack.
static func mini_boss_pack(floor_index: int = 1, biome: String = "mine") -> Array:
	var realm := realm_for(floor_index, biome)
	if realm == "forest":
		return ["leshy", "boar"]
	if realm == "nav":
		return ["koldun", "likho"]
	return ["brute", "slug"]


## Floor boss near the EXIT campfire — DESIGN Phase 3 mini/floor boss.
static func floor_boss_pack(floor_index: int = 1, biome: String = "mine") -> Array:
	var realm := realm_for(floor_index, biome)
	if realm == "forest":
		return ["forest_lord", "kikimora"]
	if realm == "nav":
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
	# White-fill flash needs a shader; Sprite3D.billboard is ignored once a
	# material_override is set, so the shader does the billboarding too.
	var flash_mat := ShaderMaterial.new()
	flash_mat.shader = load(FLASH_SHADER)
	flash_mat.set_shader_parameter("albedo_tex", tex)
	flash_mat.set_shader_parameter("flash", 0.0)
	flash_mat.set_shader_parameter("billboard_y", 1.0)
	flash_mat.set_shader_parameter("alpha_cut", 0.2)
	spr.material_override = flash_mat
	holder.add_child(spr)

	# Target rim, hidden until the player drags a card onto this monster. It is
	# a SIBLING quad running the outline shader, not a material on the sprite
	# above: material_override would take the sprite's modulate with it, and
	# modulate is how the hit flash works (see combat_overlay).
	var rim := Sprite3D.new()
	rim.name = "Outline"
	rim.texture = tex
	rim.pixel_size = spr.pixel_size
	rim.centered = true
	rim.position = spr.position
	rim.transparent = true
	rim.shaded = false
	rim.double_sided = true
	rim.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rim.render_priority = 4
	rim.visible = false
	var rim_mat := ShaderMaterial.new()
	rim_mat.shader = load(OUTLINE_SHADER)
	rim_mat.set_shader_parameter("albedo_tex", tex)
	rim_mat.set_shader_parameter("rim_color", RIM_COLOUR)
	rim_mat.set_shader_parameter("alpha_cut", 0.2)
	# Constant thickness ON SCREEN: the rim is measured in UV, so a 1024px
	# monster and a 300px one need different numbers to look the same.
	rim_mat.set_shader_parameter("thickness", RIM_PIXELS / float(tex.get_width()))
	rim_mat.set_shader_parameter("billboard_y", 1.0)
	rim.material_override = rim_mat
	holder.add_child(rim)

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
