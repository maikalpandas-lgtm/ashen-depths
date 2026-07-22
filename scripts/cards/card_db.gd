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
## rarity: common | uncommon | rare — Layer 2 rare-pick uses uncommon+rare.
const CARDS := {
	"slice": {
		"name": "Сеча", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 6, "block": 0, "sigils": [],
		"text": "6 урона", "art": "card_slice", "rarity": "common",
	},
	"hack": {
		"name": "Рубка", "type": Type.STRIKE, "energy": 2, "blood": 0,
		"damage": 10, "block": 0, "sigils": [Sigil.SHARP],
		"text": "10 урона. Остриё: +2 по щиту", "art": "card_hack",
		"rarity": "rare",
	},
	"block": {
		"name": "Заслон", "type": Type.GUARD, "energy": 1, "blood": 0,
		"damage": 0, "block": 5, "sigils": [],
		"text": "5 брони", "art": "card_block", "rarity": "common",
	},
	"cleave_cut": {
		"name": "Размах", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 5, "block": 0, "sigils": [Sigil.CLEAVE],
		"text": "5 урона, 50% соседу", "art": "card_cleave_cut",
		"rarity": "uncommon",
	},
	"blood_lash": {
		"name": "Навий хлыст", "type": Type.BLOOD, "energy": 0, "blood": 4,
		"damage": 12, "block": 0, "sigils": [Sigil.SANGUINE, Sigil.DRAIN],
		"text": "−4 HP → 12 урона, вампиризм", "art": "card_blood_lash",
		"rarity": "rare",
	},
	"bone_rattle": {
		"name": "Костогрем", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 4, "block": 0, "sigils": [Sigil.BONE],
		"text": "4 урона. Добил — кость", "art": "card_bone_rattle",
		"rarity": "uncommon",
	},
	"echo_strike": {
		"name": "Отголосок", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 7, "block": 0, "sigils": [Sigil.ECHO],
		"text": "7 урона. Эхо при кости", "art": "card_echo_strike",
		"rarity": "rare",
	},
	"ward": {
		"name": "Оберег", "type": Type.GUARD, "energy": 1, "blood": 0,
		"damage": 0, "block": 4, "sigils": [Sigil.WARD],
		"text": "4 брони и 1 шип", "art": "card_ward",
		"rarity": "uncommon",
	},
	"offering": {
		"name": "Треба", "type": Type.SKILL, "energy": 0, "blood": 0,
		"damage": 0, "block": 0, "sigils": [],
		"text": "Сбрось карту: −1 к цене", "art": "card_offering",
		"rarity": "uncommon",
	},
	"firebolt": {
		"name": "Огнестрел", "type": Type.SPELL, "energy": 1, "blood": 0,
		"damage": 5, "block": 0, "sigils": [Sigil.PIERCE],
		"text": "5 урона. Пробой брони", "art": "card_firebolt",
		"rarity": "common",
	},
}

## Each permanent upgrade level: +2 damage on strikes, +2 block on guards.
const UPGRADE_DAMAGE := 2
const UPGRADE_BLOCK := 2


static func has_card(id: String) -> bool:
	return CARDS.has(id)


## Returns a COPY — callers must not be able to edit the shared definition.
static func get_card(id: String) -> Dictionary:
	if not CARDS.has(id):
		push_error("[CardDB] unknown card id: %s" % id)
		return {}
	return (CARDS[id] as Dictionary).duplicate(true)


## Resolve a deck entry (id or {card, plus}) into a playable definition copy.
static func resolve_entry(entry) -> Dictionary:
	var card_id := ""
	var plus := 0
	if entry is Dictionary:
		card_id = str(entry.get("card", entry.get("id", "")))
		plus = int(entry.get("plus", 0))
	else:
		card_id = str(entry)
	var card := get_card(card_id)
	if card.is_empty():
		return {}
	if plus > 0:
		if int(card["damage"]) > 0:
			card["damage"] = int(card["damage"]) + plus * UPGRADE_DAMAGE
		if int(card["block"]) > 0:
			card["block"] = int(card["block"]) + plus * UPGRADE_BLOCK
		card["name"] = "%s+" % card["name"] if plus == 1 else "%s+%d" % [card["name"], plus]
		card["text"] = _upgraded_text(card)
		card["plus"] = plus
	return card


static func _upgraded_text(card: Dictionary) -> String:
	var parts: Array = []
	if int(card["damage"]) > 0:
		parts.append("%d урона" % int(card["damage"]))
	if int(card["block"]) > 0:
		parts.append("%d брони" % int(card["block"]))
	if parts.is_empty():
		return str(card.get("text", ""))
	return " · ".join(parts)


static func ids() -> Array:
	return CARDS.keys()


static func rare_pool() -> Array:
	return CARDS.keys().filter(
		func(k): return str(CARDS[k].get("rarity", "common")) in ["uncommon", "rare"])
