extends Node3D
## Procedural rooms + corridors labyrinth (Phase 1 MVP).

enum Cell {
	WALL,
	FLOOR,
	DOOR,
	START,
	EXIT,
	CHEST,
	ENCOUNTER,
}

signal generation_finished(start_world: Vector3)

@export var grid_width: int = 41
@export var grid_height: int = 41
@export var room_count: int = 10
@export var room_min_size: int = 4
@export var room_max_size: int = 8
@export var cell_size: float = 3.0
@export var wall_height: float = 3.2
@export var encounter_rooms: int = 4
@export var torch_spacing: int = 4

var grid: Array = []  # 2D: grid[y][x] -> Cell
var rooms: Array[Rect2i] = []
var start_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO

var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _door_mat: StandardMaterial3D
var _ceiling_mat: StandardMaterial3D

@onready var geometry_root: Node3D = $Geometry
@onready var props_root: Node3D = $Props
@onready var entities_root: Node3D = $Entities


func _ready() -> void:
	_build_materials()
	generate()


func generate(seed_value: int = 0) -> void:
	if seed_value == 0:
		seed_value = randi()
	seed(seed_value)
	if GameState:
		GameState.current_seed = seed_value

	_clear_children(geometry_root)
	_clear_children(props_root)
	_clear_children(entities_root)
	rooms.clear()

	_init_grid()
	_place_rooms()
	_connect_rooms()
	_mark_doors()
	_place_start_and_exit()
	_place_chest_in_dead_end()
	_place_encounters()
	_build_meshes()
	_spawn_torches()
	_spawn_props_and_entities()

	var start_world := cell_to_world(start_cell) + Vector3(0, 0.1, 0)
	print("[Dungeon] seed=%s rooms=%d start=%s exit=%s" % [seed_value, rooms.size(), start_cell, exit_cell])
	generation_finished.emit(start_world)
	if GameState:
		GameState.dungeon_ready.emit(start_world)


func cell_to_world(cell: Vector2i) -> Vector3:
	var ox := -grid_width * cell_size * 0.5
	var oz := -grid_height * cell_size * 0.5
	return Vector3(ox + cell.x * cell_size + cell_size * 0.5, 0.0, oz + cell.y * cell_size + cell_size * 0.5)


func _build_materials() -> void:
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.albedo_color = Color(0.22, 0.2, 0.28)
	_floor_mat.roughness = 0.92

	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.35, 0.32, 0.42)
	_wall_mat.roughness = 0.88

	_door_mat = StandardMaterial3D.new()
	_door_mat.albedo_color = Color(0.45, 0.28, 0.18)
	_door_mat.roughness = 0.7

	_ceiling_mat = StandardMaterial3D.new()
	_ceiling_mat.albedo_color = Color(0.12, 0.1, 0.16)
	_ceiling_mat.roughness = 1.0


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		c.queue_free()


func _init_grid() -> void:
	grid.clear()
	for y in range(grid_height):
		var row: Array = []
		row.resize(grid_width)
		for x in range(grid_width):
			row[x] = Cell.WALL
		grid.append(row)


func _set_cell(x: int, y: int, value: int) -> void:
	if x < 0 or y < 0 or x >= grid_width or y >= grid_height:
		return
	grid[y][x] = value


func _get_cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= grid_width or y >= grid_height:
		return Cell.WALL
	return grid[y][x]


func _is_walkable(v: int) -> bool:
	return v != Cell.WALL


func _place_rooms() -> void:
	var attempts := 0
	while rooms.size() < room_count and attempts < room_count * 30:
		attempts += 1
		var w := randi_range(room_min_size, room_max_size)
		var h := randi_range(room_min_size, room_max_size)
		var x := randi_range(1, grid_width - w - 2)
		var y := randi_range(1, grid_height - h - 2)
		var rect := Rect2i(x, y, w, h)
		var inflated := Rect2i(x - 1, y - 1, w + 2, h + 2)
		var ok := true
		for other in rooms:
			if inflated.intersects(other):
				ok = false
				break
		if not ok:
			continue
		rooms.append(rect)
		for yy in range(rect.position.y, rect.position.y + rect.size.y):
			for xx in range(rect.position.x, rect.position.x + rect.size.x):
				_set_cell(xx, yy, Cell.FLOOR)


