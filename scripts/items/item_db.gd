extends RefCounted
## Item catalog — DESIGN.md §8. Backpack Battles style (no auto-battler).
##
## size: Vector2i(w, h) unrotated. 2×1 can rotate to 1×2.
## tags: adjacency keys (blade, whetstone, guard, …).
## base / adj: combat modifier keys (see Backpack.compute_mods).

const ITEMS := {
	"rusty_blade": {
		"name": "Ржавый клинок", "rarity": "common",
		"w": 1, "h": 1, "tags": ["blade"],
		"buy": 22, "sell": 9,
		"text": "Удар +1. +1 у точила",
		"base": {"strike_dmg": 1},
		"adj": {"need": "whetstone", "strike_dmg": 1},
	},
	"whetstone": {
		"name": "Точило", "rarity": "common",
		"w": 1, "h": 1, "tags": ["whetstone"],
		"buy": 18, "sell": 7,
		"text": "Сосед-клинок сильнее",
		"base": {},
		"adj": {},
	},
	"shield_shard": {
		"name": "Осколок щита", "rarity": "common",
		"w": 2, "h": 1, "tags": ["guard"],
		"buy": 28, "sell": 12,
		"text": "Старт боя +4 брони. +2 у охраны",
		"base": {"start_block": 4},
		"adj": {"need": "guard", "start_block": 2},
	},
	"poison_vial": {
		"name": "Фиал яда", "rarity": "uncommon",
		"w": 1, "h": 1, "tags": ["poison"],
		"buy": 30, "sell": 13,
		"text": "Первый удар хода +2. +1 у клинка",
		"base": {"first_strike_bonus": 2},
		"adj": {"need": "blade", "first_strike_bonus": 1},
	},
	"mana_rune": {
		"name": "Руна ⚡", "rarity": "uncommon",
		"w": 1, "h": 1, "tags": ["rune"],
		"buy": 35, "sell": 15,
		"text": "1 раз за бой: +1 ⚡ в ход 1",
		"base": {"energy_first_turn": 1},
		"adj": {},
	},
	"coin_pouch": {
		"name": "Мешок монет", "rarity": "common",
		"w": 1, "h": 1, "tags": ["gold"],
		"buy": 20, "sell": 8,
		"text": "+15% золота с боёв",
		"base": {"gold_pct": 0.15},
		"adj": {},
	},
	"bone_charm": {
		"name": "Костяной оберег", "rarity": "uncommon",
		"w": 1, "h": 1, "tags": ["bone"],
		"buy": 32, "sell": 14,
		"text": "Убийство: +1 кость (макс 3/бой)",
		"base": {"bone_on_kill": 1},
		"adj": {},
	},
	"blood_charm": {
		"name": "Кровавый оберег", "rarity": "rare",
		"w": 1, "h": 1, "tags": ["blood"],
		"buy": 40, "sell": 18,
		"text": "Кровавые карты −1 HP (мин 1)",
		"base": {"blood_discount": 1},
		"adj": {},
	},
	"iron_plating": {
		"name": "Железная обшивка", "rarity": "rare",
		"w": 2, "h": 1, "tags": ["guard"],
		"buy": 45, "sell": 20,
		"text": "Старт +6 брони",
		"base": {"start_block": 6},
		"adj": {"need": "guard", "start_block": 2},
	},
	"hunter_fang": {
		"name": "Клык охотника", "rarity": "rare",
		"w": 1, "h": 1, "tags": ["blade"],
		"buy": 42, "sell": 19,
		"text": "Удар +2",
		"base": {"strike_dmg": 2},
		"adj": {"need": "whetstone", "strike_dmg": 1},
	},
	"ember_core": {
		"name": "Уголёк", "rarity": "epic",
		"w": 1, "h": 1, "tags": ["rune", "fire"],
		"buy": 55, "sell": 24,
		"text": "Заклинания +2 урона",
		"base": {"spell_dmg": 2},
		"adj": {},
	},
	"seal_shard": {
		"name": "Осколок Зарока", "rarity": "epic",
		"w": 1, "h": 1, "tags": ["relic", "shard"],
		"buy": 0, "sell": 30,
		"text": "Реликвия: +1 ⚡ каждый ход",
		"base": {"energy_each_turn": 1},
		"adj": {},
	},
}


static func has_item(id: String) -> bool:
	return ITEMS.has(id)


static func get_item(id: String) -> Dictionary:
	if not ITEMS.has(id):
		push_error("[ItemDB] unknown item: %s" % id)
		return {}
	return (ITEMS[id] as Dictionary).duplicate(true)


static func ids() -> Array:
	return ITEMS.keys()


static func ids_of_rarity(rarity: String) -> Array:
	return ITEMS.keys().filter(func(k): return str(ITEMS[k].get("rarity", "")) == rarity)


## Size after optional 90° rotation (only meaningful for non-square pieces).
static func size_of(id: String, rot: int = 0) -> Vector2i:
	var def := get_item(id)
	if def.is_empty():
		return Vector2i(1, 1)
	var w := int(def.get("w", 1))
	var h := int(def.get("h", 1))
	if rot % 2 == 1:
		return Vector2i(h, w)
	return Vector2i(w, h)


## Loot table by pack kind — DESIGN §8.3.
static func roll_loot(pack_kind: String, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	match pack_kind:
		"floor_boss":
			# 1 of 2 rare/epic
			var pool: Array = ids_of_rarity("rare") + ids_of_rarity("epic")
			pool = _shuffled(pool, rng)
			for i in mini(2, pool.size()):
				out.append({"id": pool[i], "pick": true})
		"mini_boss":
			var pool2: Array = ids_of_rarity("common") + ids_of_rarity("uncommon") + ids_of_rarity("rare")
			pool2 = _shuffled(pool2, rng)
			if not pool2.is_empty():
				out.append({"id": pool2[0], "pick": false})
		_:
			# normal: ~55% chance of 1 common
			if rng.randf() < 0.55:
				var commons: Array = ids_of_rarity("common")
				if not commons.is_empty():
					out.append({
						"id": commons[rng.randi_range(0, commons.size() - 1)],
						"pick": false,
					})
	return out


static func roll_shop_stock(count: int, rng: RandomNumberGenerator, upscale: bool = false) -> Array:
	var pool: Array = ids().duplicate()
	# Shards are boss/relic only — not on normal shop racks
	pool = pool.filter(func(k): return str(ITEMS[k].get("rarity", "")) != "epic" or k != "seal_shard")
	pool = pool.filter(func(k): return k != "seal_shard")
	pool = _shuffled(pool, rng)
	var out: Array = []
	for i in mini(count, pool.size()):
		var id: String = pool[i]
		var def := get_item(id)
		var price: int = int(def.get("buy", 20))
		if upscale:
			price = int(float(price) * 1.25)
		out.append({"id": id, "price": price})
	return out


static func _shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a
