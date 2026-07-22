extends RefCounted
## The three heroes of a run and their starter decks — DESIGN.md §5, §7.5.
##
## MVP party is fixed (Kael / Lyra / Sera); drafting 3 from the pool of 8 comes
## later. HP deliberately sums to 88, which is the party HP the HUD already
## shows, so the bar keeps meaning the same thing.

const CardDB = preload("res://scripts/cards/card_db.gd")
const Deck = preload("res://scripts/cards/deck.gd")

const HEROES := {
	"kael": {
		"name": "Каэль", "archetype": "Паладин", "role": "Танк / броня",
		"hp": 34, "portrait": "hero_kael", "colour": Color(0.85, 0.72, 0.35),
		"deck": [
			"slice", "slice", "slice",
			"block", "block", "block",
			"ward", "ward",
			"hack",
		],
	},
	"lyra": {
		"name": "Лира", "archetype": "Охотница", "role": "Урон / ловушки",
		"hp": 30, "portrait": "hero_lyra", "colour": Color(0.45, 0.78, 0.5),
		"deck": [
			"slice", "slice", "slice",
			"cleave_cut", "cleave_cut",
			"block", "block",
			"echo_strike",
			"offering",
		],
	},
	"sera": {
		"name": "Сера", "archetype": "Огненный маг", "role": "По площади",
		"hp": 24, "portrait": "hero_sera", "colour": Color(0.9, 0.45, 0.3),
		"deck": [
			"firebolt", "firebolt", "firebolt",
			"slice", "slice",
			"block", "block",
			"blood_lash",
			"bone_rattle",
		],
	},
	# --- славянский набор (добавлен, не замена) ---
	"vityaz": {
		"name": "Витязь", "archetype": "Богатырь", "role": "Танк / броня",
		"hp": 36, "portrait": "hero_vityaz", "colour": Color(0.86, 0.3, 0.26),
		"deck": [
			"slice", "slice", "slice",
			"block", "block", "block",
			"ward", "ward",
			"hack",
		],
	},
	"polyanitsa": {
		"name": "Поляница", "archetype": "Поляница", "role": "Урон / ловушки",
		"hp": 28, "portrait": "hero_polyanitsa", "colour": Color(0.55, 0.72, 0.35),
		"deck": [
			"slice", "slice", "slice",
			"cleave_cut", "cleave_cut",
			"block", "block",
			"echo_strike",
			"offering",
		],
	},
	"volhv": {
		"name": "Волхв", "archetype": "Ведун", "role": "Чары",
		"hp": 24, "portrait": "hero_volhv", "colour": Color(0.45, 0.6, 0.95),
		"deck": [
			"firebolt", "firebolt", "firebolt",
			"slice", "slice",
			"block", "block",
			"blood_lash",
			"bone_rattle",
		],
	},
}

## Славянская тройка — основная. Старая (kael/lyra/sera) осталась в пуле:
## драфт 3 из пула появится позже, DESIGN §5.
const MVP_PARTY := ["vityaz", "polyanitsa", "volhv"]
const OLD_PARTY := ["kael", "lyra", "sera"]

var members: Array = []  ## [{id, name, hp, max_hp, ...}]


func _init(hero_ids: Array = MVP_PARTY) -> void:
	for id in hero_ids:
		if not HEROES.has(id):
			push_error("[Party] unknown hero id: %s" % id)
			continue
		var def: Dictionary = (HEROES[id] as Dictionary).duplicate(true)
		def["id"] = id
		def["max_hp"] = def["hp"]
		members.append(def)


func total_hp() -> int:
	var sum := 0
	for m in members:
		sum += int(m["hp"])
	return sum


func total_max_hp() -> int:
	var sum := 0
	for m in members:
		sum += int(m["max_hp"])
	return sum


func alive_members() -> Array:
	return members.filter(func(m): return int(m["hp"]) > 0)


## Every hero's starter deck merged into ONE combat deck, each card tagged with
## its owner (§7.5 MVP decision). Cards are NOT resolved to definitions here —
## a deck stores ids so it stays cheap to copy and save.
func build_combat_deck(seed_value: int) -> Deck:
	var entries: Array = []
	for m in members:
		for card_id in m["deck"]:
			if not CardDB.has_card(card_id):
				push_error("[Party] %s has unknown card: %s" % [m["id"], card_id])
				continue
			entries.append({"card": card_id, "owner": m["id"]})
	var deck: Deck = Deck.new(entries, seed_value)
	deck.shuffle()
	return deck


## Permanently add a drafted card to a hero's personal deck (post-combat layer 1).
func add_card(owner_id: String, card_id: String) -> bool:
	if not CardDB.has_card(card_id):
		push_error("[Party] add_card unknown: %s" % card_id)
		return false
	for m in members:
		if str(m["id"]) != owner_id:
			continue
		var deck: Array = m["deck"]
		deck.append(card_id)
		m["deck"] = deck
		return true
	push_error("[Party] add_card unknown owner: %s" % owner_id)
	return false


func deck_size() -> int:
	var n := 0
	for m in members:
		n += (m["deck"] as Array).size()
	return n
