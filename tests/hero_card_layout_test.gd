extends SceneTree
## The hero select card must FIT. It was authored as a hard 330x470 with a 190px
## portrait, then a blurb and a biome picker were added above it, and the content
## grew to 522px inside a 486px card — the starting deck got sliced in half along
## the bottom edge, which is the one thing on that screen the player is choosing
## between.
##
## So the sizes are computed, and this holds them to it at every window size the
## game can realistically run at, for the fattest deck any hero has.
const HeroCardLayout = preload("res://scripts/ui/hero_card_layout.gd")
const Party = preload("res://scripts/party.gd")


func _init() -> void:
	var failed := 0

	var worst := 0
	for hero_id in Party.PLAYABLE:
		var seen := {}
		for card_id in (Party.HEROES[hero_id] as Dictionary)["deck"]:
			seen[str(card_id)] = true
		worst = maxi(worst, seen.size())
	if worst <= 0:
		printerr("  FAIL no hero decks found")
		quit(1)
		return

	# 720 is the shipped window; the rest are windows a player can drag to.
	for vp in [600.0, 720.0, 768.0, 900.0, 1080.0, 1440.0]:
		var m: Dictionary = HeroCardLayout.metrics(vp, worst)
		var content: float = float(m["content"])
		var budget: float = float(m["budget"])
		if content > budget + 0.5:
			printerr("  FAIL %dpx window: card needs %.0fpx, has %.0fpx"
				% [int(vp), content, budget])
			failed += 1
		if bool(m["overflow"]):
			printerr("  FAIL %dpx window reports overflow" % int(vp))
			failed += 1
		var portrait: float = float(m["portrait"])
		if portrait < HeroCardLayout.MIN_PORTRAIT - 0.5:
			printerr("  FAIL %dpx window shrank the portrait past its floor (%.0f)"
				% [int(vp), portrait])
			failed += 1

	# A tall window must not shrink anything — that would be pure waste
	var big: Dictionary = HeroCardLayout.metrics(1440.0, worst)
	if not is_equal_approx(float(big["portrait"]), HeroCardLayout.MAX_PORTRAIT):
		printerr("  FAIL a 1440px window still shrank the portrait to %.0f" % big["portrait"])
		failed += 1

	# The deck must actually wrap, not silently vanish off the side
	if HeroCardLayout.deck_rows(worst, HeroCardLayout.MAX_MINI.x) < 2:
		printerr("  FAIL %d distinct cards claim to fit in one row" % worst)
		failed += 1

	if failed == 0:
		print("  ok   hero card fits every window size (deck of %d distinct)" % worst)
	quit(1 if failed > 0 else 0)
