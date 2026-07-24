extends RefCounted
## Pure maths and grouping for the deck book. No nodes, so a headless test can
## hold it — importing the overlay itself into a test hangs the run (AGENTS.md).

const CardDB = preload("res://scripts/cards/card_db.gd")

const GAP := 8.0
const MIN_CARD := Vector2(104.0, 146.0)
const MAX_CARD := Vector2(150.0, 210.0)
## Chrome above and below the grid: title, hint, filter row, margins.
const CHROME_H := 190.0
## Side margins plus the scrollbar.
const SIDE_PAD := 76.0
## Rows that must be visible without scrolling before cards start shrinking.
const WANT_ROWS := 3

const FILTERS := [
	{"label": "ВСЕ", "type": -1},
	{"label": "УДАР", "type": CardDB.Type.STRIKE},
	{"label": "ЗАЩИТА", "type": CardDB.Type.GUARD},
	{"label": "ПРИЁМ", "type": CardDB.Type.SKILL},
	{"label": "ЧАРЫ", "type": CardDB.Type.SPELL},
	{"label": "КРОВЬ", "type": CardDB.Type.BLOOD},
]


## Card size that fits WANT_ROWS rows in this window.
##
## Computed rather than fixed for the same reason the hero card is
## (hero_card_layout.gd): the old book used a hard 132x185, and on a short
## window the third row was simply cut off with no hint it existed.
static func card_size(viewport: Vector2) -> Vector2:
	var budget: float = maxf(160.0, viewport.y - CHROME_H)
	var per_row: float = (budget - float(WANT_ROWS - 1) * GAP) / float(WANT_ROWS)
	var h: float = clampf(per_row, MIN_CARD.y, MAX_CARD.y)
	# Keep the 132:185 proportion the card art was composed for
	var w: float = h * (MAX_CARD.x / MAX_CARD.y)
	return Vector2(w, h)


## How many cards fit across.
static func columns(viewport: Vector2, card: Vector2) -> int:
	var usable: float = maxf(card.x, viewport.x - SIDE_PAD)
	return maxi(1, int(floor((usable + GAP) / (card.x + GAP))))


## Duplicates collapsed into groups, each keeping ONE real deck index so the
## caller can upgrade that copy.
##
## Grouping key includes `plus`: an upgraded Сеча is not the same card as a
## plain one and must not hide inside its stack.
static func group(cards: Array, filter_type: int = -1) -> Array:
	var order: Array = []
	var by_key := {}
	for i in range(cards.size()):
		var entry = cards[i]
		var def: Dictionary = CardDB.resolve_entry(entry)
		if def.is_empty():
			continue
		if filter_type >= 0 and int(def.get("type", -1)) != filter_type:
			continue
		var key := "%s+%d" % [_id_of(entry), _plus_of(entry)]
		if not by_key.has(key):
			by_key[key] = {"entry": entry, "count": 0, "index": i}
			order.append(key)
		by_key[key]["count"] = int(by_key[key]["count"]) + 1
	var out: Array = []
	for key in order:
		out.append(by_key[key])
	return out


## Only cards with damage or block gain anything from +N (CardDB.resolve_entry
## adds to those two numbers and nothing else), so a pure skill must not offer
## an upgrade that would silently do nothing for 40 gold.
static func upgradeable(def: Dictionary) -> bool:
	if def.is_empty():
		return false
	return int(def.get("damage", 0)) > 0 or int(def.get("block", 0)) > 0


static func _id_of(entry) -> String:
	if entry is Dictionary:
		return str(entry.get("card", entry.get("id", "")))
	return str(entry)


static func _plus_of(entry) -> int:
	if entry is Dictionary:
		return int(entry.get("plus", 0))
	return 0