func _room_center(rect: Rect2i) -> Vector2i:
	return Vector2i(
		rect.position.x + rect.size.x / 2,
		rect.position.y + rect.size.y / 2
	)


func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	# L-shaped corridor
	if randf() < 0.5:
		_carve_h(a.x, b.x, a.y)
		_carve_v(a.y, b.y, b.x)
	else:
		_carve_v(a.y, b.y, a.x)
		_carve_h(a.x, b.x, b.y)


func _carve_h(x0: int, x1: int, y: int) -> void:
	var step := 1 if x1 >= x0 else -1
	for x in range(x0, x1 + step, step):
		if _get_cell(x, y) == Cell.WALL:
			_set_cell(x, y, Cell.FLOOR)


func _carve_v(y0: int, y1: int, x: int) -> void:
	var step := 1 if y1 >= y0 else -1
	for y in range(y0, y1 + step, step):
		if _get_cell(x, y) == Cell.WALL:
			_set_cell(x, y, Cell.FLOOR)


func _connect_rooms() -> void:
	if rooms.is_empty():
		return
	# Connect each room to the next (simple spanning path) + a few extra links
	var centers: Array[Vector2i] = []
	for r in rooms:
		centers.append(_room_center(r))
	for i in range(1, centers.size()):
		_carve_corridor(centers[i - 1], centers[i])
	# Extra loops for less linear maze
	var extra := mini(3, centers.size() - 1)
	for _i in range(extra):
		var a := centers[randi() % centers.size()]
		var b := centers[randi() % centers.size()]
		if a != b:
			_carve_corridor(a, b)


func _in_any_room(x: int, y: int) -> bool:
	var p := Vector2i(x, y)
	for r in rooms:
		if r.has_point(p):
			return true
	return false


func _mark_doors() -> void:
	# Door where floor has room-neighbor and corridor-neighbor
	for y in range(1, grid_height - 1):
		for x in range(1, grid_width - 1):
			if _get_cell(x, y) != Cell.FLOOR:
				continue
			if _in_any_room(x, y):
				continue
			# corridor cell adjacent to room
			var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			var touches_room := false
			for d in dirs:
				if _in_any_room(x + d.x, y + d.y) and _is_walkable(_get_cell(x + d.x, y + d.y)):
					touches_room = true
					break
			if touches_room:
				# only mark some as doors for readability
				if (x + y) % 2 == 0:
					_set_cell(x, y, Cell.DOOR)


func _floor_neighbors(x: int, y: int) -> int:
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _is_walkable(_get_cell(x + d.x, y + d.y)):
			n += 1
	return n


func _find_dead_ends() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(grid_height):
		for x in range(grid_width):
			if not _is_walkable(_get_cell(x, y)):
				continue
			if _in_any_room(x, y):
				continue
			if _floor_neighbors(x, y) == 1:
				result.append(Vector2i(x, y))
	return result


func _place_start_and_exit() -> void:
	if rooms.is_empty():
		start_cell = Vector2i(grid_width / 2, grid_height / 2)
		_set_cell(start_cell.x, start_cell.y, Cell.START)
		exit_cell = start_cell
		return
	# Start = first room center, Exit = farthest room center
	start_cell = _room_center(rooms[0])
	var best := rooms[0]
	var best_d := -1
	for r in rooms:
		var c := _room_center(r)
		var d: int = absi(c.x - start_cell.x) + absi(c.y - start_cell.y)
		if d > best_d:
			best_d = d
			best = r
	exit_cell = _room_center(best)
	_set_cell(start_cell.x, start_cell.y, Cell.START)
	_set_cell(exit_cell.x, exit_cell.y, Cell.EXIT)


