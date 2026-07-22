extends Node3D
class_name DungeonGenerator
## Corridor-first cave labyrinth with props (Phase 1+ visuals).

const TextureFactory = preload("res://scripts/texture_factory.gd")
const TorchSprites = preload("res://scripts/torch_sprites.gd")

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
## Maze corridors only (width 1) + few small chambers — competitor "corridor map" feel.
@export var room_count: int = 4
@export var room_min_size: int = 2
@export var room_max_size: int = 3
@export var cell_size: float = 3.0
@export var wall_height: float = 3.2
@export var encounter_rooms: int = 4
## Lower = denser wall torches (1 = every walkable cell with a wall).
@export var torch_spacing: int = 2
@export var extra_loops: int = 10

var grid: Array = []
var rooms: Array[Rect2i] = []
var start_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var floor_cells: Array[Vector2i] = []

var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _ceiling_mat: StandardMaterial3D
var _crystal_sprite_mat: StandardMaterial3D
var _rock_sprite_mat: StandardMaterial3D

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

	# Rebuild cave textures/materials so R regenerates new rock look
	_build_materials()
	_clear_children(geometry_root)
	_clear_children(props_root)
	_clear_children(entities_root)
	rooms.clear()
	floor_cells.clear()

	_init_grid()
	_carve_maze_corridors()
	_add_corridor_loops()
	_place_small_chambers()
	_mark_doors()
	_place_start_and_exit()
	_place_chest_in_dead_end()
	_place_encounters()
	_collect_floor_cells()
	_build_art_corridor()
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
	# Readable cave: darker than neon mint, still visible without a torch in face
	_floor_mat = _make_surface_mat(TextureFactory.cave_floor(320), Color(0.88, 0.95, 1.0), 0.9)
	_wall_mat = _make_surface_mat(TextureFactory.cave_wall(320), Color(0.92, 1.0, 0.98), 0.84)
	_ceiling_mat = _make_surface_mat(TextureFactory.cave_ceiling(320), Color(0.7, 0.82, 0.8), 0.93)
	_crystal_sprite_mat = null
	_rock_sprite_mat = null


func _make_surface_mat(tex: Texture2D, albedo: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL  # receive torch / OmniLight
	m.albedo_texture = tex
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = 0.0
	m.specular = 0.25
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.texture_repeat = true
	m.uv1_scale = Vector3(1.0, 1.0, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.vertex_color_use_as_albedo = true  # soft joint AO only
	return m


func _make_skirting_mat() -> StandardMaterial3D:
	## Soft dark veil for floor–wall joint (competitor contact shadow).
	## Alpha + unshaded so it reads even with strong ambient/glow.
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.01, 0.03, 0.05, 1.0)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	m.no_depth_test = false
	m.render_priority = 1
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return m


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


## Perfect-ish maze on odd cells → only width-1 corridors (T-junctions, dead ends).
func _carve_maze_corridors() -> void:
	# Work on odd coordinates so walls stay between paths
	var start := Vector2i(1 + (grid_width / 2) % 2, 1 + (grid_height / 2) % 2)
	if start.x < 1:
		start.x = 1
	if start.y < 1:
		start.y = 1
	if start.x % 2 == 0:
		start.x -= 1
	if start.y % 2 == 0:
		start.y -= 1
	start.x = clampi(start.x, 1, grid_width - 2)
	start.y = clampi(start.y, 1, grid_height - 2)
	if start.x % 2 == 0:
		start.x = 1
	if start.y % 2 == 0:
		start.y = 1

	var stack: Array[Vector2i] = [start]
	_carve_floor(start.x, start.y)
	var dirs: Array[Vector2i] = [
		Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0)
	]

	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var options: Array[Vector2i] = []
		for d in dirs:
			var n: Vector2i = cur + d
			if n.x < 1 or n.y < 1 or n.x >= grid_width - 1 or n.y >= grid_height - 1:
				continue
			if _get_cell(n.x, n.y) == Cell.WALL:
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var d: Vector2i = options[randi() % options.size()]
		var between: Vector2i = cur + d / 2
		var nxt: Vector2i = cur + d
		_carve_floor(between.x, between.y)
		_carve_floor(nxt.x, nxt.y)
		stack.append(nxt)


