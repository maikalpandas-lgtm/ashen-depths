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
const Statuses = preload("res://scripts/combat/statuses.gd")
const FloorScale = preload("res://scripts/combat/floor_scale.gd")
const ForageDB = preload("res://scripts/items/forage_db.gd")

const START_ENERGY := 3  ## §7.4 — ⚡3 at the start of the player's turn
const DRAW_PER_TURN := 5  ## §7.5

## Critical hits. Rolled per card, not per enemy, so a Cleave crits on both
## halves — a card either lands clean or it does not.
const CRIT_CHANCE := 0.18
const CRIT_MULT := 1.75

enum Phase { PLAYER, ENEMY, WON, LOST }

var party: RefCounted = null
var deck: Deck = null
var enemies: Array = []  ## [{id, name, hp, max_hp, block, intent}]
var energy: int = 0
var party_block: int = 0
var thorns: int = 0
## Status bag for the hero. Enemies carry their own under e["status"].
var party_status: Dictionary = {}
var bones: int = 0  ## §7.3 — spent by Echo
var turn: int = 0
var phase: int = Phase.PLAYER
var log_lines: Array = []
## What just happened, for the UI to animate. Rules stay node-free; the overlay
## reads this instead of guessing from log text.
## kind: "enemy_hit" | "enemy_died" | "enemy_attack" | "enemy_block"
##     | "status_applied" | "status_tick"
var events: Array = []

var _rng := RandomNumberGenerator.new()
var _discount: int = 0  ## Offering: next card costs 1 less
## Backpack mods snapshot (DESIGN §8) — frozen at combat start
var mods: Dictionary = {}
var _first_strike_used: bool = false
## Damage the last _hit_enemy spent past the target's final hit point.
var last_overkill: int = 0
## Depth this fight happens at, snapshotted at the start (GameState may change
## under a long fight, and a monster must not grow mid-combat).
var floor_index: int = 1
## Trophies earned this fight, banked into GameState when it is won — a fight
## the party loses should not pay out.
var trophies_taken: Dictionary = {}
var _bones_from_items: int = 0  ## bone_charm cap 3/fight


func _init(party_ref: RefCounted, pack: Array, seed_value: int) -> void:
	party = party_ref
	_rng.seed = seed_value
	deck = party.build_combat_deck(seed_value)
	mods = _read_backpack_mods()
	floor_index = _read_floor_index()
	for enemy_id in pack:
		var def: Dictionary = EnemySprites.ENEMIES.get(enemy_id, EnemySprites.ENEMIES["grub"])
		# Scaled by depth. Without this the run got EASIER the deeper it went:
		# stats were flat while the hero levelled, drafted and geared up.
		var hp := FloorScale.scale_hp(int(def["hp"]), floor_index)
		enemies.append({
			"id": enemy_id,
			"name": def["name"],
			"hp": hp,
			"max_hp": hp,
			"block": 0,
			"intent": {},
			"status": {},
		})
	# Bones foraged in the corridor come into the fight (фаза E)
	var gs = _game_state()
	if gs != null and int(gs.get("bones_carried") or 0) > 0:
		bones += int(gs.bones_carried)
		gs.bones_carried = 0
		_log("кости из похода: %d" % bones)
	begin_player_turn()


func _read_floor_index() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var gs = tree.root.get_node_or_null("GameState")
		if gs != null and gs.get("floor_index") != null:
			return maxi(1, int(gs.floor_index))
	return 1


func _read_backpack_mods() -> Dictionary:
	# GameState is an autoload in the real game; headless tests may lack it.
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var gs = tree.root.get_node_or_null("GameState")
		if gs != null and gs.get("backpack") != null:
			var bp = gs.backpack
			if bp != null and bp.has_method("compute_mods"):
				return bp.compute_mods()
	return {}


# --------------------------------------------------------------------- turns

