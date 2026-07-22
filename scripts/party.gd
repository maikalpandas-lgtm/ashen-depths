extends RefCounted
## The three heroes of a run and their starter decks — DESIGN.md §5, §7.5.
##
## MVP party is fixed (Kael / Lyra / Sera); drafting 3 from the pool of 8 comes
## later. HP deliberately sums to 88, which is the party HP the HUD already
## shows, so the bar keeps meaning the same thing.
##
## Permanent deck entries are Dictionaries: {card, plus}. `plus` is Layer 2
## upgrade count (+2 dmg / +2 block per level in CardDB.resolve_entry).

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

var members: Array = []  ## [{id, name, hp, max_hp, deck:[{card,plus}], ...}]


func _init(hero_ids: Array = MVP_PARTY) -> void:
	for id in hero_ids:
		if not HEROES.has(id):
			push_error("[Party] unknown hero id: %s" % id)
			continue
		var def: Dictionary = (HEROES[id] as Dictionary).duplicate(true)
		def["id"] = id
		def["max_hp"] = def["hp"]
		var raw: Array = def["deck"]
		var deck: Array = []
		for card_id in raw:
			deck.append({"card": str(card_id), "plus": 0})
		def["deck"] = deck
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
		for entry in m["deck"]:
			var e := _as_entry(entry)
			if not CardDB.has_card(str(e["card"])):
				push_error("[Party] %s has unknown card: %s" % [m["id"], e["card"]])
				continue
			entries.append({
				"card": str(e["card"]),
				"owner": m["id"],
				"plus": int(e.get("plus", 0)),
			})
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
		deck.append({"card": card_id, "plus": 0})
		m["deck"] = deck
		return true
	push_error("[Party] add_card unknown owner: %s" % owner_id)
	return false


## Layer 2: bump plus on one permanent copy. Returns false if index bad.
func upgrade_card(owner_id: String, deck_index: int) -> bool:
	for m in members:
		if str(m["id"]) != owner_id:
			continue
		var deck: Array = m["deck"]
		if deck_index < 0 or deck_index >= deck.size():
			return false
		var e := _as_entry(deck[deck_index])
		e["plus"] = int(e.get("plus", 0)) + 1
		deck[deck_index] = e
		m["deck"] = deck
		return true
	return false


## Random upgrade targets for the level-up screen. Each item:
## {owner, owner_name, colour, deck_index, card, plus, def}
func roll_upgrade_offers(count: int = 3, rng: RandomNumberGenerator = null) -> Array:
	var pool: Array = []
	for m in members:
		var deck: Array = m["deck"]
		for i in range(deck.size()):
			var e := _as_entry(deck[i])
			# Skills with no dmg/block still upgrade for name mark; skip pure 0/0
			var def := CardDB.get_card(str(e["card"]))
			if def.is_empty():
				continue
			if int(def["damage"]) <= 0 and int(def["block"]) <= 0:
				continue
			pool.append({
				"owner": m["id"],
				"owner_name": m["name"],
				"colour": m["colour"],
				"deck_index": i,
				"card": str(e["card"]),
				"plus": int(e.get("plus", 0)),
			})
	if pool.is_empty():
		return []
	if rng:
		# Fisher–Yates with provided rng
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
	else:
		pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func deck_size() -> int:
	var n := 0
	for m in members:
		n += (m["deck"] as Array).size()
	return n


func _as_entry(entry) -> Dictionary:
	if entry is Dictionary:
		return {
			"card": str(entry.get("card", entry.get("id", ""))),
			"plus": int(entry.get("plus", 0)),
		}
	return {"card": str(entry), "plus": 0}