## Punch a few extra walls so map has loops (not pure dead-end only).
func _add_corridor_loops() -> void:
	var candidates: Array[Vector2i] = []
	for y in range(2, grid_height - 2):
		for x in range(2, grid_width - 2):
			if _get_cell(x, y) != Cell.WALL:
				continue
			# wall between two floors (horizontal or vertical corridor bridge)
			var h := _is_walkable(_get_cell(x - 1, y)) and _is_walkable(_get_cell(x + 1, y))
			var v := _is_walkable(_get_cell(x, y - 1)) and _is_walkable(_get_cell(x, y + 1))
			if h or v:
				candidates.append(Vector2i(x, y))
	candidates.shuffle()
	var n := mini(extra_loops, candidates.size())
	for i in range(n):
		_carve_floor(candidates[i].x, candidates[i].y)


## Small 2×2 / 3×3 chambers on corridor nodes (not big open rooms).
func _place_small_chambers() -> void:
	_collect_floor_cells()
	var nodes: Array[Vector2i] = []
	for c in floor_cells:
		if _floor_neighbors(c.x, c.y) >= 3:
			nodes.append(c)
	nodes.shuffle()
	var attempts := 0
	var i := 0
	while rooms.size() < room_count and attempts < 60 and i < nodes.size():
		attempts += 1
		var c: Vector2i = nodes[i]
		i += 1
		var w := randi_range(room_min_size, room_max_size)
		var h := randi_range(room_min_size, room_max_size)
		var x := c.x - w / 2
		var y := c.y - h / 2
		x = clampi(x, 1, grid_width - w - 2)
		y = clampi(y, 1, grid_height - h - 2)
		var rect := Rect2i(x, y, w, h)
		var overlaps := false
		for r in rooms:
			if Rect2i(x - 2, y - 2, w + 4, h + 4).intersects(r):
				overlaps = true
				break
		if overlaps:
			continue
		rooms.append(rect)
		for yy in range(y, y + h):
			for xx in range(x, x + w):
				_carve_floor(xx, yy)


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


## Sealed tunnel: single merged floor/ceiling (no cell seams) + wall panels.
func _build_art_corridor() -> void:
	var skirt_mat := _make_skirting_mat()
	_build_merged_floor()
	_build_merged_ceiling()
	for y in range(grid_height):
		for x in range(grid_width):
			if not _is_walkable(_get_cell(x, y)):
				continue
			var world := cell_to_world(Vector2i(x, y))
			_add_solid_box(world + Vector3(0, -0.3, 0), Vector3(cell_size * 1.05, 0.55, cell_size * 1.05))
			_add_solid_box(world + Vector3(0, wall_height + 0.5, 0), Vector3(cell_size * 1.05, 0.55, cell_size * 1.05))
			_maybe_cave_wall(x, y, 1, 0, world, skirt_mat)
			_maybe_cave_wall(x, y, -1, 0, world, skirt_mat)
			_maybe_cave_wall(x, y, 0, 1, world, skirt_mat)
			_maybe_cave_wall(x, y, 0, -1, world, skirt_mat)


