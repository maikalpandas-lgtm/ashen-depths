extends SceneTree
## Every pack the generator can actually produce must fit the corridor, and the
## world layout must use the SAME formation as combat — otherwise the pack
## visibly jumps into place the moment a fight opens.
const EnemySprites = preload("res://scripts/enemy_sprites.gd")

const CLEAR_WIDTH := 3.5  ## corridor minus the worst-case rock bulge


func _init() -> void:
	var packs := {}
	for floor_i in [1, 2, 3, 5, 8]:
		for h in range(8):
			packs[str(EnemySprites.pack_for(h, floor_i))] = EnemySprites.pack_for(h, floor_i)
		packs["mini%d" % floor_i] = EnemySprites.mini_boss_pack(floor_i)
		packs["boss%d" % floor_i] = EnemySprites.floor_boss_pack(floor_i)

	var failed := 0
	for key in packs:
		var pack: Array = packs[key]
		var n := pack.size()
		var layout := EnemySprites.form_layout(pack)
		var spacing := float(layout["spacing"])
		var scale_f := float(layout["scale"])
		var widest := 0.0
		for id in pack:
			var def: Dictionary = EnemySprites.ENEMIES.get(id, {})
			var px := EnemySprites.art_size(str(def.get("art", "")))
			if px == Vector2i.ZERO:
				continue
			widest = maxf(widest, float(def["height"]) * float(px.x) / float(px.y))
		var span: float = float(n - 1) * spacing + widest * scale_f
		if span > CLEAR_WIDTH:
			printerr("  FAIL %s spans %.2fm > %.1fm" % [pack, span, CLEAR_WIDTH])
			failed += 1
	if failed == 0:
		print("  ok   all %d real pack shapes fit the corridor" % packs.size())
	quit(1 if failed > 0 else 0)
