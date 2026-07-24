extends RefCounted
## Sizing for one hero card on the select screen.
##
## Split out and made pure because the card was authored with hard-coded pixels
## (330x470 with a 190px portrait) and then things were ADDED above it — a biome
## picker, a blurb — until the content needed 522px inside a 486px card and the
## starting deck was sliced in half along the bottom.
##
## So nothing here is a constant the caller picks. The card is told how much
## screen it may have and returns sizes that FIT, and a headless test holds it
## to that across window sizes.

## Fixed parts, measured from the real controls on a 1280x720 window.
const NAME_H := 29.0
const ROLE_H := 17.0
const SEP := 6.0        ## VBoxContainer separation between the 5 rows
const PAD := 24.0       ## box offset_top + offset_bottom inside the button
const RING := 14.0      ## portrait ring border + margin
const DECK_SEP := 4.0

const CARD_W := 330.0
const SIDE_PAD := 28.0  ## box offset_left + offset_right

## Everything the select screen puts ABOVE the hero row: title, subtitle, the
## biome picker and its note, plus the column's own top/bottom margins.
##
## MEASURED, not guessed: on a live 720px window the hero row was handed 486px,
## so the chrome is 234. The first estimate here was 210, which would have left
## the card 24px over budget — i.e. still clipped, just less obviously.
const CHROME_H := 240.0

const MIN_PORTRAIT := 108.0
const MAX_PORTRAIT := 190.0
const MIN_MINI := Vector2(52.0, 73.0)
const MAX_MINI := Vector2(74.0, 104.0)
const BLURB_H := 34.0


## How many rows `entries` mini-cards wrap into at width `mini_w`.
static func deck_rows(entries: int, mini_w: float) -> int:
	if entries <= 0:
		return 0
	var inner := CARD_W - SIDE_PAD
	var per_row: int = maxi(1, int(floor((inner + DECK_SEP) / (mini_w + DECK_SEP))))
	return int(ceil(float(entries) / float(per_row)))


static func content_height(portrait: float, mini: Vector2, entries: int) -> float:
	var rows := deck_rows(entries, mini.x)
	var deck_h: float = float(rows) * mini.y + maxf(0.0, float(rows - 1)) * DECK_SEP
	return (portrait + RING) + NAME_H + ROLE_H + BLURB_H + deck_h + SEP * 4.0 + PAD


## Biggest portrait + mini-card that still fit `viewport_h`, for the hero whose
## deck has the most distinct cards.
##
## Shrinks the portrait first and the deck thumbnails second: the deck is what
## the choice is actually ABOUT (DESIGN §5), so it is the last thing to give.
static func metrics(viewport_h: float, entries: int) -> Dictionary:
	var budget: float = maxf(220.0, viewport_h - CHROME_H)
	var portrait := MAX_PORTRAIT
	var mini := MAX_MINI
	# 24 steps is enough to walk both sliders to their floor at ~3px a step.
	for _i in range(24):
		if content_height(portrait, mini, entries) <= budget:
			break
		if portrait > MIN_PORTRAIT:
			portrait = maxf(MIN_PORTRAIT, portrait - 8.0)
			continue
		if mini.x > MIN_MINI.x:
			mini = Vector2(maxf(MIN_MINI.x, mini.x - 3.0), maxf(MIN_MINI.y, mini.y - 4.2))
			continue
		break
	var h := content_height(portrait, mini, entries)
	return {
		"portrait": portrait,
		"mini": mini,
		"card": Vector2(CARD_W, h),
		"content": h,
		"budget": budget,
		# True when even the smallest layout overflows — the caller cannot fix
		# it by shrinking further, and silently clipping is what got us here.
		"overflow": h > budget,
	}