## One continuous cave floor — uneven rock, wall rise, world UV (no tile seams).
func _build_merged_floor() -> void:
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 4  # enough for cave undulation
	var half := cell_size * 0.5
	var uv_s := 1.0 / cell_size
	for cell in floor_cells:
		var world := cell_to_world(cell)
		var x := cell.x
		var y := cell.y
		var wall_px := not _is_walkable(_get_cell(x + 1, y))
		var wall_nx := not _is_walkable(_get_cell(x - 1, y))
		var wall_pz := not _is_walkable(_get_cell(x, y + 1))
		var wall_nz := not _is_walkable(_get_cell(x, y - 1))
		for j in range(segs):
			for i in range(segs):
				var u0 := float(i) / float(segs)
				var v0 := float(j) / float(segs)
				var u1 := float(i + 1) / float(segs)
				var v1 := float(j + 1) / float(segs)
				var p00 := _floor_pt(world, u0, v0, half, wall_px, wall_nx, wall_pz, wall_nz)
				var p10 := _floor_pt(world, u1, v0, half, wall_px, wall_nx, wall_pz, wall_nz)
				var p11 := _floor_pt(world, u1, v1, half, wall_px, wall_nx, wall_pz, wall_nz)
				var p01 := _floor_pt(world, u0, v1, half, wall_px, wall_nx, wall_pz, wall_nz)
				var a00 := _floor_ao(u0, v0, wall_px, wall_nx, wall_pz, wall_nz)
				var a10 := _floor_ao(u1, v0, wall_px, wall_nx, wall_pz, wall_nz)
				var a11 := _floor_ao(u1, v1, wall_px, wall_nx, wall_pz, wall_nz)
				var a01 := _floor_ao(u0, v1, wall_px, wall_nx, wall_pz, wall_nz)
				_tri_ao(st, p00, p10, p11, Vector3.UP,
					p00.x * uv_s, p00.z * uv_s, p10.x * uv_s, p10.z * uv_s, p11.x * uv_s, p11.z * uv_s,
					a00, a10, a11)
				_tri_ao(st, p00, p11, p01, Vector3.UP,
					p00.x * uv_s, p00.z * uv_s, p11.x * uv_s, p11.z * uv_s, p01.x * uv_s, p01.z * uv_s,
					a00, a11, a01)
	st.generate_normals()
	mi.mesh = st.commit()
	mi.material_override = _floor_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry_root.add_child(mi)


func _floor_pt(
	world: Vector3, u: float, v: float, half: float,
	wall_px: bool, wall_nx: bool, wall_pz: bool, wall_nz: bool
) -> Vector3:
	var x := (u - 0.5) * 2.0 * half
	var z := (v - 0.5) * 2.0 * half
	var wx := world.x + x
	var wz := world.z + z
	# Cave floor: rocky undulation (world-stable → seamless between cells)
	var h := _cave_noise(wx, wz, 0) * 0.07 + _cave_noise(wx * 2.1, wz * 2.0, 5) * 0.03
	# Rise toward walls (trough in corridor center)
	var rise := 0.0
	if wall_px:
		rise = maxf(rise, pow(u, 1.5) * 0.12)
	if wall_nx:
		rise = maxf(rise, pow(1.0 - u, 1.5) * 0.12)
	if wall_pz:
		rise = maxf(rise, pow(v, 1.5) * 0.12)
	if wall_nz:
		rise = maxf(rise, pow(1.0 - v, 1.5) * 0.12)
	return world + Vector3(x, h + rise, z)


func _floor_ao(u: float, v: float, wall_px: bool, wall_nx: bool, wall_pz: bool, wall_nz: bool) -> float:
	var ao := 1.0
	var fall := 0.55
	if wall_px:
		ao = minf(ao, _edge_ao(1.0 - u, fall))
	if wall_nx:
		ao = minf(ao, _edge_ao(u, fall))
	if wall_pz:
		ao = minf(ao, _edge_ao(1.0 - v, fall))
	if wall_nz:
		ao = minf(ao, _edge_ao(v, fall))
	return ao


func _edge_ao(dist_from_wall: float, falloff: float) -> float:
	var t := clampf(dist_from_wall / falloff, 0.0, 1.0)
	t = 1.0 - (1.0 - t) * (1.0 - t)
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(0.14, 1.0, t)


## Multi-octave rock noise in ~[-1, 1], world-stable (seed only biases phase).
func _cave_noise(x: float, z: float, seed_h: int) -> float:
	var s := float(seed_h) * 0.17
	var n := sin(x * 1.15 + s) * cos(z * 0.97 + s * 0.6)
	n += sin(x * 2.4 + z * 1.6 + s * 1.3) * 0.45
	n += sin(x * 4.8 - z * 3.7 + s * 2.1) * 0.22
	n += cos(x * 0.55 - z * 0.7 + s) * 0.35
	return clampf(n * 0.55, -1.0, 1.0)


