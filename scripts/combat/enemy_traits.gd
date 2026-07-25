extends RefCounted
## What an enemy DOES, as opposed to how much HP it has.
##
## Before this every monster behaved identically: _roll_intent read max_hp and
## picked a number. A grub, a stone brute and a mavka differed only in stats and
## art, so adding more monsters would have added pictures and no tactics.
##
## Node-free so it can be tested. Traits lean on the statuses from фаза A —
## poison, frail, weak and rage already exist, and this is what finally makes
## the ENEMY side use them.

## `block_chance` — how often it guards instead of swinging.
## `hits` — swings per attack (armour soaks each one separately, see фаза C).
## `dmg_mult` — on the rolled damage.
## `on_hit` — status hung on the hero when it connects: {id, stacks}.
## `on_turn` — status given to ITSELF or its allies at the start of its action.
const TRAITS := {
	## Bites twice for little. Armour is the answer; a big shield wastes it.
	"swarm": {
		"name": "Стая", "block_chance": 0.05, "hits": 2, "dmg_mult": 0.55,
		"text": "Бьёт дважды за полурона",
	},
	## Turtles up. Punish with Пробой брони rather than raw damage.
	"guard": {
		"name": "Заслон", "block_chance": 0.45, "hits": 1, "dmg_mult": 0.9,
		"text": "Часто закрывается бронёй",
	},
	## One heavy blow. Block it or lose a third of your health.
	"brute": {
		"name": "Тяжёлый", "block_chance": 0.05, "hits": 1, "dmg_mult": 1.5,
		"text": "Редко, но очень сильно",
	},
	## Stacks poison. Ignores armour entirely, so guarding does not help.
	"poisoner": {
		"name": "Отравитель", "block_chance": 0.15, "hits": 1, "dmg_mult": 0.7,
		"on_hit": {"id": "poison", "stacks": 2},
		"text": "Травит при попадании",
	},
	## Weakens the hero — the fight gets longer, not deadlier.
	"hexer": {
		"name": "Порчельник", "block_chance": 0.2, "hits": 1, "dmg_mult": 0.75,
		"on_hit": {"id": "weak", "stacks": 1},
		"text": "Ослабляет героя",
	},
	## Makes the hero take more. Deadly stacked with a brute beside it.
	"weaver": {
		"name": "Наводчик", "block_chance": 0.2, "hits": 1, "dmg_mult": 0.7,
		"on_hit": {"id": "frail", "stacks": 1},
		"text": "Наводит порчу — урон по герою растёт",
	},
	## Buffs the whole pack. Kill it FIRST, which is the decision this adds.
	"howler": {
		"name": "Ярун", "block_chance": 0.1, "hits": 1, "dmg_mult": 0.6,
		"on_turn": {"id": "rage", "stacks": 1, "allies": true},
		"text": "Распаляет стаю: +урон всем",
	},
}

const DEFAULT := "guard"


static func of(trait_id: String) -> Dictionary:
	return TRAITS.get(trait_id, TRAITS[DEFAULT])


static func exists(trait_id: String) -> bool:
	return TRAITS.has(trait_id)


## Short line for the codex / tooltip.
static func text(trait_id: String) -> String:
	return str(of(trait_id).get("text", ""))
