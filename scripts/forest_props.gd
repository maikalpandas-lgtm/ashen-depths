extends RefCounted
## Forest biome props — trees, undergrowth, lights, horizon.
##
## The forest reuses the SAME grid the mines use. That is the whole trick: every
## system already built on that grid (pack placement, exit, chests, merchant,
## minimap, corridor axis for formations) keeps working untouched. Only what a
## "wall" cell LOOKS like changes — rock panels become a stand of trees.
##
## Concept rule (AGENTS.md): every object here is a 2D sprite. Only the ground
## is 3D. Do not rebuild a tree out of meshes to give it volume.

const ART_DIR := "res://assets/textures/"

## Trees that fill a wall cell. Heights in metres — deliberately taller than
## wall_height (3.9), because there is no ceiling to hide behind: a short tree
## lets the player see straight over the maze and the level stops reading as a
## forest.
const TREES := [
	{"art": "forest_pine", "height": 7.2},
	{"art": "forest_birch", "height": 6.4},
	{"art": "forest_oak_old", "height": 5.8},
]

## Ground clutter on walkable cells. Sparse on purpose — this is a corridor the
## player has to fight in, and a floor full of ferns hides the enemy sprites.
const UNDERGROWTH := [
	{"art": "forest_bush", "height": 0.9},
	{"art": "forest_fern", "height": 0.8},
	{"art": "forest_stump", "height": 0.7},
	{"art": "forest_log", "height": 0.6},
]

const LANTERN := {"art": "forest_lantern", "height": 2.4}
const GLOWSHROOM := {"art": "forest_glowshroom", "height": 0.7}
const CAMPFIRE := {"art": "forest_campfire", "height": 0.8}
const TREELINE := {"art": "forest_treeline", "height": 9.0}

static var _tex_cache: Dictionary = {}


## Imported resource FIRST — Image.load() on res:// does not work in an exported
## build, the files live in the .pck (AGENTS.md).
static func _tex(art_id: String) -> Texture2D:
	if _tex_cache.has(art_id):
		return _tex_cache[art_id]
	var path := ART_DIR + art_id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path, "Texture2D")
		if res is Texture2D:
			tex = res as Texture2D
	if tex == null:
		push_warning("[ForestProps] missing art: %s" % path)
	_tex_cache[art_id] = tex
	return tex


## One billboarded sprite planted with its FEET on `ground_y`.
##
## Sprite3D is centred, so the node has to be lifted by half its height or the
## art sinks to the waist — the same bug the enemy sprites had.
static func make_sprite(parent: Node3D, art_id: String, height: float,
		pos: Vector3, ground_y: float) -> Sprite3D:
	var tex := _tex(art_id)
	if tex == null:
		return null
	var spr := Sprite3D.new()
	spr.texture = tex
	spr.pixel_size = height / float(tex.get_height())
	spr.centered = true
	spr.transparent = true
	spr.shaded = false
	spr.double_sided = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.alpha_scissor_threshold = 0.2
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.render_priority = 3
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(spr)
	spr.global_position = Vector3(pos.x, ground_y + height * 0.5, pos.z)
	return spr


## Ground height at the sprite's OWN spot.
##
## Everything here is jittered up to ~1.5m off the cell centre, and the forest
## floor is the same undulating mesh the cave uses (it climbs ~0.16m toward the
## treeline on top of the noise). Seating a jittered trunk on the height read at
## the cell centre buried its foot in the ground — hence `ground_fn`, which the
## generator passes as `floor_height_at`. Falls back to the centre reading when
## no sampler is given.
static func _ground_at(ground_fn: Callable, fallback: float, pos: Vector3) -> float:
	if ground_fn.is_valid():
		return float(ground_fn.call(pos.x, pos.z))
	return fallback


