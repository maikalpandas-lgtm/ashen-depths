extends RefCounted
## Timing curve for the card flourish. Node-free so a headless test can hold it
## — the overlay itself cannot be imported into a test (AGENTS.md).
##
## Three beats, and the middle one is the point: the card has to SIT still long
## enough to be read. A pure ease-in-ease-out looked slick and left the player
## unable to say what they had just picked up.

const RISE := 0.22   ## grow in from nothing
const HOLD := 0.75   ## sit still and be read
const FADE := 0.30   ## drift up and out
const TOTAL := RISE + HOLD + FADE

const START_SCALE := 0.55
const HOLD_SCALE := 1.0
const END_SCALE := 1.08
## How far it drifts up while fading, as a fraction of the card's height.
const DRIFT := 0.34


## Everything the view needs at time `t`: {scale, pos, alpha, caption_y}.
##
## `pos` is the TOP-LEFT of the card, already centred for `card` size — the
## caller sets pivot_offset to the middle so scale grows from the centre.
static func frame(t: float, viewport: Vector2, card: Vector2) -> Dictionary:
	var scale := HOLD_SCALE
	var alpha := 1.0
	var drift := 0.0

	if t < RISE:
		var u: float = clampf(t / RISE, 0.0, 1.0)
		# Overshoot slightly then settle — a linear grow reads as a popup
		var e: float = 1.0 - pow(1.0 - u, 3.0)
		scale = lerpf(START_SCALE, HOLD_SCALE, e)
		alpha = u
	elif t < RISE + HOLD:
		scale = HOLD_SCALE
		alpha = 1.0
	else:
		var u2: float = clampf((t - RISE - HOLD) / FADE, 0.0, 1.0)
		scale = lerpf(HOLD_SCALE, END_SCALE, u2)
		alpha = 1.0 - u2
		drift = u2 * card.y * DRIFT

	# Centred a little above the middle: the bottom third of the screen is the
	# hand and the draft row, and the flourish must not cover what it describes.
	var centre := Vector2(viewport.x * 0.5, viewport.y * 0.42 - drift)
	return {
		"scale": scale,
		"pos": centre - card * 0.5,
		"alpha": alpha,
		"caption_y": centre.y + card.y * 0.5 + 14.0,
	}
