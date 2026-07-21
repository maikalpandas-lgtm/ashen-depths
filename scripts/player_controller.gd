extends CharacterBody3D
## First-person controller for labyrinth exploration.

@export var walk_speed: float = 5.5
@export var sprint_speed: float = 8.0
@export var mouse_sensitivity: float = 0.0022
@export var gravity: float = 22.0
@export var jump_velocity: float = 6.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var _pitch: float = 0.0
var _mouse_captured: bool = true


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))
		head.rotation.x = _pitch

	if event.is_action_pressed("ui_cancel"):
		_mouse_captured = not _mouse_captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()


func teleport_to(world_pos: Vector3) -> void:
	global_position = world_pos
	velocity = Vector3.ZERO
