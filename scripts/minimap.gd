extends Control
## Top-down fog-of-war-ish minimap from dungeon grid.

@export var pixel_size: int = 4
@export var panel_size: int = 168

var _dungeon: Node3D
var _player: Node3D
var _texture_rect: TextureRect
var _img: Image
var _tex: ImageTexture
var _revealed: Dictionary = {}  # Vector2i -> true


func setup(dungeon: Node3D, player: Node3D) -> void:
	_dungeon = dungeon
	_player = player
	custom_minimum_size = Vector2(panel_size, panel_size)
	size = Vector2(panel_size, panel_size)

	if _texture_rect == null:
		_texture_rect = TextureRect.new()
		_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_texture_rect)

	_rebuild_base()
	_redraw()


func clear_fog() -> void:
	_revealed.clear()


func _process(_delta: float) -> void:
	if _dungeon == null or _player == null:
		return
	if not _dungeon.has_method("world_to_cell"):
		return
	var cell: Vector2i = _dungeon.world_to_cell(_player.global_position)
	# Reveal around player
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			_revealed[Vector2i(cell.x + dx, cell.y + dy)] = true
	_redraw()


func _rebuild_base() -> void:
	if _dungeon == null:
		return
	var gw: int = _dungeon.grid_width
	var gh: int = _dungeon.grid_height
	_img = Image.create(gw * pixel_size, gh * pixel_size, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0.08, 0.06, 0.1, 1))
	_tex = ImageTexture.create_from_image(_img)
	_texture_rect.texture = _tex


func _redraw() -> void:
	if _dungeon == null or _img == null:
		return
	var gw: int = _dungeon.grid_width
	var gh: int = _dungeon.grid_height
	_img.fill(Color(0.06, 0.05, 0.09, 1))

	for y in range(gh):
		for x in range(gw):
			var cell := Vector2i(x, y)
			var walk: bool = _dungeon.is_walkable_cell(x, y)
			var col := Color(0.12, 0.1, 0.15, 1)
			if walk:
				if _revealed.has(cell):
					col = Color(0.45, 0.4, 0.52, 1)
					var kind: int = _dungeon.get_cell_type(x, y)
					# Door / specials via enum values matching dungeon
					match kind:
						2: # DOOR
							col = Color(0.65, 0.4, 0.25, 1)
						3: # START
							col = Color(0.3, 0.75, 0.4, 1)
						4: # EXIT
							col = Color(0.7, 0.35, 0.95, 1)
						5: # CHEST
							col = Color(1.0, 0.85, 0.25, 1)
						6: # ENCOUNTER
							col = Color(0.95, 0.25, 0.3, 1)
				else:
					col = Color(0.14, 0.12, 0.18, 1)  # unexplored floor hint (optional dark)
					col = Color(0.08, 0.07, 0.1, 1)  # fog: hide until revealed
			_fill_cell(x, y, col)

	# Player
	if _player and _dungeon.has_method("world_to_cell"):
		var pc: Vector2i = _dungeon.world_to_cell(_player.global_position)
		_fill_cell(pc.x, pc.y, Color(1.0, 0.95, 0.55, 1))
		# facing tick
		var forward := -_player.global_transform.basis.z
		var fx := 0
		var fy := 0
		if absf(forward.x) > absf(forward.z):
			fx = 1 if forward.x > 0.0 else -1
		else:
			fy = 1 if forward.z > 0.0 else -1
		_fill_cell(pc.x + fx, pc.y + fy, Color(1.0, 0.8, 0.2, 1))

	_tex.update(_img)


func _fill_cell(x: int, y: int, col: Color) -> void:
	if _img == null:
		return
	var gw: int = _dungeon.grid_width
	var gh: int = _dungeon.grid_height
	if x < 0 or y < 0 or x >= gw or y >= gh:
		return
	var x0 := x * pixel_size
	var y0 := y * pixel_size
	for py in range(pixel_size):
		for px in range(pixel_size):
			_img.set_pixel(x0 + px, y0 + py, col)
