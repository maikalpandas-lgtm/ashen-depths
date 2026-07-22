extends RefCounted
## MVP card definitions — DESIGN.md §7.7. Data only, no combat logic yet.
##
## Names and rules text are Russian: the game is set in Slavic myth, and the
## card ids stay Latin so code and art filenames never depend on the language.
##
## Cards are plain Dictionaries so they serialise into a save without a custom
## Resource, and so a deck can carry an owner tag alongside the id.
## No `class_name` on purpose — see AGENTS.md.

enum Type { STRIKE, GUARD, SKILL, SPELL, BLOOD }

## Sigils are tags; the rules live in DESIGN.md §7.3 and land in Phase 3.
enum Sigil { SHARP, PIERCE, SWEEP, DRAIN, FRAIL_HIT, BONE, SANGUINE, ECHO, WARD, CLEAVE }

## energy = ⚡, blood = 🩸 HP paid on play.
const CARDS := {
	"slice": {
		"name": "Сеча", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 6, "block": 0, "sigils": [],
		"text": "6 урона", "art": "card_slice",
	},
	"hack": {
		"name": "Рубка", "type": Type.STRIKE, "energy": 2, "blood": 0,
		"damage": 10, "block": 0, "sigils": [Sigil.SHARP],
		"text": "10 урона. Остриё: +2 по щиту", "art": "card_hack",
	},
	"block": {
		"name": "Заслон", "type": Type.GUARD, "energy": 1, "blood": 0,
		"damage": 0, "block": 5, "sigils": [],
		"text": "5 брони", "art": "card_block",
	},
	"cleave_cut": {
		"name": "Размах", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 5, "block": 0, "sigils": [Sigil.CLEAVE],
		"text": "5 урона, 50% соседу", "art": "card_cleave_cut",
	},
	"blood_lash": {
		"name": "Навий хлыст", "type": Type.BLOOD, "energy": 0, "blood": 4,
		"damage": 12, "block": 0, "sigils": [Sigil.SANGUINE, Sigil.DRAIN],
		"text": "−4 HP → 12 урона, вампиризм", "art": "card_blood_lash",
	},
	"bone_rattle": {
		"name": "Костогрем", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 4, "block": 0, "sigils": [Sigil.BONE],
		"text": "4 урона. Добил — кость", "art": "card_bone_rattle",
	},
	"echo_strike": {
		"name": "Отголосок", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 7, "block": 0, "sigils": [Sigil.ECHO],
		"text": "7 урона. Эхо при кости", "art": "card_echo_strike",
	},
	"ward": {
		"name": "Оберег", "type": Type.GUARD, "energy": 1, "blood": 0,
		"damage": 0, "block": 4, "sigils": [Sigil.WARD],
		"text": "4 брони и 1 шип", "art": "card_ward",
	},
	"offering": {
		"name": "Треба", "type": Type.SKILL, "energy": 0, "blood": 0,
		"damage": 0, "block": 0, "sigils": [],
		"text": "Сбрось карту: −1 к цене", "art": "card_offering",
	},
	"firebolt": {
		"name": "Огнестрел", "type": Type.SPELL, "energy": 1, "blood": 0,
		"damage": 5, "block": 0, "sigils": [Sigil.PIERCE],
		"text": "5 урона. Пробой брони", "art": "card_firebolt",
	},
}


static func has_card(id: String) -> bool:
	return CARDS.has(id)


## Returns a COPY — callers must not be able to edit the shared definition.
static func get_card(id: String) -> Dictionary:
	if not CARDS.has(id):
		push_error("[CardDB] unknown card id: %s" % id)
		return {}
	return (CARDS[id] as Dictionary).duplicate(true)


static func ids() -> Array:
	return CARDS.keys()
