extends Node3D
## Corridor-first cave labyrinth with props (Phase 1+ visuals).

const TextureFactory = preload("res://scripts/texture_factory.gd")

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

@export var grid_width: int = 45
@export var grid_height: int = 45
@export var corridor_steps: int = 420
@export var branch_chance: float = 0.12
@export var room_count: int = 6
@export var room_min_size: int = 3
@export var room_max_size: int = 5
@export var cell_size: float = 3.2
@export var wall_height: float = 3.4
@export var encounter_rooms: int = 4
@export var torch_spacing: int = 4

var grid: Array = []
var rooms: Array[Rect2i] = []
var start_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var floor_cells: Array[Vector2i] = []

var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _ceiling_mat: StandardMaterial3D
var _rock_mat: StandardMaterial3D
var _crystal_mat: StandardMaterial3D
var _crystal_warm_mat: StandardMaterial3D

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
	floor_cells.clear()

	_init_grid()
	_carve_corridor_network()
	_place_rooms_on_corridors()
	_mark_doors()
	_place_start_and_exit()
	_place_chest_in_dead_end()
	_place_encounters()
	_collect_floor_cells()
	_build_cave_meshes()
	_spawn_torches()
	_spawn_decorations()
	_spawn_props_and_entities()

	var start_world := cell_to_world(start_cell) + Vector3(0, 0.1, 0)
	print("[Dungeon] seed=%s floors=%d rooms=%d start=%s exit=%s" % [
		seed_value, floor_cells.size(), rooms.size(), start_cell, exit_cell
	])
	generation_finished.emit(start_world)
	if GameState:
		GameState.dungeon_ready.emit(start_world)


func cell_to_world(cell: Vector2i) -> Vector3:
	var ox := -grid_width * cell_size * 0.5
	var oz := -grid_height * cell_size * 0.5
	return Vector3(ox + cell.x * cell_size + cell_size * 0.5, 0.0, oz + cell.y * cell_size + cell_size * 0.5)


func world_to_cell(world: Vector3) -> Vector2i:
	var ox := -grid_width * cell_size * 0.5
	var oz := -grid_height * cell_size * 0.5
	var x := int(floor((world.x - ox) / cell_size))
	var y := int(floor((world.z - oz) / cell_size))
	return Vector2i(clampi(x, 0, grid_width - 1), clampi(y, 0, grid_height - 1))


func is_walkable_cell(x: int, y: int) -> bool:
	return _is_walkable(_get_cell(x, y))


func get_cell_type(x: int, y: int) -> int:
	return _get_cell(x, y)


func _build_materials() -> void:
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.albedo_texture = TextureFactory.cave_floor(128)
	_floor_mat.albedo_color = Color(1.15, 1.15, 1.2)
	_floor_mat.roughness = 0.85
	_floor_mat.uv1_triplanar = true
	_floor_mat.uv1_scale = Vector3(0.4, 0.4, 0.4)

	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_texture = TextureFactory.cave_wall(128)
	_wall_mat.albedo_color = Color(1.2, 1.25, 1.2)
	_wall_mat.roughness = 0.82
	_wall_mat.uv1_triplanar = true
	_wall_mat.uv1_scale = Vector3(0.35, 0.35, 0.35)

	_ceiling_mat = StandardMaterial3D.new()
	_ceiling_mat.albedo_texture = TextureFactory.cave_ceiling(64)
	_ceiling_mat.albedo_color = Color(1.1, 1.15, 1.15)
	_ceiling_mat.roughness = 0.95
	_ceiling_mat.uv1_triplanar = true
	_ceiling_mat.uv1_scale = Vector3(0.3, 0.3, 0.3)

	_rock_mat = StandardMaterial3D.new()
	_rock_mat.albedo_texture = TextureFactory.cave_wall(64)
	_rock_mat.albedo_color = Color(1.1, 1.2, 1.15)
	_rock_mat.roughness = 0.9
	_rock_mat.uv1_triplanar = true
	_rock_mat.uv1_scale = Vector3(0.6, 0.6, 0.6)

	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = Color(0.55, 0.85, 1.0)
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Color(0.35, 0.7, 1.0)
	_crystal_mat.emission_energy_multiplier = 2.2
	_crystal_mat.roughness = 0.25
	_crystal_mat.metallic = 0.15

	_crystal_warm_mat = StandardMaterial3D.new()
	_crystal_warm_mat.albedo_color = Color(0.95, 0.55, 1.0)
	_crystal_warm_mat.emission_enabled = true
	_crystal_warm_mat.emission = Color(0.7, 0.3, 0.95)
	_crystal_warm_mat.emission_energy_multiplier = 1.8
	_crystal_warm_mat.roughness = 0.3


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
		row.fill(Cell.WALL)
		grid.append(row)


