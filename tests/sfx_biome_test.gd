extends SceneTree
## A half-finished forest sound pack must never go SILENT.
##
## Biome clips are looked up first, but the forest ships before its .ogg files
## do, so every id has to fall back to the cave clip that already exists. This
## test walks every biome override and asserts the fallback chain, because the
## failure mode is silence — and silence is exactly what nobody notices in a
## playtest until the whole pack is missing.
const SfxScript = preload("res://scripts/sfx.gd")


func _init() -> void:
	var failed := 0
	var checked := 0
	for biome in SfxScript.BIOME_SFX.keys():
		var table: Dictionary = SfxScript.BIOME_SFX[biome]
		for id in table.keys():
			checked += 1
			if not SfxScript.CATALOG.has(id):
				printerr("  FAIL %s/%s has no CATALOG fallback — goes silent" % [biome, id])
				failed += 1
	# Every ambience bed and override table must name a REAL biome, or
	# set_biome silently refuses it and the level plays the wrong soundscape.
	for biome in SfxScript.AMBIENCE.keys():
		if not SfxScript.BIOMES.has(biome):
			printerr("  FAIL ambience for unknown biome '%s'" % biome)
			failed += 1
	for biome in SfxScript.BIOME_SFX.keys():
		if not SfxScript.BIOMES.has(biome):
			printerr("  FAIL sfx overrides for unknown biome '%s'" % biome)
			failed += 1
	if failed == 0:
		print("  ok   every biome clip falls back to a real one (%d checked)" % checked)
	quit(1 if failed > 0 else 0)
