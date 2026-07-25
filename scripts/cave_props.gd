extends RefCounted
## Corridor set dressing for the mines and Навь — волна 3 of VISUAL_PLAN.
##
## Why this matters more than it sounds: the reference's corridors carry banners,
## barrels, rubble, crystals, grave markers and mushroom clumps, so no two
## stretches look alike. Ours had torches and nothing else, which is why every
## corridor read as the same corridor.
##
## Concept rule holds — 2D sprites, only the map is 3D (AGENTS.md).

const ART_DIR := "res://assets/textures/"

## Heights raised across the board on 25.07.2026 — at the old sizes rubble and
## mushrooms were specks a player walked past without registering. A corridor is
## 4.5m wide and 3.9m tall, so a 0.55m pile is nothing in it.
##
## `wall` props hang on a wall face like a torch; the rest stand on the floor.
## `weight` biases how often each appears — rubble is filler, a grave is an event.
const PROPS := {
	"prop_banner": {"height": 2.5, "wall": true, "weight": 3, "light": false},
	"prop_column": {"height": 3.4, "wall": false, "weight": 2, "light": false},
	"prop_barrel": {"height": 1.35, "wall": false, "weight": 3, "light": false},
	"prop_rubble": {"height": 0.95, "wall": false, "weight": 5, "light": false},
	"prop_wall_shrooms": {"height": 1.15, "wall": false, "weight": 4, "light": true},
	"prop_crystals": {"height": 1.55, "wall": false, "weight": 3, "light": true},
	"prop_bones_big": {"height": 1.25, "wall": false, "weight": 2, "light": false},
	"prop_grave": {"height": 2.0, "wall": false, "weight": 1, "light": false},
}

## Cold glow for the two that emit — crystals and mushrooms are the only reason
## the palette is not entirely torch-orange.
const GLOW := Color(0.5, 0.82, 0.95)

static var _tex_cache: Dictionary = {}
static var _bag: Array = []


static func _tex(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var path := ART_DIR + id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = ResourceLoader.load(path, "Texture2D") as Texture2D
	_tex_cache[id] = tex
	return tex


## Weighted id list, built once. A flat random pick would put as many grave
## markers in a corridor as piles of rubble.
static func _weighted() -> Array:
	if not _bag.is_empty():
		return _bag
	for id in PROPS.keys():
		for _i in range(int(PROPS[id].get("weight", 1))):
			_bag.append(str(id))
	return _bag


static func pick(hash_value: int, wall_available: bool) -> String:
	var bag := _weighted()
	# Walk the bag from the hashed start until something placeable turns up, so
	# a cell with no wall never silently gets nothing.
	for step in range(bag.size()):
		var id: String = str(bag[(absi(hash_value) + step) % bag.size()])
		if bool(PROPS[id].get("wall", false)) and not wall_available:
			continue
		return id
	return ""


## Height in metres, so the generator can work out where a hanging prop's middle
## sits before it decides how far off the rock to mount it.
static func height_of(id: String) -> float:
	return float(PROPS.get(id, {}).get("height", 1.0))


static func is_wall_prop(id: String) -> bool:
	return bool(PROPS.get(id, {}).get("wall", false))


## One prop planted with its base on `ground_y`.
static func make(parent: Node3D, id: String, pos: Vector3, ground_y: float,
		face: Vector2i = Vector2i.ZERO) -> Node3D:
	var def: Dictionary = PROPS.get(id, {})
	if def.is_empty():
		return null
	var tex := _tex(id)
	if tex == null:
		return null
	var height := float(def["height"])

	var holder := Node3D.new()
	holder.position = Vector3(pos.x, ground_y, pos.z)
	parent.add_child(holder)
	# Name AFTER add_child or duplicates become @Node3D@N (AGENTS.md)
	holder.name = "Prop_%s" % id

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
	spr.render_priority = 2
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if bool(def.get("wall", false)) and face != Vector2i.ZERO:
		# A banner hangs FLAT on its wall — billboarding it would make it swing
		# to face the player and stop reading as cloth on stone.
		spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		holder.rotation.y = atan2(float(-face.x), float(-face.y))
	else:
		spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# Slightly dimmed: set dressing must not compete with enemies for attention
	spr.modulate = Color(0.86, 0.9, 0.94)
	holder.add_child(spr)

	if bool(def.get("light", false)):
		var light := OmniLight3D.new()
		light.light_color = GLOW
		light.light_energy = 0.7
		light.omni_range = 2.6
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		light.position = Vector3(0.0, height * 0.55, 0.0)
		holder.add_child(light)

	# Combat backs its camera into these, same as the trees
	holder.add_to_group("combat_occluder")
	return holder
