extends Area3D
## Placeholder pack of enemies. Phase 3 will open card combat.

@export var pack_name: String = "Cave Pack"
@export var enemy_count: int = 2

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true


func _on_body_entered(body: Node3D) -> void:
	if _triggered:
		return
	if body is CharacterBody3D and body.is_in_group("player"):
		_triggered = true
		print("[Encounter] %s (%d enemies) — card combat comes in Phase 3" % [pack_name, enemy_count])
		if GameState:
			GameState.encounter_started.emit(pack_name)
		# Visual feedback: dim the marker lights
		for child in get_children():
			if child is OmniLight3D:
				(child as OmniLight3D).light_color = Color(0.4, 0.1, 0.1)
			if child is MeshInstance3D:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.35, 0.1, 0.1)
				mat.emission_enabled = true
				mat.emission = Color(0.5, 0.05, 0.05)
				mat.emission_energy_multiplier = 0.6
				(child as MeshInstance3D).material_override = mat