## Organic cave ceiling: rock undulation + hanging dips (world noise, no cell-grid seams).
func _build_merged_ceiling() -> void:
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 5
	var half := cell_size * 0.5 + 0.1
	var uv_s := 1.0 / cell_size
	for cell in floor_cells:
		var world := cell_to_world(cell)
		var cx := cell.x
		var cy := cell.y
		var wall_px := not _is_walkable(_get_cell(cx + 1, cy))
		var wall_nx := not _is_walkable(_get_cell(cx - 1, cy))
		var wall_pz := not _is_walkable(_get_cell(cx, cy + 1))
		var wall_nz := not _is_walkable(_get_cell(cx, cy - 1))
		for j in range(segs):
			for i in range(segs):
				var u0 := float(i) / float(segs)
				var v0 := float(j) / float(segs)
				var u1 := float(i + 1) / float(segs)
				var v1 := float(j + 1) / float(segs)
				var p00 := _ceil_pt(world, u0, v0, half, wall_px, wall_nx, wall_pz, wall_nz)
				var p10 := _ceil_pt(world, u1, v0, half, wall_px, wall_nx, wall_pz, wall_nz)
				var p11 := _ceil_pt(world, u1, v1, half, wall_px, wall_nx, wall_pz, wall_nz)
				var p01 := _ceil_pt(world, u0, v1, half, wall_px, wall_nx, wall_pz, wall_nz)
				var e00 := _ceil_ao(u0, v0, wall_px, wall_nx, wall_pz, wall_nz)
				var e10 := _ceil_ao(u1, v0, wall_px, wall_nx, wall_pz, wall_nz)
				var e11 := _ceil_ao(u1, v1, wall_px, wall_nx, wall_pz, wall_nz)
				var e01 := _ceil_ao(u0, v1, wall_px, wall_nx, wall_pz, wall_nz)
				_tri_ao(st, p00, p11, p10, Vector3.DOWN,
					p00.x * uv_s, p00.z * uv_s, p11.x * uv_s, p11.z * uv_s, p10.x * uv_s, p10.z * uv_s,
					e00, e11, e10)
				_tri_ao(st, p00, p01, p11, Vector3.DOWN,
					p00.x * uv_s, p00.z * uv_s, p01.x * uv_s, p01.z * uv_s, p11.x * uv_s, p11.z * uv_s,
					e00, e01, e11)
	st.generate_normals()
	mi.mesh = st.commit()
	mi.material_override = _ceiling_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry_root.add_child(mi)


func _ceil_pt(
	world: Vector3, u: float, v: float, half: float,
	wall_px: bool, wall_nx: bool, wall_pz: bool, wall_nz: bool
) -> Vector3:
	var x := (u - 0.5) * 2.0 * half
	var z := (v - 0.5) * 2.0 * half
	var wx := world.x + x
	var wz := world.z + z
	# Strong cave rock + hanging stalactite dips (world-stable)
	var n := _cave_noise(wx, wz, 11)
	var n2 := _cave_noise(wx * 1.6 + 2.0, wz * 1.5, 19)
	var n3 := _cave_noise(wx * 3.0, wz * 2.8, 31)
	var hang := maxf(0.0, n) * 0.22 + maxf(0.0, n2) * 0.12 + maxf(0.0, n3) * 0.06
	# Vault lower near walls (tube roof) without per-cell grid seams
	var wall_t := 0.0
	if wall_px:
		wall_t = maxf(wall_t, u)
	if wall_nx:
		wall_t = maxf(wall_t, 1.0 - u)
	if wall_pz:
		wall_t = maxf(wall_t, v)
	if wall_nz:
		wall_t = maxf(wall_t, 1.0 - v)
	var vault := wall_t * wall_t * 0.35
	var y := wall_height + 0.28 - vault - hang + n2 * 0.04
	return world + Vector3(x, y, z)


func _ceil_ao(u: float, v: float, wall_px: bool, wall_nx: bool, wall_pz: bool, wall_nz: bool) -> float:
	var ao := 1.0
	if wall_px:
		ao = minf(ao, lerpf(0.75, 1.0, 1.0 - u))
	if wall_nx:
		ao = minf(ao, lerpf(0.75, 1.0, u))
	if wall_pz:
		ao = minf(ao, lerpf(0.75, 1.0, 1.0 - v))
	if wall_nz:
		ao = minf(ao, lerpf(0.75, 1.0, v))
	return ao


