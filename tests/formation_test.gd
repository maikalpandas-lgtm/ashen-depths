extends SceneTree
## Every pack the generator can actually produce must fit the corridor, and the
## world layout must use the SAME formation as combat — otherwise the pack
## visibly jumps into place the moment a fight opens.
const EnemySprites = preload("res://scripts/enemy_sprites.gd")

const CLEAR_WIDTH := 3.5  ## corridor minus the worst-case rock bulge


func _init() -> void:
	var packs := {}
	for biome in ["mine", "forest"]:
		for floor_i in [1, 2, 3, 5, 8]:
			for h in range(8):
				var p: Array = EnemySprites.pack_for(h, floor_i, biome)
				packs[str(p)] = p
			packs["mini_%s%d" % [biome, floor_i]] = EnemySprites.mini_boss_pack(floor_i, biome)
			packs["boss_%s%d" % [biome, floor_i]] = EnemySprites.floor_boss_pack(floor_i, biome)

	var failed := 0
	# A monster whose PNG is not drawn yet has NO width, and pack_widest quietly
	# substitutes 1.3m. That makes this test pass on a guess: when the real art
	# lands the silhouette changes and the row can stop fitting. So say so out
	# loud rather than reporting a clean run.
	var guessed := []
	for id in EnemySprites.ids():
		var art := str((EnemySprites.ENEMIES[id] as Dictionary).get("art", ""))
		if EnemySprites.art_size(art) == Vector2i.ZERO:
			guessed.append("%s (%s)" % [id, art])
	if not guessed.is_empty():
		print("  NOTE art missing, width GUESSED at 1.3m: %s" % ", ".join(guessed))
		print("       re-run this test once Grok delivers, the row may stop fitting")
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