func _place_chest_in_dead_end() -> void:
	var dead := _find_dead_ends()
	if dead.is_empty():
		# fallback: corner of a non-start room
		if rooms.size() > 1:
			var r: Rect2i = rooms[1]
			var cx := r.position.x + 1
			var cy := r.position.y + 1
			_set_cell(cx, cy, Cell.CHEST)
		return
	var pick: Vector2i = dead[randi() % dead.size()]
	_set_cell(pick.x, pick.y, Cell.CHEST)


func _place_encounters() -> void:
	if rooms.size() <= 1:
		return
	var candidates: Array[Rect2i] = []
	for i in range(1, rooms.size()):
		var c := _room_center(rooms[i])
		if c == exit_cell:
			continue
		candidates.append(rooms[i])
	candidates.shuffle()
	var n := mini(encounter_rooms, candidates.size())
	for i in range(n):
		var c := _room_center(candidates[i])
		if _get_cell(c.x, c.y) == Cell.FLOOR or _get_cell(c.x, c.y) == Cell.START:
			_set_cell(c.x, c.y, Cell.ENCOUNTER)


func _build_meshes() -> void:
	# Floor plane pieces + walls where adjacent is wall
	for y in range(grid_height):
		for x in range(grid_width):
			var cell: int = _get_cell(x, y)
			if not _is_walkable(cell):
				continue
			var world := cell_to_world(Vector2i(x, y))
			_add_box(
				geometry_root,
				world + Vector3(0, -0.15, 0),
				Vector3(cell_size, 0.3, cell_size),
				_floor_mat if cell != Cell.DOOR else _door_mat
			)
			# ceiling
			_add_box(
				geometry_root,
				world + Vector3(0, wall_height + 0.1, 0),
				Vector3(cell_size, 0.25, cell_size),
				_ceiling_mat
			)
			# walls on edges toward WALL cells
			_maybe_wall(x, y, 1, 0, world)
			_maybe_wall(x, y, -1, 0, world)
			_maybe_wall(x, y, 0, 1, world)
			_maybe_wall(x, y, 0, -1, world)

			# door arch visual
			if cell == Cell.DOOR:
				_add_box(
					geometry_root,
					world + Vector3(0, wall_height * 0.45, 0),
					Vector3(cell_size * 0.25, wall_height * 0.9, cell_size * 0.25),
					_door_mat
				)


func _maybe_wall(x: int, y: int, dx: int, dy: int, world: Vector3) -> void:
	if _is_walkable(_get_cell(x + dx, y + dy)):
		return
	var thickness := 0.35
	var size := Vector3(cell_size, wall_height, cell_size)
	var offset := Vector3(dx, 0, dy) * (cell_size * 0.5 - thickness * 0.5)
	if dx != 0:
		size = Vector3(thickness, wall_height, cell_size)
	else:
		size = Vector3(cell_size, wall_height, thickness)
	_add_box(geometry_root, world + offset + Vector3(0, wall_height * 0.5, 0), size, _wall_mat)


func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(col)
	parent.add_child(body)


func _spawn_torches() -> void:
	var placed := 0
	for y in range(grid_height):
		for x in range(grid_width):
			if not _is_walkable(_get_cell(x, y)):
				continue
			if (x + y * 3) % torch_spacing != 0:
				continue
			# prefer cells next to a wall
			if _floor_neighbors(x, y) >= 4 and not _in_any_room(x, y):
				continue
			var world := cell_to_world(Vector2i(x, y))
			_add_torch(world + Vector3(0.0, 1.6, 0.0))
			placed += 1
	print("[Dungeon] torches=%d" % placed)