func _maybe_cave_wall(x: int, y: int, dx: int, dy: int, world: Vector3, skirt_mat: Material) -> void:
	if _is_walkable(_get_cell(x + dx, y + dy)):
		return
	var into := Vector3(-float(dx), 0.0, -float(dy))
	var edge := cell_size * 0.5
	var base := world + Vector3(float(dx) * edge, 0.0, float(dy) * edge)
	_add_cave_wall_mesh(base, into)
	_add_floor_wall_skirting(base, into, skirt_mat)
	var col_size := Vector3(cell_size * 1.12, wall_height + 0.35, 0.5) if absf(into.z) > 0.5 else Vector3(0.5, wall_height + 0.35, cell_size * 1.12)
	_add_solid_box(base - into * 0.08 + Vector3(0, wall_height * 0.5, 0), col_size)


func _add_floor_wall_skirting(base: Vector3, face_into: Vector3, mat: Material) -> void:
	## Soft dark veil — 2-step falloff so the band reads bigger.
	var width := cell_size  # exact cell — no corner overshoot on skirt
	var depth := 0.95  # wide onto floor
	var height := 0.55  # up the wall
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var mid_d := depth * 0.4
	var mid_h := height * 0.4
	# Floor: wall → mid (strong) → outer (fade out)
	var f0 := Vector3(-hw, 0.012, 0.0)
	var f1 := Vector3(hw, 0.012, 0.0)
	var f2 := Vector3(hw, 0.012, mid_d)
	var f3 := Vector3(-hw, 0.012, mid_d)
	var f4 := Vector3(hw, 0.012, depth)
	var f5 := Vector3(-hw, 0.012, depth)
	_tri_alpha(st, f0, f1, f2, Vector3.UP, 0.92, 0.92, 0.55)
	_tri_alpha(st, f0, f2, f3, Vector3.UP, 0.92, 0.55, 0.55)
	_tri_alpha(st, f3, f2, f4, Vector3.UP, 0.55, 0.55, 0.0)
	_tri_alpha(st, f3, f4, f5, Vector3.UP, 0.55, 0.0, 0.0)
	# Wall base: floor → mid → fade
	var w0 := Vector3(-hw, 0.0, 0.01)
	var w1 := Vector3(hw, 0.0, 0.01)
	var w2 := Vector3(hw, mid_h, 0.01)
	var w3 := Vector3(-hw, mid_h, 0.01)
	var w4 := Vector3(hw, height, 0.01)
	var w5 := Vector3(-hw, height, 0.01)
	_tri_alpha(st, w0, w1, w2, Vector3(0, 0, 1), 0.9, 0.9, 0.5)
	_tri_alpha(st, w0, w2, w3, Vector3(0, 0, 1), 0.9, 0.5, 0.5)
	_tri_alpha(st, w3, w2, w4, Vector3(0, 0, 1), 0.5, 0.5, 0.0)
	_tri_alpha(st, w3, w4, w5, Vector3(0, 0, 1), 0.5, 0.0, 0.0)

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var yaw := 0.0
	if absf(face_into.x) > 0.5:
		yaw = -PI * 0.5 if face_into.x > 0.0 else PI * 0.5
	else:
		yaw = 0.0 if face_into.z < 0.0 else PI
	mi.transform = Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), base + face_into * 0.02)
	geometry_root.add_child(mi)


func _tri_alpha(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, aa: float, ab: float, ac: float) -> void:
	st.set_normal(n)
	st.set_color(Color(1, 1, 1, aa))
	st.add_vertex(a)
	st.set_normal(n)
	st.set_color(Color(1, 1, 1, ab))
	st.add_vertex(b)
	st.set_normal(n)
	st.set_color(Color(1, 1, 1, ac))
	st.add_vertex(c)


