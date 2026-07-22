extends RefCounted
## MVP card definitions — DESIGN.md §7.7. Data only, no combat logic yet.
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
		"name": "Slice", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 6, "block": 0, "sigils": [],
		"text": "Deal 6 damage.", "art": "card_slice",
	},
	"hack": {
		"name": "Hack", "type": Type.STRIKE, "energy": 2, "blood": 0,
		"damage": 10, "block": 0, "sigils": [Sigil.SHARP],
		"text": "Deal 10 damage. Sharp: +2 vs Block.", "art": "card_hack",
	},
	"block": {
		"name": "Block", "type": Type.GUARD, "energy": 1, "blood": 0,
		"damage": 0, "block": 5, "sigils": [],
		"text": "Gain 5 Block.", "art": "card_block",
	},
	"cleave_cut": {
		"name": "Cleave Cut", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 5, "block": 0, "sigils": [Sigil.CLEAVE],
		"text": "Deal 5 damage, 50% to a neighbour.", "art": "card_cleave_cut",
	},
	"blood_lash": {
		"name": "Blood Lash", "type": Type.BLOOD, "energy": 0, "blood": 4,
		"damage": 12, "block": 0, "sigils": [Sigil.SANGUINE, Sigil.DRAIN],
		"text": "Pay 4 HP. Deal 12, heal half.", "art": "card_blood_lash",
	},
	"bone_rattle": {
		"name": "Bone Rattle", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 4, "block": 0, "sigils": [Sigil.BONE],
		"text": "Deal 4. On kill: +1 Bone.", "art": "card_bone_rattle",
	},
	"echo_strike": {
		"name": "Echo Strike", "type": Type.STRIKE, "energy": 1, "blood": 0,
		"damage": 7, "block": 0, "sigils": [Sigil.ECHO],
		"text": "Deal 7. Echo: repeat for 0 if Bone ≥ 1.", "art": "card_echo_strike",
	},
	"ward": {
		"name": "Ward", "type": Type.GUARD, "energy": 1, "blood": 0,
		"damage": 0, "block": 4, "sigils": [Sigil.WARD],
		"text": "Gain 4 Block and 1 Thorns.", "art": "card_ward",
	},
	"offering": {
		"name": "Offering", "type": Type.SKILL, "energy": 0, "blood": 0,
		"damage": 0, "block": 0, "sigils": [],
		"text": "Discard 1: next card costs 1 less.", "art": "card_offering",
	},
	"firebolt": {
		"name": "Firebolt", "type": Type.SPELL, "energy": 1, "blood": 0,
		"damage": 5, "block": 0, "sigils": [Sigil.PIERCE],
		"text": "Deal 5. Pierce: ignores half Block.", "art": "card_firebolt",
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