func _add_torch(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	props_root.add_child(holder)

	var stick := MeshInstance3D.new()
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.04
	stick_mesh.bottom_radius = 0.05
	stick_mesh.height = 0.5
	stick.mesh = stick_mesh
	var stick_mat := StandardMaterial3D.new()
	stick_mat.albedo_color = Color(0.25, 0.15, 0.08)
	stick.material_override = stick_mat
	stick.position = Vector3(0, -0.15, 0)
	holder.add_child(stick)

	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.12
	flame_mesh.height = 0.22
	flame.mesh = flame_mesh
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.45, 0.1)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.5, 0.15)
	flame_mat.emission_energy_multiplier = 2.5
	flame.material_override = flame_mat
	flame.position = Vector3(0, 0.15, 0)
	holder.add_child(flame)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.35)
	light.light_energy = 1.4
	light.omni_range = 8.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.2, 0)
	holder.add_child(light)


func _spawn_props_and_entities() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			var cell: int = _get_cell(x, y)
			var world := cell_to_world(Vector2i(x, y))
			match cell:
				Cell.CHEST:
					_spawn_chest(world)
				Cell.ENCOUNTER:
					_spawn_encounter(world, "Pack_%d_%d" % [x, y])
				Cell.EXIT:
					_spawn_exit_marker(world)
				Cell.START:
					_spawn_start_marker(world)
				_:
					pass


func _spawn_chest(world: Vector3) -> void:
	var area := Area3D.new()
	area.position = world + Vector3(0, 0.4, 0)
	area.collision_layer = 4
	area.collision_mask = 2
	area.monitoring = true

	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.55, 0.6)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.5, 0.15)
	mat.metallic = 0.35
	mat.roughness = 0.45
	mesh.material_override = mat
	area.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.0, 1.2)
	col.shape = shape
	area.add_child(col)

	var label := Label3D.new()
	label.name = "Label3D"
	label.text = "Chest"
	label.position = Vector3(0, 0.7, 0)
	label.font_size = 32
	label.modulate = Color(1, 0.9, 0.5)
	area.add_child(label)

	area.set_script(load("res://scripts/chest.gd"))
	entities_root.add_child(area)


func _spawn_encounter(world: Vector3, pack_name: String) -> void:
	var area := Area3D.new()
	area.position = world + Vector3(0, 0.5, 0)
	area.collision_layer = 8
	area.collision_mask = 2
	var count := randi_range(2, 4)

	for i in range(count):
		var blob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.45
		sphere.height = 0.9
		blob.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.15, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.1, 0.15)
		mat.emission_energy_multiplier = 0.8
		blob.material_override = mat
		var angle := TAU * float(i) / float(count)
		blob.position = Vector3(cos(angle) * 0.7, 0.3, sin(angle) * 0.7)
		area.add_child(blob)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.6
	col.shape = shape
	area.add_child(col)

	var light := OmniLight3D.new()
	light.light_color = Color(0.9, 0.2, 0.25)
	light.light_energy = 0.9
	light.omni_range = 5.0
	area.add_child(light)

	var label := Label3D.new()
	label.text = "ENCOUNTER"
	label.position = Vector3(0, 1.4, 0)
	label.font_size = 28
	label.modulate = Color(1, 0.4, 0.4)
	area.add_child(label)

	area.set_script(load("res://scripts/encounter_placeholder.gd"))
	area.set("pack_name", pack_name)
	area.set("enemy_count", count)
	entities_root.add_child(area)


func _spawn_exit_marker(world: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = 0.15
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.15, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.2, 0.8)
	mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	mi.position = world + Vector3(0, 0.1, 0)
	props_root.add_child(mi)

	var label := Label3D.new()
	label.text = "EXIT / BOSS (soon)"
	label.position = world + Vector3(0, 1.5, 0)
	label.font_size = 36
	label.modulate = Color(0.75, 0.5, 1.0)
	props_root.add_child(label)


func _spawn_start_marker(world: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 0.1
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.45, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.7, 0.4)
	mat.emission_energy_multiplier = 1.0
	mi.material_override = mat
	mi.position = world + Vector3(0, 0.08, 0)
	props_root.add_child(mi)
