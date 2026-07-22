extends CharacterBody3D
## Grid crawler ONLY: step cell-to-cell, 90° turns (A/D), camera locked forward.
## No free-look mouse yaw — props can stay fixed on walls without billboards.
## Y is always locked — cannot fall through the world.

@export var step_time: float = 0.16
@export var turn_time: float = 0.12
@export var move_cooldown: float = 0.02
@export var feet_y: float = 0.0
## Walk sway — tune live in the inspector.
@export var sway_shift: float = 0.038  ## sideways travel of the hands, metres
@export var sway_lift: float = 0.016  ## vertical bob, metres
@export var sway_roll: float = 6.5  ## hand roll, degrees
@export var sway_period: float = 0.62  ## seconds per full left-right-left cycle
@export var sway_ease_in: float = 0.14  ## seconds to spin up when you start walking
@export var sway_ease_out: float = 0.3  ## seconds to settle when you stop

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

const FACINGS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

## Dungeon generator node (has is_walkable_cell / cell_to_world). Untyped: no class_name dep.
var dungeon: Node = null
var cell: Vector2i = Vector2i.ZERO
var facing_index: int = 0
var _busy: bool = false
var _input_lock: float = 0.0
var _mouse_captured: bool = true
var _move_tween: Tween = null

# Viewmodel hand sway (left torch / right knife)
var _viewmodel: Node3D = null
var _hand_left: Node3D = null
var _hand_right: Node3D = null
var _left_base: Vector3 = Vector3.ZERO
var _right_base: Vector3 = Vector3.ZERO
var _left_rot_base: Vector3 = Vector3.ZERO
var _right_rot_base: Vector3 = Vector3.ZERO
var _walk_phase: float = 0.0
var _walk_amount: float = 0.0  ## 0 = standing still, 1 = full stride


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true
	if head:
		head.rotation.x = deg_to_rad(-2.0)
	if camera:
		camera.fov = 72.0
		camera.near = 0.08
		camera.far = 28.0
	_spawn_view_torch()


func _spawn_view_torch() -> void:
	if camera == null:
		return
	const TorchSprites = preload("res://scripts/torch_sprites.gd")
	_viewmodel = TorchSprites.make_hand_torch(camera)
	_hand_left = _viewmodel.get_node_or_null("HandTorch") as Node3D
	_hand_right = _viewmodel.get_node_or_null("HandKnife") as Node3D
	if _hand_left:
		_left_base = _hand_left.position
		_left_rot_base = _hand_left.rotation_degrees
	if _hand_right:
		_right_base = _hand_right.position
		_right_rot_base = _hand_right.rotation_degrees


func setup_dungeon(dungeon_ref: Node) -> void:
	dungeon = dungeon_ref
	if dungeon != null and not dungeon.has_method("is_walkable_cell"):
		push_warning("[Player] setup_dungeon: node missing is_walkable_cell: %s" % dungeon)


func teleport_to(world_pos: Vector3) -> void:
	_kill_tween()
	velocity = Vector3.ZERO
	_busy = false
	_input_lock = 0.0
	if dungeon and dungeon.has_method("world_to_cell"):
		cell = dungeon.call("world_to_cell", world_pos) as Vector2i
		# Safety: if cell not walkable, snap to start
		if not _cell_walkable(cell) and dungeon.get("start_cell") != null:
			cell = dungeon.get("start_cell") as Vector2i
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
	_auto_walk()
	_update_sway(delta)


## Held key keeps walking. _unhandled_input only fires on the press edge, so on
## its own it gave exactly one step per keypress.
func _auto_walk() -> void:
	if _busy or _input_lock > 0.0 or dungeon == null:
		return
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up"):
		_try_step(FACINGS[facing_index])
	elif Input.is_action_pressed("move_back") or Input.is_action_pressed("ui_down"):
		_try_step(FACINGS[facing_index] * -1)


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
	if not _cell_walkable(next):
		_bump()
		return
	cell = next
	_busy = true
	_input_lock = step_time + move_cooldown
	if Sfx:
		Sfx.play("step", -4.0, 0.08)
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
	if Sfx:
		Sfx.play("turn", -8.0, 0.05)
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
	_check_exit_cell()


