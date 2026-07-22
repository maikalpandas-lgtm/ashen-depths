extends RefCounted
## Card combat, rules only — no nodes, no drawing. DESIGN.md §7.
##
## Kept free of the scene tree on purpose: this is the one part of combat that
## can be verified without looking at a frame, and tests/run_tests.gd does.
##
## No board (§7.0): cards are played straight from hand at a target. Enemies
## stand in a row and are addressed by index.

const CardDB = preload("res://scripts/cards/card_db.gd")
const Deck = preload("res://scripts/cards/deck.gd")
const EnemySprites = preload("res://scripts/enemy_sprites.gd")

const START_ENERGY := 3  ## §7.4 — ⚡3 at the start of the player's turn
const DRAW_PER_TURN := 5  ## §7.5

enum Phase { PLAYER, ENEMY, WON, LOST }

var party: RefCounted = null
var deck: Deck = null
var enemies: Array = []  ## [{id, name, hp, max_hp, block, intent}]
var energy: int = 0
var party_block: int = 0
var thorns: int = 0
var bones: int = 0  ## §7.3 — spent by Echo
var turn: int = 0
var phase: int = Phase.PLAYER
var log_lines: Array = []
## What just happened, for the UI to animate. Rules stay node-free; the overlay
## reads this instead of guessing from log text.
## kind: "enemy_hit" | "enemy_died" | "enemy_attack" | "enemy_block"
var events: Array = []

var _rng := RandomNumberGenerator.new()
var _discount: int = 0  ## Offering: next card costs 1 less


func _init(party_ref: RefCounted, pack: Array, seed_value: int) -> void:
	party = party_ref
	_rng.seed = seed_value
	deck = party.build_combat_deck(seed_value)
	for enemy_id in pack:
		var def: Dictionary = EnemySprites.ENEMIES.get(enemy_id, EnemySprites.ENEMIES["grub"])
		enemies.append({
			"id": enemy_id,
			"name": def["name"],
			"hp": int(def["hp"]),
			"max_hp": int(def["hp"]),
			"block": 0,
			"intent": {},
		})
	begin_player_turn()


# --------------------------------------------------------------------- turns

func begin_player_turn() -> void:
	turn += 1
	phase = Phase.PLAYER
	energy = START_ENERGY
	party_block = 0
	_discount = 0
	deck.discard_hand()
	deck.draw(DRAW_PER_TURN)
	for e in enemies:
		e["block"] = 0
		e["intent"] = _roll_intent(e)
	_log("ход %d" % turn)


## Enemies act, then the next player turn starts. Returns the lines logged.
func end_turn() -> Array:
	if phase != Phase.PLAYER:
		return []
	phase = Phase.ENEMY
	events.clear()
	var before := log_lines.size()
	for e in enemies:
		if int(e["hp"]) <= 0:
			continue
		var intent: Dictionary = e["intent"]
		match intent.get("type", "attack"):
			"block":
				e["block"] = int(e["block"]) + int(intent["value"])
				_event("enemy_block", enemies.find(e))
				_log("%s закрывается (+%d брони)" % [e["name"], intent["value"]])
			_:
				_event("enemy_attack", enemies.find(e), int(intent["value"]))
				_hit_party(int(intent["value"]), e)
	if _party_alive_hp() <= 0:
		phase = Phase.LOST
		_log("дружина пала")
		return log_lines.slice(before)
	begin_player_turn()
	return log_lines.slice(before)


func _roll_intent(e: Dictionary) -> Dictionary:
	# Brutes hit hard and rarely guard; grubs chip; shades are in between
	var base: int = maxi(2, int(e["max_hp"]) / 4)
	if _rng.randf() < 0.2:
		return {"type": "block", "value": base}
	return {"type": "attack", "value": base + _rng.randi_range(0, 2)}


# --------------------------------------------------------------------- cards

func card_cost(hand_index: int) -> int:
	var card := _card_at(hand_index)
	if card.is_empty():
		return 99
	return maxi(0, int(card["energy"]) - _discount)


func can_play(hand_index: int) -> bool:
	if phase != Phase.PLAYER:
		return false
	var card := _card_at(hand_index)
	if card.is_empty():
		return false
	if card_cost(hand_index) > energy:
		return false
	# Blood cards are paid in HP, and must not be able to kill the party (§7.4)
	if int(card["blood"]) > 0 and _party_alive_hp() <= int(card["blood"]):
		return false
	return true