func begin_player_turn() -> void:
	turn += 1
	phase = Phase.PLAYER
	energy = START_ENERGY + int(mods.get("energy_each_turn", 0))
	if turn == 1:
		energy += int(mods.get("energy_first_turn", 0))
		party_block = int(mods.get("start_block", 0))
		_first_strike_used = false
		_bones_from_items = 0
		if party_block > 0:
			_log("рюкзак: +%d брони" % party_block)
	else:
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
	# Hero's statuses wear off at the end of the HERO's turn, before the enemies
	# swing — so Отрава cannot kill you after you already survived their round.
	_tick_party_status()
	if _party_alive_hp() <= 0:
		phase = Phase.LOST
		_log("дружина пала")
		return log_lines.slice(before)
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
				var swing := Statuses.outgoing(e["status"], int(intent["value"]))
				# Each hit lands separately, so armour is chewed through one
				# blow at a time — that is the whole point of a flurry.
				for _h in range(maxi(1, int(intent.get("hits", 1)))):
					if _party_alive_hp() <= 0:
						break
					_event("enemy_attack", enemies.find(e), swing)
					_hit_party(swing, e)
	_tick_enemy_status()
	_check_victory()
	if phase == Phase.WON:
		return log_lines.slice(before)
	if _party_alive_hp() <= 0:
		phase = Phase.LOST
		_log("дружина пала")
		return log_lines.slice(before)
	begin_player_turn()
	return log_lines.slice(before)


func _tick_party_status() -> void:
	if party_status.is_empty():
		return
	var dot := Statuses.tick(party_status)
	if dot > 0:
		_event("status_tick", -1, dot)
		_log("отрава жжёт: ❤−%d" % dot)
		# Straight to HP: poison is the thing armour does not stop
		_damage_party(dot)


func _tick_enemy_status() -> void:
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		if int(e["hp"]) <= 0:
			continue
		var bag: Dictionary = e["status"]
		if bag.is_empty():
			continue
		var dot := Statuses.tick(bag)
		if dot <= 0:
			continue
		e["hp"] = maxi(0, int(e["hp"]) - dot)
		_event("status_tick", i, dot)
		if int(e["hp"]) <= 0:
			_event("enemy_died", i)
			_log("%s не пережил отраву" % e["name"])
		else:
			_log("%s травится на %d" % [e["name"], dot])


## Hang a status on an enemy (or the hero when index < 0).
func apply_status(index: int, id: String, amount: int) -> void:
	if not Statuses.exists(id) or amount == 0:
		return
	if index < 0:
		Statuses.apply(party_status, id, amount)
		_event("status_applied", -1, amount, false, id)
		return
	var e := _enemy_at(index)
	if e.is_empty() or int(e["hp"]) <= 0:
		return
	Statuses.apply(e["status"], id, amount)
	_event("status_applied", index, amount, false, id)


## Intents carry a HIT COUNT, not just a number.
##
## `3x2` is a different problem from `6x1`: each hit is soaked by armour
## separately, so block is worth far less against a flurry. Showing one summed
## number hid that entirely — the player could not tell why their 6 armour
## evaporated against a "6" attack.
func _roll_intent(e: Dictionary) -> Dictionary:
	# Brutes hit hard and rarely guard; grubs chip; shades are in between
	# Floor: ~max_hp/3 so a pack of 3 grubs can actually chip through block
	# max_hp is already scaled, so the intent inherits depth through it; the
	# extra damage multiplier is applied on top and kept gentler than HP.
	var base: int = FloorScale.scale_damage(maxi(3, int(e["max_hp"]) / 3), floor_index)
	if _rng.randf() < 0.15:
		return {"type": "block", "value": base, "hits": 1}
	# Small, fast things flurry; heavy things land one big blow. Tied to size so
	# it reads off the sprite rather than being a surprise.
	var big: bool = int(e["max_hp"]) >= 20
	if not big and _rng.randf() < 0.35:
		var per: int = maxi(2, base / 2)
		return {"type": "attack", "value": per, "hits": 2}
	return {"type": "attack", "value": base + _rng.randi_range(0, 3), "hits": 1}


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
	var blood_cost := _blood_cost(card)
	if blood_cost > 0 and _party_alive_hp() <= blood_cost:
		return false
	return true


