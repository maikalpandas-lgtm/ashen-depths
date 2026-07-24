extends SceneTree
## Every sprite the game references must be IMPORTED, not merely present.
##
## A PNG dropped into assets/textures/ is invisible to ResourceLoader until
## Godot imports it and writes the .import file beside it. The forest shipped
## its first build with all fourteen props missing for exactly this reason:
## the trees never appeared, while the wolves did, because EnemySprites happens
## to have an Image.load() fallback and ForestProps does not.
##
## That fallback is NOT a fix. Image.load() on a res:// path does not work in an
## exported build — the files live in the .pck, not on disk (AGENTS.md). So an
## un-imported asset is a level that looks fine in the editor and ships EMPTY.
##
## Run after every art batch. `godot --headless --import` is the fix.
const EnemySprites = preload("res://scripts/enemy_sprites.gd")
const ForestProps = preload("res://scripts/forest_props.gd")
const CardDB = preload("res://scripts/cards/card_db.gd")
const Party = preload("res://scripts/party.gd")

const DIR := "res://assets/textures/"


func _init() -> void:
	var wanted := {}

	for id in EnemySprites.ENEMIES.keys():
		wanted[str((EnemySprites.ENEMIES[id] as Dictionary)["art"])] = "enemy %s" % id

	for entry in ForestProps.TREES:
		wanted[str(entry["art"])] = "forest tree"
	for entry in ForestProps.UNDERGROWTH:
		wanted[str(entry["art"])] = "forest undergrowth"
	for entry in [ForestProps.LANTERN, ForestProps.GLOWSHROOM,
			ForestProps.CAMPFIRE, ForestProps.TREELINE]:
		wanted[str(entry["art"])] = "forest prop"

	for card_id in CardDB.ids():
		var card: Dictionary = CardDB.get_card(str(card_id))
		if card.has("art"):
			wanted[str(card["art"])] = "card %s" % card_id

	for hero_id in Party.HEROES.keys():
		var def: Dictionary = Party.HEROES[hero_id]
		if def.has("portrait"):
			wanted[str(def["portrait"])] = "portrait %s" % hero_id

	var missing_file := []
	var not_imported := []
	for art in wanted.keys():
		if str(art) == "":
			continue
		var path := DIR + str(art) + ".png"
		if not FileAccess.file_exists(path):
			missing_file.append("%s (%s)" % [art, wanted[art]])
			continue
		# The .import file is what makes ResourceLoader see it at all
		if not ResourceLoader.exists(path):
			not_imported.append("%s (%s)" % [art, wanted[art]])

	var failed := 0
	if not missing_file.is_empty():
		printerr("  FAIL art files do not exist: %s" % ", ".join(missing_file))
		failed += 1
	if not not_imported.is_empty():
		printerr("  FAIL art present but NOT IMPORTED — invisible in an export.")
		printerr("       fix: godot --headless --import")
		printerr("       %s" % ", ".join(not_imported))
		failed += 1
	if failed == 0:
		print("  ok   all %d referenced sprites exist and are imported" % wanted.size())
	quit(1 if failed > 0 else 0)