func _set_cell(x: int, y: int, value: int) -> void:
	if x < 1 or y < 1 or x >= grid_width - 1 or y >= grid_height - 1:
		return
	grid[y][x] = value


func _get_cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= grid_width or y >= grid_height:
		return Cell.WALL
	return grid[y][x]


func _is_walkable(v: int) -> bool:
	return v != Cell.WALL


func _carve_floor(x: int, y: int) -> void:
	if _get_cell(x, y) == Cell.WALL:
		_set_cell(x, y, Cell.FLOOR)


## Corridor-first: branching drunkard walk → maze-like tunnels
func _carve_corridor_network() -> void:
	var cx := grid_width / 2
	var cy := grid_height / 2
	var heads: Array[Vector2i] = [Vector2i(cx, cy)]
	_carve_floor(cx, cy)
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	var carved := 1
	var guard := 0
	while carved < corridor_steps and guard < corridor_steps * 8:
		guard += 1
		if heads.is_empty():
			# restart from random floor
			var fx := randi_range(2, grid_width - 3)
			var fy := randi_range(2, grid_height - 3)
			if _is_walkable(_get_cell(fx, fy)):
				heads.append(Vector2i(fx, fy))
			else:
				_carve_floor(fx, fy)
				heads.append(Vector2i(fx, fy))
				carved += 1
			continue

		var hi := randi() % heads.size()
		var pos: Vector2i = heads[hi]
		var dir: Vector2i = dirs[randi() % 4]
		# prefer continuing straight sometimes
		if randf() < 0.55 and heads.size() > 0:
			pass
		var steps := randi_range(2, 6)
		for _s in range(steps):
			pos += dir
			if pos.x < 2 or pos.y < 2 or pos.x >= grid_width - 2 or pos.y >= grid_height - 2:
				break
			if not _is_walkable(_get_cell(pos.x, pos.y)):
				carved += 1
			_carve_floor(pos.x, pos.y)
			# occasionally widen to 2 for "cave pocket"
			if randf() < 0.08:
				var side := Vector2i(-dir.y, dir.x)
				_carve_floor(pos.x + side.x, pos.y + side.y)

		heads[hi] = pos
		if randf() < branch_chance:
			heads.append(pos)
		if heads.size() > 10:
			heads.remove_at(randi() % heads.size())
		# turn
		if randf() < 0.4:
			dir = dirs[randi() % 4]


func _place_rooms_on_corridors() -> void:
	var attempts := 0
	while rooms.size() < room_count and attempts < 80:
		attempts += 1
		var w := randi_range(room_min_size, room_max_size)
		var h := randi_range(room_min_size, room_max_size)
		var x := randi_range(2, grid_width - w - 3)
		var y := randi_range(2, grid_height - h - 3)
		var rect := Rect2i(x, y, w, h)
		# must touch existing floor (corridor)
		var touches := false
		var overlaps_room := false
		for r in rooms:
			if Rect2i(x - 1, y - 1, w + 2, h + 2).intersects(r):
				overlaps_room = true
				break
		if overlaps_room:
			continue
		for yy in range(y, y + h):
			for xx in range(x, x + w):
				if _is_walkable(_get_cell(xx, yy)):
					touches = true
					break
			if touches:
				break
		if not touches and rooms.size() > 0:
			continue
		rooms.append(rect)
		for yy in range(y, y + h):
			for xx in range(x, x + w):
				_carve_floor(xx, yy)
		# ensure link to corridor center
		var center := Vector2i(x + w / 2, y + h / 2)
		_carve_toward_nearest_floor(center)