func _blood_cost(card: Dictionary) -> int:
	var b := int(card.get("blood", 0))
	if b <= 0:
		return 0
	var disc: int = int(mods.get("blood_discount", 0))
	return maxi(1, b - disc)


## Play hand[hand_index] at enemies[target]. Returns true if it resolved.
func play_card(hand_index: int, target: int) -> bool:
	if not can_play(hand_index):
		return false
	events.clear()
	var card := _card_at(hand_index)
	var sigils: Array = card["sigils"]

	energy -= card_cost(hand_index)
	_discount = 0
	var blood_cost := _blood_cost(card)
	if blood_cost > 0:
		_damage_party(blood_cost)
		_log("отдано %d HP" % blood_cost)

	if int(card["block"]) > 0:
		party_block += int(card["block"])
		_log("+%d брони" % int(card["block"]))
		if sigils.has(CardDB.Sigil.WARD):
			thorns += 1
			_log("+1 шип")

	if int(card["damage"]) > 0:
		_apply_item_damage_mods(card)
		_resolve_damage(card, target)
		# Echo repeats for free while a Bone is available (§7.3)
		if sigils.has(CardDB.Sigil.ECHO) and bones > 0:
			bones -= 1
			_log("эхо (−1 кость)")
			_resolve_damage(card, target)

	if sigils.has(CardDB.Sigil.DRAW):
		var got := deck.draw(1)
		if got > 0:
			_log("+%d карта" % got)
	if sigils.has(CardDB.Sigil.RAGE):
		apply_status(-1, "rage", 1)
		_log("+1 ярость")
	# SANGUINE: paying in blood feeds the swing that follows
	if sigils.has(CardDB.Sigil.SANGUINE) and blood_cost > 0:
		apply_status(-1, "rage", 1)

	# Match by id — display name is localised (Треба), not "Offering"
	var card_id: String = str(deck.hand[hand_index]["card"])
	if card_id == "offering":
		_discount = 1
		_log("следующая карта дешевле на 1")

	# Exhaust must be the LAST thing: drawing or discarding first would shift
	# hand_index out from under it and burn the wrong card.
	if sigils.has(CardDB.Sigil.EXHAUST):
		deck.exhaust_at(hand_index)
		_log("карта сгорела")
	else:
		deck.discard_at(hand_index)
	_check_victory()
	return true


func _apply_item_damage_mods(card: Dictionary) -> void:
	# Mutates the resolved copy only (not CardDB)
	var dmg := int(card["damage"])
	var ctype: int = int(card.get("type", -1))
	if ctype == CardDB.Type.SPELL:
		dmg += int(mods.get("spell_dmg", 0))
	else:
		dmg += int(mods.get("strike_dmg", 0))
	if not _first_strike_used and int(mods.get("first_strike_bonus", 0)) > 0:
		dmg += int(mods["first_strike_bonus"])
		_first_strike_used = true
	card["damage"] = dmg


