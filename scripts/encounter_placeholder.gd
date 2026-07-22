extends Area3D
## Placeholder pack of enemies. Phase 3 will open card combat.

@export var pack_name: String = "Cave Pack"
@export var enemy_count: int = 2
## Enemy ids standing here, filled in by the generator
@export var pack_ids: Array = []
## "normal" | "mini_boss" | "floor_boss" — XP / gold / banner
@export var pack_kind: String = "normal"

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true


func _on_body_entered(body: Node3D) -> void:
	if _triggered:
		return
	if body is CharacterBody3D and body.is_in_group("player"):
		_triggered = true
		print("[Encounter] %s (%s) — %s" % [pack_name, pack_kind, pack_ids])
		if GameState:
			GameState.encounter_started.emit(pack_name)
			GameState.combat_requested.emit(pack_ids, self)
		for child in get_children():
			if child is OmniLight3D:
				var light := child as OmniLight3D
				match pack_kind:
					"floor_boss":
						light.light_color = Color(0.95, 0.25, 0.15)
						light.light_energy = 2.4
					"mini_boss":
						light.light_color = Color(1.0, 0.55, 0.2)
						light.light_energy = 2.0
					_:
						light.light_color = Color(0.9, 0.35, 0.2)