func _carve_toward_nearest_floor(from: Vector2i) -> void:
	# already on floor likely; carve a short spur if isolated
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p := from
		for _i in range(8):
			p += d
			if _is_walkable(_get_cell(p.x, p.y)):
				return
			_carve_floor(p.x, p.y)


func _in_any_room(x: int, y: int) -> bool:
	var p := Vector2i(x, y)
	for r in rooms:
		if r.has_point(p):
			return true
	return false


func _mark_doors() -> void:
	for y in range(1, grid_height - 1):
		for x in range(1, grid_width - 1):
			if _get_cell(x, y) != Cell.FLOOR:
				continue
			if _in_any_room(x, y):
				continue
			var n := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _is_walkable(_get_cell(x + d.x, y + d.y)):
					n += 1
			# choke point near room
			var near_room := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _in_any_room(x + d.x, y + d.y):
					near_room = true
			if near_room and n <= 3 and (x + y) % 3 == 0:
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
			if _floor_neighbors(x, y) == 1:
				result.append(Vector2i(x, y))
	return result


func _collect_floor_cells() -> void:
	floor_cells.clear()
	for y in range(grid_height):
		for x in range(grid_width):
			if _is_walkable(_get_cell(x, y)):
				floor_cells.append(Vector2i(x, y))


func _place_start_and_exit() -> void:
	_collect_floor_cells()
	if floor_cells.is_empty():
		start_cell = Vector2i(grid_width / 2, grid_height / 2)
		_set_cell(start_cell.x, start_cell.y, Cell.START)
		exit_cell = start_cell
		return
	# Start near center-ish, exit farthest
	var center := Vector2i(grid_width / 2, grid_height / 2)
	start_cell = floor_cells[0]
	var best_s := 999999
	for c in floor_cells:
		var d: int = absi(c.x - center.x) + absi(c.y - center.y)
		if d < best_s:
			best_s = d
			start_cell = c
	exit_cell = start_cell
	var best_e := -1
	for c in floor_cells:
		var d: int = absi(c.x - start_cell.x) + absi(c.y - start_cell.y)
		if d > best_e:
			best_e = d
			exit_cell = c
	_set_cell(start_cell.x, start_cell.y, Cell.START)
	_set_cell(exit_cell.x, exit_cell.y, Cell.EXIT)


func _place_chest_in_dead_end() -> void:
	var dead := _find_dead_ends()
	if dead.is_empty():
		if floor_cells.size() > 5:
			var c: Vector2i = floor_cells[randi() % floor_cells.size()]
			if c != start_cell and c != exit_cell:
				_set_cell(c.x, c.y, Cell.CHEST)
		return
	var pick: Vector2i = dead[randi() % dead.size()]
	if pick != start_cell and pick != exit_cell:
		_set_cell(pick.x, pick.y, Cell.CHEST)


func _place_encounters() -> void:
	var candidates: Array[Vector2i] = []
	for c in floor_cells if not floor_cells.is_empty() else _temp_collect():
		if c == start_cell or c == exit_cell:
			continue
		if _floor_neighbors(c.x, c.y) >= 3 or _in_any_room(c.x, c.y):
			candidates.append(c)
	if candidates.is_empty():
		_collect_floor_cells()
		for c in floor_cells:
			if c != start_cell and c != exit_cell:
				candidates.append(c)
	candidates.shuffle()
	var n := mini(encounter_rooms, candidates.size())
	var placed := 0
	var i := 0
	while placed < n and i < candidates.size():
		var c: Vector2i = candidates[i]
		i += 1
		# keep encounters spaced
		var ok := true
		for other in floor_cells:
			if _get_cell(other.x, other.y) == Cell.ENCOUNTER:
				if absi(other.x - c.x) + absi(other.y - c.y) < 6:
					ok = false
					break
		if not ok:
			continue
		_set_cell(c.x, c.y, Cell.ENCOUNTER)
		placed += 1


func _temp_collect() -> Array[Vector2i]:
	_collect_floor_cells()
	return floor_cells