func _add_cave_wall_mesh(base: Vector3, face_into: Vector3) -> void:
	## Organic cave wall: tube bulge + rock noise. World UV / noise = no seams.
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs_w := 6
	var segs_h := 7
	var width := cell_size + 0.08
	var right := Vector3(-face_into.z, 0.0, face_into.x)
	var uv_s := 1.0 / cell_size

	for j in range(segs_h):
		for i in range(segs_w):
			var u0 := float(i) / float(segs_w)
			var v0 := float(j) / float(segs_h)
			var u1 := float(i + 1) / float(segs_w)
			var v1 := float(j + 1) / float(segs_h)
			var p00 := _wall_pt(base, face_into, right, u0, v0, width)
			var p10 := _wall_pt(base, face_into, right, u1, v0, width)
			var p11 := _wall_pt(base, face_into, right, u1, v1, width)
			var p01 := _wall_pt(base, face_into, right, u0, v1, width)
			var a00 := _wall_ao(u0, v0)
			var a10 := _wall_ao(u1, v0)
			var a11 := _wall_ao(u1, v1)
			var a01 := _wall_ao(u0, v1)
			var ua0 := (base + right * ((u0 - 0.5) * width)).dot(right) * uv_s
			var ua1 := (base + right * ((u1 - 0.5) * width)).dot(right) * uv_s
			var va0 := v0 * (wall_height / cell_size)
			var va1 := v1 * (wall_height / cell_size)
			_tri_ao(st, p00, p10, p11, face_into, ua0, va0, ua1, va0, ua1, va1, a00, a10, a11)
			_tri_ao(st, p00, p11, p01, face_into, ua0, va0, ua1, va1, ua0, va1, a00, a11, a01)
	st.generate_normals()
	mi.mesh = st.commit()
	mi.material_override = _wall_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry_root.add_child(mi)


func _wall_pt(
	base: Vector3, face_into: Vector3, right: Vector3,
	u: float, v: float, width: float
) -> Vector3:
	var along := (u - 0.5) * width
	var h := -0.18 + v * (wall_height + 0.42)
	var pos := base + right * along + Vector3.UP * h
	# Soft at panel corners so seams don't fin; mid-wall gets full relief
	var edge_w := sin(clampf(u, 0.0, 1.0) * PI)
	edge_w = edge_w * edge_w
	var amp := lerpf(0.2, 1.0, edge_w)
	# Mild tube + stronger angular rock facets (stepped noise = cave blocks)
	var tube := sin(v * PI) * 0.18 + pow(v, 1.7) * 0.14
	var n1 := _cave_noise(pos.x * 0.7 + pos.z * 0.7, h * 1.1, 3)
	var n2 := _cave_noise(along * 1.1 + pos.x * 0.15, h * 1.7, 8)
	var n3 := _cave_noise(along * 2.6, h * 3.2, 17)
	# Quantize mid frequencies → flatter angular planes instead of soft blobs
	var facet := floor(n2 * 4.0) / 4.0
	var rock := n1 * 0.1 + facet * 0.16 + n3 * 0.07
	# Occasional hard ledge shelf
	var ledge := maxf(0.0, facet) * sin(v * PI) * 0.14
	var push := (tube + rock + ledge) * amp
	return pos + face_into * (push - 0.015)


## Wall base + roof darkening (no vertical edge dark bands that look like seams).
func _wall_ao(u: float, v: float) -> float:
	var floor_t := clampf(v / 0.35, 0.0, 1.0)
	floor_t = floor_t * floor_t * (3.0 - 2.0 * floor_t)
	# Darker contact near floor — deep cave, not lit hallway
	var ao := lerpf(0.08, 0.92, floor_t)
	var roof_t := clampf((1.0 - v) / 0.22, 0.0, 1.0)
	roof_t = roof_t * roof_t
	ao *= lerpf(0.55, 1.0, 1.0 - roof_t)
	return ao


func _tri_ao(
	st: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3,
	n: Vector3,
	ua: float, va: float, ub: float, vb: float, uc: float, vc: float,
	ao_a: float, ao_b: float, ao_c: float
) -> void:
	st.set_normal(n)
	st.set_color(Color(ao_a, ao_a, ao_a))
	st.set_uv(Vector2(ua, va))
	st.add_vertex(a)
	st.set_normal(n)
	st.set_color(Color(ao_b, ao_b, ao_b))
	st.set_uv(Vector2(ub, vb))
	st.add_vertex(b)
	st.set_normal(n)
	st.set_color(Color(ao_c, ao_c, ao_c))
	st.set_uv(Vector2(uc, vc))
	st.add_vertex(c)