## A stand of trees filling one wall cell. `h` is a per-cell hash so the same
## seed rebuilds the same wood.
static func make_tree_stand(parent: Node3D, world: Vector3, ground_y: float,
		cell_size: float, h: int, ground_fn: Callable = Callable()) -> void:
	var count := 2 + (h % 2)
	for i in range(count):
		var pick: Dictionary = TREES[(h / (i + 1) + i * 3) % TREES.size()]
		# Jitter inside the cell so the wood does not read as a grid of poles.
		var jx := (float((h * 7 + i * 31) % 100) / 100.0 - 0.5) * cell_size * 0.66
		var jz := (float((h * 13 + i * 17) % 100) / 100.0 - 0.5) * cell_size * 0.66
		var scale_f := 0.82 + float((h + i * 11) % 40) / 100.0
		var at := world + Vector3(jx, 0.0, jz)
		var spr := make_sprite(parent, str(pick["art"]),
			float(pick["height"]) * scale_f,
			at, _ground_at(ground_fn, ground_y, at))
		# Far trees sit deeper in shade, so the wall of wood has depth instead
		# of reading as one flat cutout wall.
		if spr:
			var shade := 0.55 + 0.12 * float(i)
			spr.modulate = Color(shade, shade * 1.02, shade * 0.94)
			# A 7m trunk right behind the player is a wall across the fight —
			# combat hides occluders near its camera (combat_overlay).
			spr.add_to_group("combat_occluder")


## Sparse clutter on a walkable cell. Kept OFF the centre line: a fern where the
## player walks ends up inside the camera.
static func make_undergrowth(parent: Node3D, world: Vector3, ground_y: float,
		cell_size: float, h: int, ground_fn: Callable = Callable()) -> void:
	var pick: Dictionary = UNDERGROWTH[h % UNDERGROWTH.size()]
	var side: float = 1.0 if (h % 2) == 0 else -1.0
	var off := cell_size * (0.30 + float(h % 7) / 60.0) * side
	var along := (float(h % 11) / 11.0 - 0.5) * cell_size * 0.5
	var pos := world + (Vector3(off, 0.0, along) if (h % 4) < 2 else Vector3(along, 0.0, off))
	var spr := make_sprite(parent, str(pick["art"]), float(pick["height"]), pos,
		_ground_at(ground_fn, ground_y, pos))
	if spr:
		spr.add_to_group("combat_occluder")


## Lantern on a pole — the forest's torch. Carries the same warm light so the
## corridor keeps its readability when the rock walls are gone.
static func make_lantern(parent: Node3D, world: Vector3, ground_y: float) -> void:
	var spr := make_sprite(parent, str(LANTERN["art"]), float(LANTERN["height"]),
		world, ground_y)
	if spr == null:
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.58)
	light.light_energy = 2.3
	light.omni_range = 6.4
	light.omni_attenuation = 1.35
	light.shadow_enabled = false
	spr.add_child(light)
	# Near the top of the pole, where the glass actually is
	light.position = Vector3(0.0, float(LANTERN["height"]) * 0.32, 0.0)


## Glowing mushrooms — cold light, so the wood is not uniformly amber.
static func make_glowshroom(parent: Node3D, world: Vector3, ground_y: float) -> void:
	var spr := make_sprite(parent, str(GLOWSHROOM["art"]), float(GLOWSHROOM["height"]),
		world, ground_y)
	if spr == null:
		return
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.9, 0.95)
	light.light_energy = 1.1
	light.omni_range = 3.4
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	spr.add_child(light)
	light.position = Vector3(0.0, float(GLOWSHROOM["height"]) * 0.4, 0.0)


## Ring of distant treeline around the whole map, so the edge of the grid does
## not show as an empty void. Sprites face inwards; they are far enough that
## fog swallows most of them.
static func make_horizon(parent: Node3D, centre: Vector3, radius: float) -> void:
	var tex := _tex(str(TREELINE["art"]))
	if tex == null:
		return
	var height := float(TREELINE["height"])
	var width := height * float(tex.get_width()) / float(tex.get_height())
	# Enough panels that neighbours overlap slightly — a gap in the ring is a
	# hole straight into the skybox.
	var count: int = maxi(8, int(ceil(TAU * radius / (width * 0.85))))
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var pos := centre + Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		var spr := Sprite3D.new()
		spr.texture = tex
		spr.pixel_size = height / float(tex.get_height())
		spr.centered = true
		spr.transparent = true
		spr.shaded = false
		spr.double_sided = true
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		spr.alpha_scissor_threshold = 0.2
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		# NOT billboarded: a billboarded ring spins with the camera and the
		# horizon visibly swims when the player turns 90 degrees.
		spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		spr.render_priority = 1
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spr.modulate = Color(0.42, 0.48, 0.55)
		parent.add_child(spr)
		spr.global_position = Vector3(pos.x, height * 0.42, pos.z)
		spr.rotation.y = -a + PI * 0.5