func _build_cave_meshes() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			var cell: int = _get_cell(x, y)
			if not _is_walkable(cell):
				continue
			var world := cell_to_world(Vector2i(x, y))
			# floor slab
			_add_box(geometry_root, world + Vector3(0, -0.12, 0), Vector3(cell_size * 1.02, 0.28, cell_size * 1.02), _floor_mat)
			# slight floor rocks
			if (x * 5 + y * 3) % 7 == 0:
				_add_box(
					geometry_root,
					world + Vector3(randf_range(-0.6, 0.6), 0.05, randf_range(-0.6, 0.6)),
					Vector3(randf_range(0.25, 0.55), randf_range(0.08, 0.18), randf_range(0.25, 0.55)),
					_rock_mat,
					false
				)

			# vaulted-ish ceiling (main + edge drops)
			_add_box(geometry_root, world + Vector3(0, wall_height + 0.15, 0), Vector3(cell_size * 1.05, 0.35, cell_size * 1.05), _ceiling_mat)
			# ceiling dip / arch feel toward walls
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not _is_walkable(_get_cell(x + d.x, y + d.y)):
					var edge := Vector3(d.x, 0, d.y) * (cell_size * 0.28)
					_add_box(
						geometry_root,
						world + edge + Vector3(0, wall_height - 0.15, 0),
						Vector3(
							cell_size * 0.55 if d.x == 0 else 0.55,
							0.55,
							cell_size * 0.55 if d.y == 0 else 0.55
						),
						_ceiling_mat,
						false
					)

			_build_wall_with_bumps(x, y, 1, 0, world)
			_build_wall_with_bumps(x, y, -1, 0, world)
			_build_wall_with_bumps(x, y, 0, 1, world)
			_build_wall_with_bumps(x, y, 0, -1, world)

			# stalactites
			if (x + y * 2) % 5 == 0:
				var st := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.02
				cyl.bottom_radius = 0.12
				cyl.height = randf_range(0.35, 0.85)
				st.mesh = cyl
				st.material_override = _rock_mat
				st.position = world + Vector3(randf_range(-0.5, 0.5), wall_height - cyl.height * 0.5, randf_range(-0.5, 0.5))
				geometry_root.add_child(st)


func _build_wall_with_bumps(x: int, y: int, dx: int, dy: int, world: Vector3) -> void:
	if _is_walkable(_get_cell(x + dx, y + dy)):
		return
	var thickness := 0.55
	var size: Vector3
	var offset := Vector3(dx, 0, dy) * (cell_size * 0.5 - thickness * 0.35)
	if dx != 0:
		size = Vector3(thickness, wall_height, cell_size * 1.02)
	else:
		size = Vector3(cell_size * 1.02, wall_height, thickness)
	var wall_pos := world + offset + Vector3(0, wall_height * 0.5, 0)
	_add_box(geometry_root, wall_pos, size, _wall_mat)

	# organic bulges into corridor
	var bulge_count := randi_range(2, 4)
	for i in range(bulge_count):
		var along := (float(i) + 0.5) / float(bulge_count) - 0.5
		var lateral := Vector3(-dy, 0, dx) * along * cell_size * 0.7
		var h := randf_range(0.4, wall_height - 0.5)
		var into := Vector3(-dx, 0, -dy) * randf_range(0.15, 0.45)
		var bsize := Vector3(
			randf_range(0.35, 0.75),
			randf_range(0.35, 0.9),
			randf_range(0.35, 0.75)
		)
		_add_box(geometry_root, wall_pos + lateral + into + Vector3(0, h - wall_height * 0.5, 0), bsize, _rock_mat, false)


func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, collision: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if not collision:
		return
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.position = pos
	body.collision_layer = 1
	body.add_child(col)
	parent.add_child(body)


func _spawn_torches() -> void:
	var placed := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(grid_height):
		for x in range(grid_width):
			if not _is_walkable(_get_cell(x, y)):
				continue
			if (x * 7 + y * 13) % torch_spacing != 0:
				continue
			var wall_dirs: Array[Vector2i] = []
			for d in dirs:
				if not _is_walkable(_get_cell(x + d.x, y + d.y)):
					wall_dirs.append(d)
			if wall_dirs.is_empty():
				continue
			var d: Vector2i = wall_dirs[placed % wall_dirs.size()]
			var world := cell_to_world(Vector2i(x, y))
			var wall_dist := cell_size * 0.5 - 0.35
			var pos := world + Vector3(d.x * wall_dist, 1.5, d.y * wall_dist)
			_add_torch(pos, d)
			placed += 1
	print("[Dungeon] torches=%d" % placed)


