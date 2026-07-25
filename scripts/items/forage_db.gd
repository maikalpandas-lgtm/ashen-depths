extends RefCounted
## Фаза E — the corridor has a reason to be walked.
##
## Two loops, both node-free so they can be tested:
##   FORAGE — things growing in the corridor, picked up with E
##   TROPHY — parts taken from monsters killed cleanly
##
## Both feed CONSUMABLES: three slots, spent in a fight. Gold buys power between
## floors; this buys a single turn inside one, which is a different decision.
##
## Art is docs/ART_PROMPTS.md §3.14 and has NOT arrived. Everything here works
## without it — sprites fall back to a coloured billboard — because the economy
## is worth playtesting before the pictures exist.

## Heights raised with the corridor props: a 0.35m clump in a 4.5m corridor is
## something you walk over without seeing, and an unnoticed pickup is no pickup.
##
## Where a forageable can grow. "any" appears in both biomes.
const FORAGE := {
	"glow_moss": {
		"name": "Светящийся мох", "art": "forage_glow_moss", "biome": "mine",
		"height": 0.5, "colour": Color(0.45, 0.85, 0.75),
		"gives": "broth",
	},
	"cave_mushroom": {
		"name": "Пещерный гриб", "art": "forage_cave_mushroom", "biome": "mine",
		"height": 0.55, "colour": Color(0.82, 0.78, 0.62),
		"gives": "antidote",
	},
	"bone_pile": {
		"name": "Костяные обломки", "art": "forage_bone_pile", "biome": "mine",
		"height": 0.6, "colour": Color(0.86, 0.84, 0.72),
		"gives": "bones",
	},
	"herbs": {
		"name": "Травы", "art": "forage_herbs", "biome": "forest",
		"height": 0.6, "colour": Color(0.4, 0.75, 0.35),
		"gives": "broth",
	},
	"berries": {
		"name": "Ягоды", "art": "forage_berries", "biome": "forest",
		"height": 0.55, "colour": Color(0.78, 0.22, 0.3),
		"gives": "rage_draught",
	},
	"amanita": {
		"name": "Мухомор", "art": "forage_amanita", "biome": "forest",
		"height": 0.55, "colour": Color(0.88, 0.28, 0.24),
		"gives": "antidote",
	},
}

## Consumables. `effect` is read by combat; `slots` are capped at CARRY_SLOTS.
const CONSUMABLES := {
	"broth": {
		"name": "Отвар", "art": "consum_broth", "colour": Color(0.72, 0.5, 0.25),
		"text": "Лечит 12 HP", "effect": "heal", "value": 12, "sell": 8,
	},
	"rage_draught": {
		"name": "Ярый настой", "art": "consum_rage_draught",
		"colour": Color(0.95, 0.5, 0.2),
		"text": "Ярость 2", "effect": "status", "status": "rage", "value": 2,
		"sell": 12,
	},
	"antidote": {
		"name": "Противоядие", "art": "consum_antidote",
		"colour": Color(0.4, 0.65, 0.9),
		"text": "Снимает Отраву и Порчу", "effect": "cleanse", "value": 0,
		"sell": 10,
	},
}

## Trophies — sold, not used. A second currency that only combat produces.
const TROPHIES := {
	"fang": {
		"name": "Клык", "art": "trophy_fang", "colour": Color(0.9, 0.88, 0.78),
		"sell": 14,
	},
	"hide": {
		"name": "Шкура", "art": "trophy_hide", "colour": Color(0.55, 0.45, 0.35),
		"sell": 18,
	},
	"ichor": {
		"name": "Навья слизь", "art": "trophy_ichor", "colour": Color(0.6, 0.4, 0.8),
		"sell": 26,
	},
}

## Bones are the existing combat resource (Echo spends them), so a bone pile
## feeds that rather than a new pouch.
const BONE_YIELD := 2

## How many consumables can be carried. Three, like the reference — enough for a
## choice, few enough that picking one up means dropping another.
const CARRY_SLOTS := 3

## Chance a walkable cell grows something, per cell.
const SPAWN_CHANCE := 0.14


## Which trophy a monster leaves. By realm, so a wolf and a mavka are not
## interchangeable loot.
static func trophy_for_realm(realm: String) -> String:
	match realm:
		"forest":
			return "hide"
		"nav":
			return "ichor"
		_:
			return "fang"


static func forage_ids_for(biome: String) -> Array:
	var out: Array = []
	for id in FORAGE.keys():
		var b := str(FORAGE[id].get("biome", "any"))
		if b == "any" or b == biome:
			out.append(str(id))
	return out


## Deterministic pick for a cell, so the same seed grows the same wood.
## Returns "" when nothing grows here.
static func roll_forage(cell_hash: int, biome: String) -> String:
	var ids := forage_ids_for(biome)
	if ids.is_empty():
		return ""
	# Cheap hash mix — the raw cell hash is too regular and produced stripes
	var h: int = absi(cell_hash * 2654435761) % 1000
	if float(h) / 1000.0 >= SPAWN_CHANCE:
		return ""
	return str(ids[absi(cell_hash / 7) % ids.size()])


static func consumable(id: String) -> Dictionary:
	return CONSUMABLES.get(id, {})


static func forage(id: String) -> Dictionary:
	return FORAGE.get(id, {})


static func trophy(id: String) -> Dictionary:
	return TROPHIES.get(id, {})


## Add to a carried list, respecting CARRY_SLOTS. Returns false when full —
## the caller must SAY so rather than silently eating the pickup.
static func add_consumable(carried: Array, id: String) -> bool:
	if not CONSUMABLES.has(id):
		return false
	if carried.size() >= CARRY_SLOTS:
		return false
	carried.append(id)
	return true


const ART_DIR := "res://assets/textures/"
static var _tex_cache: Dictionary = {}


## Sprite for a forageable, or null while §3.14 art is outstanding — callers
## fall back to a coloured billboard so the economy is playable meanwhile.
static func art(art_id: String) -> Texture2D:
	if _tex_cache.has(art_id):
		return _tex_cache[art_id]
	var path := ART_DIR + art_id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = ResourceLoader.load(path, "Texture2D") as Texture2D
	_tex_cache[art_id] = tex
	return tex