func _resolve_damage(card: Dictionary, target: int) -> void:
	var sigils: Array = card["sigils"]
	var amount := int(card["damage"])
	var e := _enemy_at(target)
	if e.is_empty():
		return

	if sigils.has(CardDB.Sigil.SHARP) and int(e["block"]) > 0:
		amount += 2
	# Ярость / Немощь on the hero shape everything they throw
	amount = Statuses.outgoing(party_status, amount)
	# Rolled once per card: a Cleave should land clean on both halves or not at
	# all, rather than critting one target and fizzling on its neighbour.
	var crit := _rng.randf() < crit_chance()
	if crit:
		amount = int(round(float(amount) * CRIT_MULT))
	var ignore_block: bool = sigils.has(CardDB.Sigil.PIERCE)
	var dealt := _hit_enemy(target, amount, ignore_block, crit)

	if sigils.has(CardDB.Sigil.CLEAVE):
		var neighbour := target + 1 if target + 1 < enemies.size() else target - 1
		if neighbour >= 0 and neighbour != target:
			_hit_enemy(neighbour, int(amount * 0.5), ignore_block, crit)

	# Leftover: the swing carries on into the next living body instead of being
	# wasted on a corpse. This is what makes a big hit on a nearly-dead grub a
	# real choice rather than an obvious waste.
	if sigils.has(CardDB.Sigil.LEFTOVER) and last_overkill > 0:
		var spill := last_overkill
		var next_alive := _next_living(target)
		if next_alive >= 0:
			_log("перенос: %d" % spill)
			_hit_enemy(next_alive, spill, ignore_block, crit)
	# Overkill: the same wasted damage becomes armour instead
	elif sigils.has(CardDB.Sigil.OVERKILL) and last_overkill > 0:
		party_block += last_overkill
		_log("перебор в броню: +%d" % last_overkill)

	# SWEEP hits the WHOLE row for half — Cleave's big brother, and the reason a
	# pack of three grubs is a different problem from one brute.
	if sigils.has(CardDB.Sigil.SWEEP):
		for i in range(enemies.size()):
			if i != target:
				_hit_enemy(i, int(amount * 0.5), ignore_block, crit)

	if sigils.has(CardDB.Sigil.DRAIN) and dealt > 0:
		_heal_party(int(dealt * 0.5))
	# Statuses ride on the hit, so they only land if the card connected
	if dealt > 0 or int(e["hp"]) <= 0:
		if sigils.has(CardDB.Sigil.FRAIL_HIT):
			apply_status(target, "frail", 2)
		if sigils.has(CardDB.Sigil.POISON_HIT):
			apply_status(target, "poison", 3)
		if sigils.has(CardDB.Sigil.WEAKEN):
			apply_status(target, "weak", 2)
	if sigils.has(CardDB.Sigil.BONE) and int(e["hp"]) <= 0:
		bones += 1
		_log("+1 кость")
	# Bone charm — free bone on kill, cap 3 from items this fight
	if int(e["hp"]) <= 0 and int(mods.get("bone_on_kill", 0)) > 0 and _bones_from_items < 3:
		bones += int(mods["bone_on_kill"])
		_bones_from_items += int(mods["bone_on_kill"])
		_log("оберег: +кость")


## Next living enemy after `from`, wrapping to the start. -1 if none is left.
func _next_living(from: int) -> int:
	for step in range(1, enemies.size()):
		var i: int = (from + step) % enemies.size()
		if int(enemies[i]["hp"]) > 0:
			return i
	return -1


## A body part from a kill (фаза E). Not every kill: a guaranteed drop is just
## a slower gold trickle, while a chance makes the shop trip feel earned.
func _take_trophy(e: Dictionary) -> void:
	var def: Dictionary = EnemySprites.ENEMIES.get(str(e.get("id", "")), {})
	var realm := str(def.get("realm", "mine"))
	var chance: float = 0.85 if bool(def.get("boss", false)) else 0.3
	if _rng.randf() >= chance:
		return
	var id := ForageDB.trophy_for_realm(realm)
	trophies_taken[id] = int(trophies_taken.get(id, 0)) + 1
	_event("trophy", enemies.find(e), 1, false, id)
	_log("трофей: %s" % ForageDB.trophy(id).get("name", id))