func _add_torch(pos: Vector3, wall_dir: Vector2i) -> void:
	var holder := Node3D.new()
	holder.position = pos
	if wall_dir.x != 0:
		holder.rotation.y = PI * 0.5 if wall_dir.x > 0 else -PI * 0.5
	else:
		holder.rotation.y = 0.0 if wall_dir.y > 0 else PI
	props_root.add_child(holder)

	var stick := MeshInstance3D.new()
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.04
	stick_mesh.bottom_radius = 0.05
	stick_mesh.height = 0.5
	stick.mesh = stick_mesh
	var stick_mat := StandardMaterial3D.new()
	stick_mat.albedo_color = Color(0.35, 0.2, 0.1)
	stick.material_override = stick_mat
	stick.rotation.x = deg_to_rad(20)
	stick.position = Vector3(0, -0.05, -0.1)
	holder.add_child(stick)

	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.14
	flame_mesh.height = 0.28
	flame.mesh = flame_mesh
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.55, 0.15)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.6, 0.2)
	flame_mat.emission_energy_multiplier = 4.5
	flame.material_override = flame_mat
	flame.position = Vector3(0, 0.22, -0.2)
	holder.add_child(flame)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 2.4
	light.omni_range = 10.0
	light.omni_attenuation = 0.9
	light.position = Vector3(0, 0.25, -0.3)
	holder.add_child(light)


func _spawn_decorations() -> void:
	var n := 0
	for cell in floor_cells:
		var x := cell.x
		var y := cell.y
		if _get_cell(x, y) == Cell.START:
			continue
		var h := (x * 31 + y * 17) % 11
		var world := cell_to_world(cell)
		# rock pile near walls
		if h == 0 or h == 1:
			var wd := _first_wall_dir(x, y)
			if wd != Vector2i.ZERO:
				var base := world + Vector3(wd.x * 0.9, 0.15, wd.y * 0.9)
				for i in range(randi_range(2, 4)):
					_add_box(
						props_root,
						base + Vector3(randf_range(-0.25, 0.25), randf_range(0.0, 0.2), randf_range(-0.25, 0.25)),
						Vector3(randf_range(0.25, 0.5), randf_range(0.2, 0.45), randf_range(0.25, 0.5)),
						_rock_mat,
						false
					)
				n += 1
		# crystal cluster
		if h == 2 or h == 3:
			var wd2 := _first_wall_dir(x, y)
			var base2 := world + Vector3(wd2.x * 0.85, 0.2, wd2.y * 0.85) if wd2 != Vector2i.ZERO else world + Vector3(0.8, 0.2, 0)
			_spawn_crystal_cluster(base2, h == 3)
			n += 1
		# blue brazier rare
		if h == 4 and _floor_neighbors(x, y) >= 3:
			_spawn_brazier(world + Vector3(0.7, 0.0, -0.5))
			n += 1
	print("[Dungeon] decorations~%d clusters" % n)


func _first_wall_dir(x: int, y: int) -> Vector2i:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _is_walkable(_get_cell(x + d.x, y + d.y)):
			return d
	return Vector2i.ZERO


func _spawn_crystal_cluster(base: Vector3, warm: bool) -> void:
	var mat := _crystal_warm_mat if warm else _crystal_mat
	for i in range(randi_range(2, 5)):
		var mi := MeshInstance3D.new()
		var prism := CylinderMesh.new()
		prism.top_radius = 0.02
		prism.bottom_radius = randf_range(0.08, 0.16)
		prism.height = randf_range(0.4, 1.1)
		mi.mesh = prism
		mi.material_override = mat
		mi.position = base + Vector3(randf_range(-0.2, 0.2), prism.height * 0.5, randf_range(-0.2, 0.2))
		mi.rotation_degrees = Vector3(randf_range(-12, 12), randf_range(0, 360), randf_range(-12, 12))
		props_root.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.8, 1.0) if not warm else Color(0.85, 0.45, 1.0)
	light.light_energy = 1.3
	light.omni_range = 5.5
	light.position = base + Vector3(0, 0.6, 0)
	props_root.add_child(light)