## EXIT campfire tile — descend one floor (run continues, new labyrinth).
func _check_exit_cell() -> void:
	if dungeon == null or not dungeon.has_method("get_cell_type"):
		return
	# Cell.EXIT == 4 in dungeon_generator.gd enum
	if int(dungeon.call("get_cell_type", cell.x, cell.y)) != 4:
		return
	# Floor shop first (DESIGN §8.3), then advance_floor from shop leave
	if GameState and GameState.has_method("request_exit_shop"):
		if Sfx:
			Sfx.play("floor_down", -2.0)
		GameState.request_exit_shop()
	elif GameState and GameState.has_method("advance_floor"):
		GameState.advance_floor()


func _kill_tween() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null


func _bump() -> void:
	# Throttle: with auto-walk, holding W into a wall would otherwise spawn a
	# bump tween every single frame.
	_input_lock = 0.22
	if Sfx:
		Sfx.play("bump", -6.0, 0.04)
	if camera == null:
		return
	var tw := create_tween()
	var base := camera.position
	tw.tween_property(camera, "position", base + Vector3(0.04, 0, 0), 0.04)
	tw.tween_property(camera, "position", base, 0.06)


## Continuous left/right walk sway, driven every frame off a running phase.
##
## This used to be a tween fired once per step. That could not read as walking:
## a step is 0.16s, so the swing was over before the eye caught it, and every
## new step killed the tween mid-flight. A free-running sine keeps the hands
## moving for as long as you hold the key and settles smoothly when you stop.
func _update_sway(delta: float) -> void:
	if _hand_left == null and _hand_right == null:
		return

	var walking := _busy or _walk_key_held()
	var ease_time := sway_ease_in if walking else sway_ease_out
	var target := 1.0 if walking else 0.0
	_walk_amount = move_toward(_walk_amount, target, delta / maxf(ease_time, 0.01))

	if _walk_amount <= 0.0005:
		# Snap to rest so a stopped viewmodel is exactly where it was authored
		if _hand_left:
			_hand_left.position = _left_base
			_hand_left.rotation_degrees = _left_rot_base
		if _hand_right:
			_hand_right.position = _right_base
			_hand_right.rotation_degrees = _right_rot_base
		return

	_walk_phase = fposmod(_walk_phase + delta * TAU / maxf(sway_period, 0.05), TAU)
	var side := sin(_walk_phase)
	var bob := -absf(cos(_walk_phase))  # dips twice per cycle, like footfalls
	var amt := _walk_amount

	if _hand_left:
		_hand_left.position = _left_base + Vector3(
			sway_shift * side, sway_lift * bob, 0.0) * amt
		_hand_left.rotation_degrees = _left_rot_base + Vector3(
			0.0, 0.0, sway_roll * side * 0.7) * amt
	if _hand_right:
		# Opposite phase — walking gait
		_hand_right.position = _right_base + Vector3(
			-sway_shift * 0.95 * side, sway_lift * 0.9 * bob, 0.0) * amt
		_hand_right.rotation_degrees = _right_rot_base + Vector3(
			0.0, 0.0, -sway_roll * side * 0.65) * amt


func _walk_key_held() -> bool:
	return (Input.is_action_pressed("move_forward") or Input.is_action_pressed("ui_up")
		or Input.is_action_pressed("move_back") or Input.is_action_pressed("ui_down"))


func _cell_walkable(c: Vector2i) -> bool:
	if dungeon == null or not dungeon.has_method("is_walkable_cell"):
		return false
	return bool(dungeon.call("is_walkable_cell", c.x, c.y))


func _cell_world_pos(c: Vector2i) -> Vector3:
	if dungeon and dungeon.has_method("cell_to_world"):
		var w: Vector3 = dungeon.call("cell_to_world", c) as Vector3
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
		if _cell_walkable(n):
			return i
	return 0


func get_facing() -> Vector2i:
	return FACINGS[facing_index]
