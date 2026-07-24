extends RefCounted
## Pure geometry for the hand fan. No nodes, so the test can use the REAL code
## instead of a copy of it — importing combat_overlay.gd into a headless test
## hangs the run (see AGENTS.md).

const CARD_W := 124.0
const CARD_H := 174.0

## Hearthstone-style fan. A flat row of upright cards reads as a spreadsheet;
## an arc reads as cards held in a hand.
const MAX_ANGLE := 15.0   ## degrees at the outermost card
const ARC_LIFT := 26.0    ## how far the middle of the arc rises
const OVERLAP := 0.80     ## fraction of a card width between neighbours
const RAISE_LIFT := 42.0  ## how far the read card pulls out of the fan


## Position, rotation and scale of card `index` of `n` inside `area`.
## `raised` is the card under the cursor or being dragged.
static func slot(index: int, n: int, area: Vector2, raised: bool,
		dragging: bool) -> Dictionary:
	var step := CARD_W * OVERLAP
	var span: float = step * float(maxi(0, n - 1))
	# Squeeze if a full hand would otherwise run off the strip
	if span > area.x - CARD_W:
		step = (area.x - CARD_W) / float(maxi(1, n - 1))
		span = step * float(maxi(0, n - 1))

	var t: float = 0.0 if n <= 1 else (float(index) / float(n - 1)) * 2.0 - 1.0
	var x: float = area.x * 0.5 + t * span * 0.5 - CARD_W * 0.5
	# Arc: the middle of the hand rides higher than its ends
	var y: float = area.y - CARD_H - 6.0 + (1.0 - cos(t * PI * 0.5)) * ARC_LIFT
	var angle: float = t * MAX_ANGLE
	var scale_f := 1.0
	if raised:
		# Straighten, lift and grow — the reference pulls the read card out of
		# the fan entirely rather than just tinting it
		angle = 0.0
		y -= RAISE_LIFT
		scale_f = 1.22 if dragging else 1.14
	return {"pos": Vector2(x, y), "angle": angle, "scale": scale_f}