func _spawn_brazier(pos: Vector3) -> void:
	var bowl := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.2
	cyl.height = 0.35
	bowl.mesh = cyl
	bowl.material_override = _rock_mat
	bowl.position = pos + Vector3(0, 0.2, 0)
	props_root.add_child(bowl)
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.35
	flame.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.4, 0.75, 1.0)
	fm.emission_enabled = true
	fm.emission = Color(0.3, 0.7, 1.0)
	fm.emission_energy_multiplier = 3.5
	flame.material_override = fm
	flame.position = pos + Vector3(0, 0.5, 0)
	props_root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.75, 1.0)
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position = pos + Vector3(0, 0.55, 0)
	props_root.add_child(light)


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
	mat.albedo_color = Color(0.8, 0.55, 0.2)
	mat.metallic = 0.45
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.3, 0.05)
	mat.emission_energy_multiplier = 0.6
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
	label.position = Vector3(0, 0.75, 0)
	label.font_size = 28
	label.modulate = Color(1, 0.9, 0.5)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(label)

	area.set_script(load("res://scripts/chest.gd"))
	entities_root.add_child(area)


func _spawn_encounter(world: Vector3, pack_name: String) -> void:
	var area := Area3D.new()
	area.position = world + Vector3(0, 0.5, 0)
	area.collision_layer = 8
	area.collision_mask = 2
	var count := randi_range(2, 3)

	# floating skull marker (like ref)
	var skull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.55
	skull.mesh = sm
	var skmat := StandardMaterial3D.new()
	skmat.albedo_color = Color(0.85, 0.82, 0.75)
	skmat.emission_enabled = true
	skmat.emission = Color(0.9, 0.85, 0.4)
	skmat.emission_energy_multiplier = 1.2
	skull.material_override = skmat
	skull.position = Vector3(0, 1.1, 0)
	area.add_child(skull)

	for i in range(count):
		var blob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.4
		sphere.height = 0.75
		blob.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.18, 0.22)
		mat.emission_enabled = true
		mat.emission = Color(0.55, 0.12, 0.15)
		mat.emission_energy_multiplier = 0.7
		blob.material_override = mat
		var angle := TAU * float(i) / float(count)
		blob.position = Vector3(cos(angle) * 0.75, 0.25, sin(angle) * 0.75)
		area.add_child(blob)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.5
	col.shape = shape
	area.add_child(col)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position = Vector3(0, 1.1, 0)
	area.add_child(light)

	var label := Label3D.new()
	label.text = "ENCOUNTER"
	label.position = Vector3(0, 1.7, 0)
	label.font_size = 24
	label.modulate = Color(1, 0.85, 0.4)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(label)

	area.set_script(load("res://scripts/encounter_placeholder.gd"))
	area.set("pack_name", pack_name)
	area.set("enemy_count", count)
	entities_root.add_child(area)


func _spawn_exit_marker(world: Vector3) -> void:
	# campfire-like exit
	for i in range(5):
		var rock := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 0.18, 0.25)
		rock.mesh = box
		rock.material_override = _rock_mat
		var a := TAU * float(i) / 5.0
		rock.position = world + Vector3(cos(a) * 0.45, 0.1, sin(a) * 0.45)
		props_root.add_child(rock)
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	flame.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.45, 0.1)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.5, 0.15)
	fm.emission_energy_multiplier = 3.5
	flame.material_override = fm
	flame.position = world + Vector3(0, 0.45, 0)
	props_root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 2.5
	light.omni_range = 9.0
	light.position = world + Vector3(0, 0.6, 0)
	props_root.add_child(light)
	var label := Label3D.new()
	label.text = "EXIT"
	label.position = world + Vector3(0, 1.4, 0)
	label.font_size = 32
	label.modulate = Color(1.0, 0.7, 0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	props_root.add_child(label)


func _spawn_start_marker(world: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.55
	cyl.height = 0.08
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.7, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 0.5)
	mat.emission_energy_multiplier = 1.2
	mi.material_override = mat
	mi.position = world + Vector3(0, 0.05, 0)
	props_root.add_child(mi)
