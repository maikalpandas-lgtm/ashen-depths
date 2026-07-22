extends RefCounted
## One combat deck: draw pile → hand → discard, DESIGN.md §7.5.
##
## Entries are Dictionaries {card = <id>, owner = <hero id>} because the MVP
## shuffles all three hero decks into ONE combat deck and tells them apart by
## an owner tag rather than by whose turn it is.
##
## Seeded RNG: a run must replay identically from its seed, so shuffling never
## touches the global RNG.

const HAND_CAP := 10  ## §7.5 — draw stops here rather than burning cards

var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []

var _rng := RandomNumberGenerator.new()


func _init(entries: Array = [], seed_value: int = 0) -> void:
	draw_pile = entries.duplicate()
	_rng.seed = seed_value


func total() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size()


func shuffle() -> void:
	# Fisher-Yates on the seeded RNG — Array.shuffle() would use the global one
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = tmp


## Draws up to `count`, refilling from the discard when the draw pile runs dry.
## Returns how many actually reached the hand — fewer than asked when the hand
## is at cap or the whole deck is already in hand.
func draw(count: int) -> int:
	var drawn := 0
	for _i in range(count):
		if hand.size() >= HAND_CAP:
			break
		if draw_pile.is_empty():
			_recycle_discard()
			if draw_pile.is_empty():
				break  # every card is already in hand
		hand.append(draw_pile.pop_back())
		drawn += 1
	return drawn


## Move one card from hand to discard. Returns false on a bad index.
func discard_at(index: int) -> bool:
	if index < 0 or index >= hand.size():
		return false
	discard_pile.append(hand[index])
	hand.remove_at(index)
	return true


func discard_hand() -> int:
	var n := hand.size()
	for entry in hand:
		discard_pile.append(entry)
	hand.clear()
	return n


## Start-of-combat state: everything back in the draw pile, freshly shuffled.
func reset_for_combat(seed_value: int) -> void:
	for entry in hand:
		draw_pile.append(entry)
	for entry in discard_pile:
		draw_pile.append(entry)
	hand.clear()
	discard_pile.clear()
	_rng.seed = seed_value
	shuffle()


func _recycle_discard() -> void:
	if discard_pile.is_empty():
		return
	draw_pile = discard_pile.duplicate()
	discard_pile.clear()
	shuffle()
