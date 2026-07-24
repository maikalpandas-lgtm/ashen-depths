extends SceneTree
## Combat framing must leave room under the monsters for their name, HP bar and
## the card hand, while keeping the pack big enough to look at. Both halves have
## been broken before, in both directions — too far, then too close.
const CameraFraming = preload("res://scripts/ui/camera_framing.gd")
const EnemySprites = preload("res://scripts/enemy_sprites.gd")


func _init() -> void:
	var packs := {}
	for floor_i in [1, 3, 5]:
		for h in range(8):
			packs[str(EnemySprites.pack_for(h, floor_i))] = EnemySprites.pack_for(h, floor_i)
		packs["mini%d" % floor_i] = EnemySprites.mini_boss_pack(floor_i)
		packs["boss%d" % floor_i] = EnemySprites.floor_boss_pack(floor_i)

	var failed := 0
	for key in packs:
		var pack: Array = packs[key]
		var n := pack.size()
		var dist := CameraFraming.distance(pack)
		var f := CameraFraming.fov(n)
		var scale_f := EnemySprites.form_scale(pack)

		var tallest := 0.0
		var shortest := 99.0
		for id in pack:
			var h: float = float(EnemySprites.ENEMIES[id]["height"]) * scale_f
			tallest = maxf(tallest, h)
			shortest = minf(shortest, h)

		var big: Dictionary = CameraFraming.screen_span(
			dist, CameraFraming.height(), CameraFraming.look_height(), f, tallest)
		var small: Dictionary = CameraFraming.screen_span(
			dist, CameraFraming.height(), CameraFraming.look_height(), f, shortest)

		if 1.0 - float(big["feet"]) < CameraFraming.NEED_BELOW:
			printerr("  FAIL %s: feet at %.0f%%, only %.0f%% free below"
				% [pack, float(big["feet"]) * 100.0, (1.0 - float(big["feet"])) * 100.0])
			failed += 1
		if float(big["feet"]) - float(big["head"]) < CameraFraming.MIN_SPRITE_FRACTION:
			printerr("  FAIL %s: biggest is only %.0f%% of the screen"
				% [pack, (float(big["feet"]) - float(big["head"])) * 100.0])
			failed += 1
		if float(small["feet"]) - float(small["head"]) < CameraFraming.MIN_SMALL_FRACTION:
			printerr("  FAIL %s: smallest is only %.0f%% of the screen"
				% [pack, (float(small["feet"]) - float(small["head"])) * 100.0])
			failed += 1
		if float(big["head"]) < 0.02:
			printerr("  FAIL %s: head cropped by the top edge" % [pack])
			failed += 1
	if failed == 0:
		print("  ok   framing: %d packs fit with room below and stay readable" % packs.size())
	quit(1 if failed > 0 else 0)
