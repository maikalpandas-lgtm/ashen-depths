extends Node
## Global run state (autoload).

const Party = preload("res://scripts/party.gd")
const Backpack = preload("res://scripts/items/backpack.gd")
const ItemDB = preload("res://scripts/items/item_db.gd")

## Layout seed for the CURRENT floor (changes every descent).
var current_seed: int = 0
## Fixed for the whole run — floor layouts derive from this + floor_index.
var run_seed: int = 0
var floor_index: int = 1
var gold: int = 0
## The three heroes of this run. Combat draws its deck from here.
var party: Party = null
## Shared party backpack 5×4 (DESIGN §8).
var backpack: Backpack = null

## XP / levels — Layer 2 fires when pending_level_ups > 0
var xp: int = 0
var level: int = 1
var pending_level_ups: int = 0
## Post-combat item offers waiting after card draft / level-up
var pending_loot: Array = []
## "floor" shop pending before advance_floor
var pending_floor_shop: bool = false

signal dungeon_ready(start_position: Vector3)
signal encounter_started(encounter_id: String)
signal combat_requested(pack: Array, source: Node)
signal chest_opened(gold_amount: int)
signal draft_requested(kill_gold: int)
signal draft_finished(hint: String)
signal level_up_requested()
signal level_up_finished(hint: String)
signal loot_requested(offers: Array)
signal loot_finished(hint: String)
signal shop_requested(mode: String)  ## "floor" | "merchant"
signal shop_finished(mode: String)
signal floor_changed(new_floor: int)
signal defeat_finished(choice: String)


func _ready() -> void:
	if party == null:
		party = Party.new()
	if backpack == null:
		backpack = Backpack.new()


func new_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		seed_value = randi()
	run_seed = seed_value
	current_seed = seed_value
	floor_index = 1
	gold = 0
	xp = 0
	level = 1
	pending_level_ups = 0
	pending_loot.clear()
	pending_floor_shop = false
	party = Party.new()
	backpack = Backpack.new()


func xp_to_next_level() -> int:
	# Phase 5: slightly faster early levels so Layer 2 shows up in a demo run
	return 12 + (level - 1) * 8


func grant_combat_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var gained := 0
	while xp >= xp_to_next_level() and gained < 3:
		xp -= xp_to_next_level()
		level += 1
		pending_level_ups += 1
		gained += 1
	if gained > 0:
		print("[Run] level → %d (pending picks %d, xp %d/%d)" % [
			level, pending_level_ups, xp, xp_to_next_level()])
	return gained


func consume_level_up() -> bool:
	if pending_level_ups <= 0:
		return false
	pending_level_ups -= 1
	return true


## Queue loot for after card draft / level-up (DESIGN §8.3 order).
func queue_combat_loot(pack_kind: String, seed_value: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else (current_seed + floor_index * 17 + Time.get_ticks_msec())
	pending_loot = ItemDB.roll_loot(pack_kind, rng)
	# Floor boss always gets a seal shard auto-offer as "Layer 3 light"
	if pack_kind == "floor_boss":
		var has_shard := false
		for o in pending_loot:
			if str(o.get("id", "")) == "seal_shard":
				has_shard = true
		if not has_shard:
			pending_loot.append({"id": "seal_shard", "pick": true, "auto_shard": true})


## Continue the post-combat reward chain: level-up → loot → done.
func continue_reward_chain(hint: String = "") -> void:
	if pending_level_ups > 0:
		level_up_requested.emit()
		return
	if not pending_loot.is_empty():
		loot_requested.emit(pending_loot.duplicate(true))
		return
	draft_finished.emit(hint)


func clear_pending_loot() -> void:
	pending_loot.clear()


## Apply gold mult from backpack (coin pouch etc.).
func award_combat_gold(base: int) -> int:
	var amount := base
	if backpack:
		var mods: Dictionary = backpack.compute_mods()
		var pct: float = float(mods.get("gold_pct", 0.0))
		if pct > 0.0:
			amount = int(round(float(base) * (1.0 + pct)))
	gold += amount
	return amount


## Player stepped on EXIT — open floor shop first, then advance.
func request_exit_shop() -> void:
	if pending_floor_shop:
		return
	pending_floor_shop = true
	shop_requested.emit("floor")


func request_merchant_shop() -> void:
	shop_requested.emit("merchant")


## Called by shop when floor mode closes (buy or leave).
func finish_floor_shop() -> void:
	pending_floor_shop = false
	advance_floor()
	shop_finished.emit("floor")


func advance_floor() -> void:
	floor_index += 1
	if party:
		for m in party.members:
			var max_hp: int = int(m["max_hp"])
			var hp: int = int(m["hp"])
			var miss: int = maxi(0, max_hp - hp)
			m["hp"] = hp + miss / 4
	current_seed = _seed_for_floor(floor_index)
	print("[Run] floor → %d (seed %d)" % [floor_index, current_seed])
	floor_changed.emit(floor_index)


func _seed_for_floor(floor_i: int) -> int:
	var base: int = run_seed if run_seed != 0 else current_seed
	if base == 0:
		base = 1
	return absi(base * 1664525 + floor_i * 1013904223)


func backpack_mods() -> Dictionary:
	if backpack == null:
		return {}
	return backpack.compute_mods()
