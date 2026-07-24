extends RefCounted
## Status effects — pure rules, no nodes, no scene tree.
##
## Split out of combat_state on purpose. Statuses are the foundation the rest of
## the card depth hangs off (docs/COMPETITOR_PLAN.md фаза A), so they have to be
## the most testable thing in the game, not the least.
##
## A status bag is a plain Dictionary {id: stacks}. Zero-stack entries are
## removed rather than kept at 0, so `bag.is_empty()` means "clean" and the UI
## can iterate the bag directly without filtering.

## Which way a status leans, so the UI can colour it without a second table.
enum Kind { HARM, BOON }

## `decay` — stacks lost at the END of the owner's turn.
##   1 = classic wear-off (Немощь fades)
##   0 = permanent until removed (Ярость holds for the fight)
## `dot` — deals its stack count as damage when it ticks, THEN decays.
const STATUSES := {
	"poison": {
		"name": "Отрава", "icon": "☠", "kind": Kind.HARM,
		"colour": Color(0.45, 0.78, 0.32), "decay": 1, "dot": true,
		"text": "В конце хода теряет HP равные стакам, потом −1 стак",
	},
	"frail": {
		"name": "Порча", "icon": "✜", "kind": Kind.HARM,
		"colour": Color(0.72, 0.38, 0.85), "decay": 1, "dot": false,
		"text": "Получает на 50% больше урона",
	},
	"weak": {
		"name": "Немощь", "icon": "↓", "kind": Kind.HARM,
		"colour": Color(0.55, 0.6, 0.68), "decay": 1, "dot": false,
		"text": "Наносит на 25% меньше урона",
	},
	"rage": {
		"name": "Ярость", "icon": "↑", "kind": Kind.BOON,
		"colour": Color(0.95, 0.55, 0.25), "decay": 0, "dot": false,
		"text": "+1 урона за стак",
	},
}

## Порча: multiplier on damage RECEIVED.
const FRAIL_MULT := 1.5
## Немощь: multiplier on damage DEALT.
const WEAK_MULT := 0.75


const ART_DIR := "res://assets/textures/"
static var _tex_cache: Dictionary = {}


## Icon texture, or null while the art is outstanding — the HUD falls back to a
## coloured pill with a symbol, which is what shipped before batch 11.
static func icon(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var path := ART_DIR + "status_" + id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = ResourceLoader.load(path, "Texture2D") as Texture2D
	_tex_cache[id] = tex
	return tex


static func exists(id: String) -> bool:
	return STATUSES.has(id)


static func info(id: String) -> Dictionary:
	return STATUSES.get(id, {})


## Add stacks. Negative amounts remove; hitting zero deletes the entry so the
## bag never carries dead keys into the UI.
static func apply(bag: Dictionary, id: String, amount: int) -> void:
	if not STATUSES.has(id) or amount == 0:
		return
	var now: int = int(bag.get(id, 0)) + amount
	if now <= 0:
		bag.erase(id)
	else:
		bag[id] = now


static func stacks(bag: Dictionary, id: String) -> int:
	return int(bag.get(id, 0))


## Damage this owner DEALS, after Ярость and Немощь.
##
## Rage is added before Weak multiplies, so being weakened cuts the buff too —
## the alternative lets a raging weakened attacker out-damage a healthy one.
static func outgoing(bag: Dictionary, amount: int) -> int:
	var out := amount + stacks(bag, "rage")
	if stacks(bag, "weak") > 0:
		out = int(floor(float(out) * WEAK_MULT))
	return maxi(0, out)


## Damage this owner RECEIVES, after Порча.
##
## Applied BEFORE block in combat_state: frail means the blow lands harder, and
## armour then soaks what it can — not the other way round.
static func incoming(bag: Dictionary, amount: int) -> int:
	if stacks(bag, "frail") > 0:
		return int(ceil(float(amount) * FRAIL_MULT))
	return amount


## End of the owner's turn. Returns damage-over-time to deal, and decays.
##
## DOT is read BEFORE decay, so 3 stacks of Отрава deal 3 and drop to 2. Decay
## first would silently rob the first tick.
static func tick(bag: Dictionary) -> int:
	var dot := 0
	for id in bag.keys():
		var def: Dictionary = STATUSES.get(id, {})
		if def.is_empty():
			continue
		if bool(def.get("dot", false)):
			dot += int(bag[id])
	for id in bag.keys():
		var def: Dictionary = STATUSES.get(id, {})
		var decay := int(def.get("decay", 0))
		if decay > 0:
			apply(bag, str(id), -decay)
	return dot


## Bag as an ordered list for the UI: harmful first, then by stack count, so the
## icon row does not reshuffle when a stack changes.
static func to_row(bag: Dictionary) -> Array:
	var out: Array = []
	for id in bag.keys():
		var def: Dictionary = STATUSES.get(id, {})
		if def.is_empty():
			continue
		out.append({
			"id": str(id),
			"tex": icon(str(id)),
			"stacks": int(bag[id]),
			"icon": str(def["icon"]),
			"name": str(def["name"]),
			"colour": def["colour"],
			"harm": int(def["kind"]) == Kind.HARM,
		})
	out.sort_custom(func(a, b):
		if a["harm"] != b["harm"]:
			return a["harm"]
		return str(a["id"]) < str(b["id"]))
	return out