## Spend a carried consumable. Index is into GameState.consumables; the state
## object owns the list, so combat asks rather than holding its own copy.
func use_consumable(index: int) -> bool:
	if phase != Phase.PLAYER:
		return false
	var gs = _game_state()
	if gs == null:
		return false
	var def: Dictionary = gs.use_consumable(index)
	if def.is_empty():
		return false
	events.clear()
	match str(def.get("effect", "")):
		"heal":
			_heal_party(int(def.get("value", 0)))
			_log("%s: +%d HP" % [def.get("name", "?"), int(def.get("value", 0))])
		"status":
			apply_status(-1, str(def.get("status", "rage")), int(def.get("value", 1)))
			_log("%s выпит" % def.get("name", "?"))
		"cleanse":
			# Only the harmful ones — a cleanse that stripped Ярость would be a
			# trap disguised as a cure.
			Statuses.apply(party_status, "poison", -99)
			Statuses.apply(party_status, "frail", -99)
			_log("%s: хвори сняты" % def.get("name", "?"))
	_event("consumable", -1, 0)
	return true


func _game_state():
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("GameState")
	return null


func crit_chance() -> float:
	return clampf(CRIT_CHANCE + float(mods.get("crit_chance", 0.0)), 0.0, 0.95)


func _hit_enemy(index: int, amount: int, ignore_block: bool, crit: bool = false) -> int:
	var e := _enemy_at(index)
	if e.is_empty() or int(e["hp"]) <= 0:
		return 0
	# Порча multiplies BEFORE armour soaks: the blow lands harder, then the
	# shield takes what it can. The other order lets armour eat the debuff.
	var left := Statuses.incoming(e["status"], amount)
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
	# What the blow spent PAST the last hit point. Leftover and Overkill both
	# need this, and it is only knowable here, before hp is clamped to zero.
	last_overkill = maxi(0, left - int(e["hp"]))
	e["hp"] = maxi(0, int(e["hp"]) - left)
	_event("enemy_hit", index, left, crit)
	if was_alive and int(e["hp"]) <= 0:
		_event("enemy_died", index)
		_log("%s убит!" % e["name"])
		_take_trophy(e)
	else:
		_log("%s%s получает %d (%d/%d)" % [
			"КРИТ! " if crit else "", e["name"], left, e["hp"], e["max_hp"]])
	return left


# --------------------------------------------------------------------- party

func _hit_party(amount: int, source: Dictionary) -> void:
	var left := Statuses.incoming(party_status, amount)
	var absorbed: int = mini(party_block, left)
	party_block -= absorbed
	left -= absorbed
	if left > 0:
		_damage_party(left)
	if absorbed > 0 and left > 0:
		_log("%s бьёт: 🛡−%d, ❤−%d" % [source["name"], absorbed, left])
	elif absorbed > 0:
		_log("%s бьёт: всё в броню (🛡−%d)" % [source["name"], absorbed])
	else:
		_log("%s бьёт: ❤−%d" % [source["name"], left])
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
		_bank_trophies()


## Trophies only pay out on a WIN. Banking them per kill would let a party that
## wipes on the last enemy still walk away with the pouch.
func _bank_trophies() -> void:
	if trophies_taken.is_empty():
		return
	var gs = _game_state()
	if gs != null and gs.has_method("add_trophy"):
		for id in trophies_taken.keys():
			gs.add_trophy(str(id), int(trophies_taken[id]))
	trophies_taken.clear()


func _card_at(hand_index: int) -> Dictionary:
	if hand_index < 0 or hand_index >= deck.hand.size():
		return {}
	# Honour permanent upgrades (Layer 2) carried on the combat deck entry
	return CardDB.resolve_entry(deck.hand[hand_index])


func _enemy_at(index: int) -> Dictionary:
	if index < 0 or index >= enemies.size():
		return {}
	return enemies[index]


## `index` < 0 means the hero rather than an enemy slot.
func _event(kind: String, index: int, amount: int = 0, crit: bool = false,
		status: String = "") -> void:
	events.append({
		"kind": kind, "index": index, "amount": amount, "crit": crit,
		"status": status,
	})


func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 60:
		log_lines.pop_front()