## Play hand[hand_index] at enemies[target]. Returns true if it resolved.
func play_card(hand_index: int, target: int) -> bool:
	if not can_play(hand_index):
		return false
	events.clear()
	var card := _card_at(hand_index)
	var sigils: Array = card["sigils"]

	energy -= card_cost(hand_index)
	_discount = 0
	if int(card["blood"]) > 0:
		_damage_party(int(card["blood"]))
		_log("отдано %d HP" % int(card["blood"]))

	if int(card["block"]) > 0:
		party_block += int(card["block"])
		_log("+%d брони" % int(card["block"]))
		if sigils.has(CardDB.Sigil.WARD):
			thorns += 1
			_log("+1 шип")

	if int(card["damage"]) > 0:
		_resolve_damage(card, target)
		# Echo repeats for free while a Bone is available (§7.3)
		if sigils.has(CardDB.Sigil.ECHO) and bones > 0:
			bones -= 1
			_log("эхо (−1 кость)")
			_resolve_damage(card, target)

	# Match by id — display name is localised (Треба), not "Offering"
	var card_id: String = str(deck.hand[hand_index]["card"])
	if card_id == "offering":
		_discount = 1
		_log("следующая карта дешевле на 1")

	deck.discard_at(hand_index)
	_check_victory()
	return true


func _resolve_damage(card: Dictionary, target: int) -> void:
	var sigils: Array = card["sigils"]
	var amount := int(card["damage"])
	var e := _enemy_at(target)
	if e.is_empty():
		return

	if sigils.has(CardDB.Sigil.SHARP) and int(e["block"]) > 0:
		amount += 2
	var ignore_block: bool = sigils.has(CardDB.Sigil.PIERCE)
	var dealt := _hit_enemy(target, amount, ignore_block)

	if sigils.has(CardDB.Sigil.CLEAVE):
		var neighbour := target + 1 if target + 1 < enemies.size() else target - 1
		if neighbour >= 0 and neighbour != target:
			_hit_enemy(neighbour, int(amount * 0.5), ignore_block)

	if sigils.has(CardDB.Sigil.DRAIN) and dealt > 0:
		_heal_party(int(dealt * 0.5))
	if sigils.has(CardDB.Sigil.BONE) and int(e["hp"]) <= 0:
		bones += 1
		_log("+1 кость")


func _hit_enemy(index: int, amount: int, ignore_block: bool) -> int:
	var e := _enemy_at(index)
	if e.is_empty() or int(e["hp"]) <= 0:
		return 0
	var left := amount
	if not ignore_block:
		var absorbed: int = mini(int(e["block"]), left)
		e["block"] = int(e["block"]) - absorbed
		left -= absorbed
	else:
		# Pierce ignores half the block (§7.3)
		var half: int = int(e["block"]) / 2
		var absorbed2: int = mini(half, left)
		e["block"] = int(e["block"]) - absorbed2
		left -= absorbed2
	left = maxi(0, left)
	var was_alive := int(e["hp"]) > 0
	e["hp"] = maxi(0, int(e["hp"]) - left)
	_event("enemy_hit", index, left)
	if was_alive and int(e["hp"]) <= 0:
		_event("enemy_died", index)
	_log("%s получает %d (%d/%d)" % [e["name"], left, e["hp"], e["max_hp"]])
	return left


# --------------------------------------------------------------------- party

func _hit_party(amount: int, source: Dictionary) -> void:
	var left := amount
	var absorbed: int = mini(party_block, left)
	party_block -= absorbed
	left -= absorbed
	if left > 0:
		_damage_party(left)
	_log("%s бьёт на %d" % [source["name"], left])
	if thorns > 0 and int(source["hp"]) > 0:
		source["hp"] = maxi(0, int(source["hp"]) - thorns)
		_log("шипы ранят %s на %d" % [source["name"], thorns])
		_check_victory()


## Damage lands on the front hero — party HP is one pool visually, but a downed
## hero has to actually drop out (§4.3).
func _damage_party(amount: int) -> void:
	var left := amount
	for m in party.members:
		if left <= 0:
			break
		if int(m["hp"]) <= 0:
			continue
		var taken: int = mini(int(m["hp"]), left)
		m["hp"] = int(m["hp"]) - taken
		left -= taken


func _heal_party(amount: int) -> void:
	var left := amount
	for m in party.members:
		if left <= 0:
			break
		var room: int = int(m["max_hp"]) - int(m["hp"])
		if room <= 0:
			continue
		var given: int = mini(room, left)
		m["hp"] = int(m["hp"]) + given
		left -= given
	_log("дружина лечится на %d" % (amount - left))


func _party_alive_hp() -> int:
	var sum := 0
	for m in party.members:
		sum += maxi(0, int(m["hp"]))
	return sum


# -------------------------------------------------------------------- helpers

func alive_enemies() -> Array:
	return enemies.filter(func(e): return int(e["hp"]) > 0)


func _check_victory() -> void:
	if alive_enemies().is_empty() and phase != Phase.LOST:
		phase = Phase.WON
		_log("стая побита")


func _card_at(hand_index: int) -> Dictionary:
	if hand_index < 0 or hand_index >= deck.hand.size():
		return {}
	return CardDB.get_card(deck.hand[hand_index]["card"])


func _enemy_at(index: int) -> Dictionary:
	if index < 0 or index >= enemies.size():
		return {}
	return enemies[index]


func _event(kind: String, index: int, amount: int = 0) -> void:
	events.append({"kind": kind, "index": index, "amount": amount})


func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 60:
		log_lines.pop_front()
