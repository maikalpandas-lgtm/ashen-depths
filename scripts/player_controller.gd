extends CharacterBody3D
## Grid crawler: step cell-to-cell, 90° turns, camera locked forward.
## Y is always locked — cannot fall through the world.

@export var step_time: float = 0.16
@export var turn_time: float = 0.12
@export var move_cooldown: float = 0.02
@export var feet_y: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

const FACINGS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

var dungeon: Node3D = null
var cell: Vector2i = Vector2i.ZERO
var facing_index: int = 0
var _busy: bool = false
var _input_lock: float = 0.0
var _mouse_captured: bool = true
var _move_tween: Tween = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true
	if head:
		head.rotation.x = deg_to_rad(-2.0)
	if camera:
		camera.fov = 72.0
	_spawn_view_torch()


func _spawn_view_torch() -> void:
	if camera == null:
		return
	var holder := Node3D.new()
	holder.name = "ViewTorch"
	holder.position = Vector3(-0.38, -0.32, -0.55)
	camera.add_child(holder)

	var stick := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.04
	cyl.height = 0.45
	stick.mesh = cyl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.35, 0.2, 0.1)
	stick.material_override = sm
	stick.rotation_degrees = Vector3(18, 0, -8)
	stick.position = Vector3(0, -0.1, 0)
	holder.add_child(stick)

	var flame := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.09
	sph.height = 0.18
	flame.mesh = sph
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.55, 0.15)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.6, 0.2)
	fm.emission_energy_multiplier = 3.5
	flame.material_override = fm
	flame.position = Vector3(0, 0.14, 0.02)
	holder.add_child(flame)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.position = Vector3(0, 0.16, 0)
	holder.add_child(light)


func setup_dungeon(dungeon_ref: Node3D) -> void:
	dungeon = dungeon_ref


func teleport_to(world_pos: Vector3) -> void:
	_kill_tween()
	velocity = Vector3.ZERO
	_busy = false
	_input_lock = 0.0
	if dungeon and dungeon.has_method("world_to_cell"):
		cell = dungeon.world_to_cell(world_pos)
		# Safety: if cell not walkable, snap to start
		if not dungeon.is_walkable_cell(cell.x, cell.y) and dungeon.get("start_cell") != null:
			cell = dungeon.start_cell
		global_position = _cell_world_pos(cell)
		facing_index = _pick_open_facing()
		rotation.y = _yaw_for_facing(facing_index)
	else:
		global_position = Vector3(world_pos.x, feet_y, world_pos.z)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_mouse_captured = not _mouse_captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
		return

	if _busy or _input_lock > 0.0:
		return

	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_turn(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_turn(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_try_step(FACINGS[facing_index])
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_try_step(FACINGS[facing_index] * -1)
		get_viewport().set_input_as_handled()
		return


func _process(delta: float) -> void:
	if _input_lock > 0.0:
		_input_lock -= delta


func _physics_process(_delta: float) -> void:
	velocity = Vector3.ZERO
	# Always pin height — never fall out of the world
	if not _busy:
		var p := global_position
		if dungeon:
			p = _cell_world_pos(cell)
		p.y = feet_y
		global_position = p
	else:
		# During step tween still force Y
		global_position.y = feet_y


func _try_step(delta_cell: Vector2i) -> void:
	if _busy or dungeon == null:
		return
	var next := cell + delta_cell
	if not dungeon.is_walkable_cell(next.x, next.y):
		_bump()
		return
	cell = next
	_busy = true
	_input_lock = step_time + move_cooldown
	var target := _cell_world_pos(cell)
	_kill_tween()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "global_position", target, step_time)
	_move_tween.finished.connect(_on_move_done)


func _turn(dir: int) -> void:
	if _busy:
		return
	_busy = true
	_input_lock = turn_time + move_cooldown
	facing_index = posmod(facing_index + dir, 4)
	var target_yaw := _yaw_for_facing(facing_index)
	_kill_tween()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_move_tween.tween_method(_set_yaw, rotation.y, _lerp_angle_to(rotation.y, target_yaw), turn_time)
	_move_tween.finished.connect(_on_move_done)


func _set_yaw(y: float) -> void:
	rotation.y = y


func _lerp_angle_to(from: float, to: float) -> float:
	return from + wrapf(to - from, -PI, PI)


func _on_move_done() -> void:
	_busy = false
	rotation.y = _yaw_for_facing(facing_index)
	if dungeon:
		global_position = _cell_world_pos(cell)
	global_position.y = feet_y


func _kill_tween() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null


func _bump() -> void:
	if camera == null:
		return
	var tw := create_tween()
	var base := camera.position
	tw.tween_property(camera, "position", base + Vector3(0.04, 0, 0), 0.04)
	tw.tween_property(camera, "position", base, 0.06)


func _cell_world_pos(c: Vector2i) -> Vector3:
	if dungeon and dungeon.has_method("cell_to_world"):
		var w: Vector3 = dungeon.cell_to_world(c)
		return Vector3(w.x, feet_y, w.z)
	return Vector3(global_position.x, feet_y, global_position.z)


func _yaw_for_facing(idx: int) -> float:
	match idx:
		0:
			return 0.0
		1:
			return -PI * 0.5
		2:
			return PI
		3:
			return PI * 0.5
		_:
			return 0.0


func _pick_open_facing() -> int:
	if dungeon == null:
		return 0
	for i in range(4):
		var n: Vector2i = cell + FACINGS[i]
		if dungeon.is_walkable_cell(n.x, n.y):
			return i
	return 0


func get_facing() -> Vector2i:
	return FACINGS[facing_index]
