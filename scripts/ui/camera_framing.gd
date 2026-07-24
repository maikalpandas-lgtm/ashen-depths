extends RefCounted
## Where the combat camera stands, and where that puts a monster on screen.
##
## Pure maths, no nodes, so tests/camera_framing_test.gd can check the framing
## instead of it being rediscovered from a screenshot. This has drifted wrong
## twice: too far (monsters were postage stamps) and then too close (their feet
## sat at 73% of the screen and the name/HP had nowhere to go but onto the legs).

const EnemySprites = preload("res://scripts/enemy_sprites.gd")

## Screen space below the feet that the labels and the hand need, as a fraction.
const NEED_BELOW := 0.34
## The BIGGEST enemy in a pack has to carry the shot.
const MIN_SPRITE_FRACTION := 0.22
## The smallest may genuinely be small — an anchutka is a knee-high imp — but it
## still has to be more than a smudge.
const MIN_SMALL_FRACTION := 0.13


const ASPECT := 16.0 / 9.0
## Height the tallest enemy should aim to fill.
const TARGET_TALL := 0.30
const MIN_DIST := 3.0
const MAX_DIST := 6.6


## Camera distance for THIS pack, not for its head count. Three grubs and three
## stone brutes are both "n = 3" but 3.4m and 5.7m of row, and sizing by count
## alone left small packs as specks while big ones still ran off the sides.
## Take whichever of "fit the width" and "make the tallest readable" needs more.
static func distance(pack: Array) -> float:
	var n: int = maxi(1, pack.size())
	var f := fov(n)
	var tallest := 0.0
	for id in pack:
		var def: Dictionary = EnemySprites.ENEMIES.get(id, {})
		tallest = maxf(tallest, float(def.get("height", 1.4)))
	tallest *= EnemySprites.form_scale(pack)
	if tallest <= 0.0:
		tallest = 1.4

	var layout: Dictionary = EnemySprites.form_layout(pack)
	var span: float = float(n - 1) * float(layout["spacing"]) \
		+ EnemySprites.pack_widest(pack) * float(layout["scale"])

	var tan_v := tan(deg_to_rad(f) * 0.5)
	# Far enough that the row fits across, with margin
	var need_w: float = (span * 1.25) / (2.0 * tan_v * ASPECT)
	# Close enough that the tallest fills its share of the height
	var need_h: float = tallest / (TARGET_TALL * 2.0 * tan_v)
	return clampf(maxf(need_w, need_h), MIN_DIST, MAX_DIST)


static func fov(n: int) -> float:
	return 58.0 if n <= 2 else (66.0 if n == 3 else 72.0)


## Height of the camera above the pack's feet.
static func height() -> float:
	return 1.95


## Point the camera aims at, in metres above the pack's feet. Aiming LOW raises
## the monsters up the frame, which is what frees the floor beneath them.
static func look_height() -> float:
	return 0.6


## Vertical screen fractions {head, feet}, 0 = top of screen, 1 = bottom.
static func screen_span(dist: float, cam_h: float, look_h: float,
		fov_deg: float, sprite_h: float) -> Dictionary:
	var half := deg_to_rad(fov_deg) * 0.5
	var axis := atan2(look_h - cam_h, dist)
	var feet := atan2(-cam_h, dist)
	var head := atan2(sprite_h - cam_h, dist)
	return {
		"head": 0.5 - (head - axis) / (2.0 * half),
		"feet": 0.5 - (feet - axis) / (2.0 * half),
	}
