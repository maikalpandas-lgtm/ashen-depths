extends SceneTree
## Smoke: forest ground shader + forest SFX files resolve.


func _init() -> void:
	var failed := 0
	var sh: Shader = load("res://shaders/forest_ground.gdshader") as Shader
	if sh == null:
		printerr("  FAIL forest_ground.gdshader")
		failed += 1
	else:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("moss_amount", 0.45)
		print("  ok   forest_ground.gdshader loads")

	var stems := [
		"forest_step_0", "forest_step_1", "forest_step_2", "forest_step_3",
		"forest_bump", "forest_chest", "forest_path", "amb_forest",
	]
	for s in stems:
		var p := "res://assets/audio/sfx/%s.ogg" % s
		var stream: AudioStream = null
		if ResourceLoader.exists(p):
			stream = load(p) as AudioStream
		if stream == null and FileAccess.file_exists(p):
			stream = AudioStreamOggVorbis.load_from_file(p)
		if stream == null:
			printerr("  FAIL missing %s" % p)
			failed += 1
		else:
			print("  ok   %s" % s)

	if failed == 0:
		print("  ok   forest assets smoke (%d clips)" % stems.size())
	quit(1 if failed > 0 else 0)
