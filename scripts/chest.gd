extends Area3D
## Simple interactable chest.

@export var gold_min: int = 15
@export var gold_max: int = 40

var _opened: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var label := get_node_or_null("Label3D") as Label3D
	if label:
		label.text = "Chest [E]"


func try_open() -> void:
	if _opened:
		return
	_opened = true
	var amount := randi_range(gold_min, gold_max)
	if GameState:
		GameState.gold += amount
		GameState.chest_opened.emit(amount)
	print("[Chest] +%d gold (total %d)" % [amount, GameState.gold if GameState else amount])
	var label := get_node_or_null("Label3D") as Label3D
	if label:
		label.text = "Empty"
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.2, 0.12)
		mesh.material_override = mat


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("player") and not _opened:
		# Auto-open on touch for MVP; E can be wired later via player raycast
		try_open()
