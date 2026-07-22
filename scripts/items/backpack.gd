extends RefCounted
## Party backpack grid 5×4 — DESIGN.md §8.2.
## Items 1×1 / 2×1 (rotatable). Orthogonal adjacency only.

const ItemDB = preload("res://scripts/items/item_db.gd")

const WIDTH := 5
const HEIGHT := 4

## uid → {id, x, y, rot}
var placed: Dictionary = {}
var _next_uid: int = 1


func clear() -> void:
	placed.clear()
	_next_uid = 1


func count() -> int:
	return placed.size()


func list_items() -> Array:
	var out: Array = []
	for uid in placed.keys():
		var p: Dictionary = placed[uid]
		out.append({
			"uid": uid,
			"id": p["id"],
			"x": p["x"],
			"y": p["y"],
			"rot": p["rot"],
			"def": ItemDB.get_item(str(p["id"])),
		})
	return out


func size_at(id: String, rot: int) -> Vector2i:
	return ItemDB.size_of(id, rot)


## Occupied cells as Vector2i → uid
func _occupancy() -> Dictionary:
	var map := {}
	for uid in placed.keys():
		var p: Dictionary = placed[uid]
		var sz := size_at(str(p["id"]), int(p["rot"]))
		for dy in range(sz.y):
			for dx in range(sz.x):
				map[Vector2i(int(p["x"]) + dx, int(p["y"]) + dy)] = uid
	return map


func can_place(id: String, x: int, y: int, rot: int = 0, ignore_uid: String = "") -> bool:
	if not ItemDB.has_item(id):
		return false
	var sz := size_at(id, rot)
	if x < 0 or y < 0 or x + sz.x > WIDTH or y + sz.y > HEIGHT:
		return false
	var occ := _occupancy()
	for dy in range(sz.y):
		for dx in range(sz.x):
			var cell := Vector2i(x + dx, y + dy)
			if occ.has(cell) and str(occ[cell]) != ignore_uid:
				return false
	return true


func place(id: String, x: int, y: int, rot: int = 0) -> String:
	if not can_place(id, x, y, rot):
		return ""
	var uid := "i%d" % _next_uid
	_next_uid += 1
	placed[uid] = {"id": id, "x": x, "y": y, "rot": rot % 2}
	return uid


func remove(uid: String) -> String:
	if not placed.has(uid):
		return ""
	var id: String = str(placed[uid]["id"])
	placed.erase(uid)
	return id


func move(uid: String, x: int, y: int, rot: int = -1) -> bool:
	if not placed.has(uid):
		return false
	var p: Dictionary = placed[uid]
	var id: String = str(p["id"])
	var r: int = int(p["rot"]) if rot < 0 else rot % 2
	if not can_place(id, x, y, r, uid):
		return false
	p["x"] = x
	p["y"] = y
	p["rot"] = r
	placed[uid] = p
	return true


## First free top-left fit; tries both rotations for elongated items.
func auto_place(id: String) -> String:
	for rot in [0, 1]:
		var sz := size_at(id, rot)
		if sz == Vector2i(1, 1) and rot == 1:
			continue
		for y in range(HEIGHT):
			for x in range(WIDTH):
				var uid := place(id, x, y, rot)
				if not uid.is_empty():
					return uid
	return ""


func has_space_for(id: String) -> bool:
	for rot in [0, 1]:
		var sz := size_at(id, rot)
		if sz == Vector2i(1, 1) and rot == 1:
			continue
		for y in range(HEIGHT):
			for x in range(WIDTH):
				if can_place(id, x, y, rot):
					return true
	return false


## Tags present on orthogonally neighbouring items (excluding self).
func _neighbour_tags(uid: String) -> Array:
	if not placed.has(uid):
		return []
	var occ := _occupancy()
	var p: Dictionary = placed[uid]
	var sz := size_at(str(p["id"]), int(p["rot"]))
	var seen_uids := {}
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for dy in range(sz.y):
		for dx in range(sz.x):
			var cell := Vector2i(int(p["x"]) + dx, int(p["y"]) + dy)
			for d in dirs:
				var n: Vector2i = cell + d
				if not occ.has(n):
					continue
				var nuid: String = str(occ[n])
				if nuid == uid or seen_uids.has(nuid):
					continue
				seen_uids[nuid] = true
	var tags: Array = []
	for nuid in seen_uids.keys():
		var def: Dictionary = ItemDB.get_item(str(placed[nuid]["id"]))
		for t in def.get("tags", []):
			if not tags.has(t):
				tags.append(t)
	return tags


## Aggregate combat modifiers from all placed items + adjacency.
## Keys: strike_dmg, spell_dmg, start_block, energy_first_turn, energy_each_turn,
##        gold_pct, bone_on_kill, blood_discount, first_strike_bonus
func compute_mods() -> Dictionary:
	var mods := {
		"strike_dmg": 0,
		"spell_dmg": 0,
		"start_block": 0,
		"energy_first_turn": 0,
		"energy_each_turn": 0,
		"gold_pct": 0.0,
		"bone_on_kill": 0,
		"blood_discount": 0,
		"first_strike_bonus": 0,
	}
	for uid in placed.keys():
		var p: Dictionary = placed[uid]
		var def: Dictionary = ItemDB.get_item(str(p["id"]))
		if def.is_empty():
			continue
		_add_mod_dict(mods, def.get("base", {}))
		var adj: Dictionary = def.get("adj", {})
		var need: String = str(adj.get("need", ""))
		if not need.is_empty():
			var ntags := _neighbour_tags(uid)
			if ntags.has(need):
				var bonus := adj.duplicate()
				bonus.erase("need")
				_add_mod_dict(mods, bonus)
	# Bone charm cap is applied per-combat in combat_state
	return mods


func _add_mod_dict(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		if k == "need":
			continue
		if k == "gold_pct":
			dst["gold_pct"] = float(dst.get("gold_pct", 0.0)) + float(src[k])
		else:
			dst[k] = int(dst.get(k, 0)) + int(src[k])


func sell_value(uid: String) -> int:
	if not placed.has(uid):
		return 0
	var def := ItemDB.get_item(str(placed[uid]["id"]))
	return int(def.get("sell", 5))
