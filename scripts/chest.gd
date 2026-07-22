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
	if Sfx:
		Sfx.play("chest")
		Sfx.play("gold", -2.0)
	print("[Chest] +%d gold (total %d)" % [amount, GameState.gold if GameState else amount])
	var label := get_node_or_null("Label3D") as Label3D
	if label:
		label.text = "Пусто"
	# Dim the 2D chest sprite once looted
	var holder := get_node_or_null("ChestSprite") as Node3D
	if holder:
		var spr := holder.get_node_or_null("Sprite") as Sprite3D
		if spr:
			spr.modulate = Color(0.45, 0.42, 0.4, 0.9)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("player") and not _opened:
		# Auto-open on touch for MVP; E can be wired later via player raycast
		try_open()