func _add_solid_box(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(col)
	geometry_root.add_child(body)


func _add_textured_box(pos: Vector3, size: Vector3, mat: Material, collision: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry_root.add_child(mi)
	if collision:
		_add_solid_box(pos, size)


func _add_plane(
	parent: Node3D,
	pos: Vector3,
	size: Vector2,
	mat: Material,
	rot_deg: Vector3,
	collision: bool = false,
	col_size: Vector3 = Vector3.ZERO
) -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	if collision:
		var s := col_size if col_size != Vector3.ZERO else Vector3(size.x, 0.4, size.y)
		_add_solid_box(pos + Vector3(0, -0.15, 0), s)


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
			if torch_spacing > 1 and (x * 7 + y * 13) % torch_spacing != 0:
				continue
			var wall_dirs: Array[Vector2i] = []
			for d in dirs:
				if not _is_walkable(_get_cell(x + d.x, y + d.y)):
					wall_dirs.append(d)
			if wall_dirs.is_empty():
				continue
			var d: Vector2i = wall_dirs[placed % wall_dirs.size()]
			var world := cell_to_world(Vector2i(x, y))
			# Cave walls bulge ~0.35–0.55 into corridor mid-height (_wall_pt tube+rock).
			# Keep torch in free air near wall face, not buried inside rock mesh.
			var wall_dist := cell_size * 0.5 - 0.58
			var pos := world + Vector3(d.x * wall_dist, 1.45, d.y * wall_dist)
			_add_torch(pos, d)
			placed += 1
	print("[Dungeon] torches=%d" % placed)


func _add_torch(pos: Vector3, wall_dir: Vector2i) -> void:
	## 2D cartoon torch sprite + soft glow halo + real 3D OmniLight.
	TorchSprites.make_wall_torch(props_root, pos, wall_dir)


func _spawn_decorations() -> void:
	## No free-floating white planes (billboards looked like “empty 3D junk”).
	## Only sparse wall braziers at dead-ends.
	var n := 0
	for cell in floor_cells:
		var x := cell.x
		var y := cell.y
		if _get_cell(x, y) == Cell.START or _get_cell(x, y) == Cell.EXIT:
			continue
		if _floor_neighbors(x, y) != 1:
			continue
		if (x * 13 + y * 7) % 5 != 0:
			continue
		var wd := _first_wall_dir(x, y)
		if wd == Vector2i.ZERO:
			continue
		var world := cell_to_world(cell)
		var base := world + Vector3(wd.x * (cell_size * 0.32), 0.0, wd.y * (cell_size * 0.32))
		_spawn_brazier(base)
		n += 1
	print("[Dungeon] braziers=%d" % n)


func _first_wall_dir(x: int, y: int) -> Vector2i:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _is_walkable(_get_cell(x + d.x, y + d.y)):
			return d
	return Vector2i.ZERO


func _spawn_brazier(pos: Vector3) -> void:
	var bowl := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.14
	cyl.height = 0.22
	bowl.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.25, 0.3, 0.34)
	bowl.material_override = bm
	bowl.position = pos + Vector3(0, 0.12, 0)
	props_root.add_child(bowl)
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.22
	flame.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.8, 1.0)
	fm.emission_enabled = true
	fm.emission = Color(0.4, 0.75, 1.0)
	fm.emission_energy_multiplier = 2.5
	flame.material_override = fm
	flame.position = pos + Vector3(0, 0.35, 0)
	props_root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.8, 1.0)
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.position = pos + Vector3(0, 0.4, 0)
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
	## Compact campfire — no random junk meshes.
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	flame.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.5, 0.15)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.55, 0.2)
	fm.emission_energy_multiplier = 2.8
	flame.material_override = fm
	flame.position = world + Vector3(0, 0.35, 0)
	props_root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.8
	light.omni_range = 6.0
	light.position = world + Vector3(0, 0.5, 0)
	props_root.add_child(light)
	var label := Label3D.new()
	label.text = "EXIT"
	label.position = world + Vector3(0, 1.2, 0)
	label.font_size = 28
	label.modulate = Color(1.0, 0.75, 0.4)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	props_root.add_child(label)


func _spawn_start_marker(_world: Vector3) -> void:
	## No glowing disc on the floor (looked like a white/cyan 3D artifact).
	pass
