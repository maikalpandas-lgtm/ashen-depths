extends Area3D
## Map merchant — 0–1 per floor. Opens shop_overlay in merchant mode.

@export var shop_label: String = "Торговец"

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true


func _on_body_entered(body: Node3D) -> void:
	if _triggered:
		return
	if body is CharacterBody3D and body.is_in_group("player"):
		_triggered = true
		print("[Merchant] open shop")
		if GameState:
			GameState.request_merchant_shop()
		# Allow re-open next visit after leaving (reset when player exits area)
		# Simple: one open per touch; re-arm after short delay
		get_tree().create_timer(1.5, true, false, true).timeout.connect(
			func(): _triggered = false)
