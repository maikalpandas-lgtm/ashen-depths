extends RefCounted
## What the coloured words on a card actually mean.
##
## Card text says "Перенос" or "Остриё" and nothing anywhere explained them. The
## keyword was coloured, which told the player it was IMPORTANT and not what it
## did — arguably worse than plain text.
##
## Keyed by the exact strings CardView.KEYWORDS colours, so the two lists cannot
## drift: tests/glossary_test.gd fails if a coloured word has no entry here.

const ENTRIES := {
	"Пробой брони": "Урон проходит сквозь половину брони врага.",
	"по щиту": "Дополнительный урон, если у врага есть броня.",
	"Остриё": "Если у цели есть броня — на 2 урона больше.",
	"Перенос": "Лишний урон переходит на следующего живого врага.",
	"Перебор в броню": "Лишний урон становится твоей бронёй.",
	"Сгорает": "Карта уходит из боя совсем и больше не придёт.",
	"Добор": "Возьми ещё одну карту из колоды.",
	"Эхо": "Удар повторяется бесплатно, если есть кость.",
	"кость": "Ресурс с добитых врагов. Тратится на Эхо.",
	"кости": "Ресурс с добитых врагов. Тратится на Эхо.",
	"вампиризм": "Половина нанесённого урона вернётся тебе как HP.",
	"шип": "Враг, ударивший тебя, получает урон в ответ.",
	"брони": "Броня гасит урон и сгорает к началу твоего хода.",
	"урона": "Прямой урон по цели.",
	"HP": "Здоровье. Кровавые карты платят им вместо энергии.",
	"Отрава": "В конце хода теряет HP по числу стаков, потом −1 стак. Броня не спасает.",
	"Порча": "Получает на 50% больше урона.",
	"Немощь": "Наносит на 25% меньше урона.",
	"Ярость": "+1 урона за стак. Держится весь бой.",
	"50% соседу": "Половина урона задевает соседа по шеренге.",
	"ВСЕМ": "Задевает всю шеренгу врагов.",
}


static func has(word: String) -> bool:
	return ENTRIES.has(word)


static func text(word: String) -> String:
	return str(ENTRIES.get(word, ""))


## Keywords present in a card's rules text, longest first so "Пробой брони" wins
## over a bare "брони" — the same precedence CardView.colourise uses.
static func for_text(rules: String) -> Array:
	var found: Array = []
	var claimed := ""
	var words: Array = ENTRIES.keys()
	words.sort_custom(func(a, b): return str(a).length() > str(b).length())
	for w in words:
		var word := str(w)
		if rules.find(word) < 0:
			continue
		# Skip a word already covered by a longer phrase, and skip the synonym
		# pair кость/кости so the panel does not print the same line twice.
		if claimed.find(word) >= 0:
			continue
		var dup := false
		for already in found:
			if text(str(already)) == text(word):
				dup = true
				break
		if dup:
			continue
		found.append(word)
		claimed += word + "|"
	return found
