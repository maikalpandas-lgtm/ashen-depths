extends Control
## Parchment-style corridor minimap (competitor-inspired).

## Compact left-HUD map (competitor scale).
@export var tile: int = 16
@export var gap: int = 2
@export var view_radius: int = 5
@export var panel_size: int = 168

var _dungeon: Node
var _player: Node3D
var _texture_rect: TextureRect
var _img: Image
var _tex: ImageTexture
var _revealed: Dictionary = {}

# parchment palette
const COL_BG := Color(0.28, 0.22, 0.18, 1)
const COL_PAPER := Color(0.36, 0.28, 0.22, 1)
const COL_TILE := Color(0.72, 0.66, 0.55, 1)
const COL_TILE_EDGE := Color(0.55, 0.48, 0.38, 1)
const COL_PLAYER := Color(1.0, 0.88, 0.35, 1)
const COL_EXIT := Color(0.95, 0.45, 0.2, 1)
const COL_CHEST := Color(0.95, 0.8, 0.25, 1)
## Skull bone, drawn ON a normal tile. It used to match the tile it sat on, so
## the icon was invisible except for two eye pixels.
const COL_FIGHT := Color(0.93, 0.92, 0.84, 1)
const COL_FIGHT_INK := Color(0.12, 0.1, 0.08, 1)
const COL_FIGHT_GLOW := Color(0.55, 0.95, 0.35, 1)
const COL_DOOR := Color(0.55, 0.38, 0.25, 1)


func setup(dungeon: Node, player: Node3D) -> void:
	_dungeon = dungeon
	_player = player
	custom_minimum_size = Vector2(panel_size, panel_size)
	size = Vector2(panel_size, panel_size)

	if _texture_rect == null:
		_texture_rect = TextureRect.new()
		_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_texture_rect)

	var dim := (view_radius * 2 + 1) * (tile + gap)
	_img = Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	_texture_rect.texture = _tex
	_redraw()


func clear_fog() -> void:
	_revealed.clear()


func _process(_delta: float) -> void:
	if _dungeon == null or _player == null:
		return
	if not _dungeon.has_method("world_to_cell"):
		return
	var cell: Vector2i = _dungeon.call("world_to_cell", _player.global_position) as Vector2i
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := Vector2i(cell.x + dx, cell.y + dy)
			if _dungeon_walkable(c.x, c.y):
				_revealed[c] = true
	_redraw()


func _dungeon_walkable(x: int, y: int) -> bool:
	if _dungeon == null or not _dungeon.has_method("is_walkable_cell"):
		return false
	return bool(_dungeon.call("is_walkable_cell", x, y))


func _redraw() -> void:
	if _dungeon == null or _img == null or _player == null:
		return
	_img.fill(COL_BG)
	# paper vignette
	var w := _img.get_width()
	var h := _img.get_height()
	for y in range(h):
		for x in range(w):
			var edge := mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
			if edge < 6:
				_img.set_pixel(x, y, COL_BG.darkened(0.15))
			elif edge < 14:
				var t := float(edge - 6) / 8.0
				_img.set_pixel(x, y, COL_BG.lerp(COL_PAPER, t * 0.5))

	if not _dungeon.has_method("world_to_cell"):
		return
	var pc: Vector2i = _dungeon.call("world_to_cell", _player.global_position) as Vector2i
	var cells_side := view_radius * 2 + 1
	var origin := Vector2i(pc.x - view_radius, pc.y - view_radius)

	for ly in range(cells_side):
		for lx in range(cells_side):
			var gx := origin.x + lx
			var gy := origin.y + ly
			var cell := Vector2i(gx, gy)
			if not _revealed.has(cell):
				continue
			if not _dungeon_walkable(gx, gy):
				continue
			var kind: int = 0
			if _dungeon.has_method("get_cell_type"):
				kind = int(_dungeon.call("get_cell_type", gx, gy))
			var col := COL_TILE
			match kind:
				2:
					col = COL_DOOR
				3:
					col = COL_TILE.lightened(0.1)
				4:
					col = COL_EXIT
				5:
					col = COL_CHEST
				7:
					col = Color(0.55, 0.45, 0.22)  # merchant
			_draw_rounded_tile(lx, ly, col)
			# special icons
			match kind:
				4:
					_draw_campfire_icon(lx, ly)
				6:
					_draw_skull_icon(lx, ly)
				5:
					_draw_dot(lx, ly, Color(0.2, 0.15, 0.05), 0.28)
				7:
					_draw_merchant_icon(lx, ly)

	# player (center of view)
	var plx := view_radius
	var ply := view_radius
	_draw_player(plx, ply)

	_tex.update(_img)


func _tile_origin(lx: int, ly: int) -> Vector2i:
	return Vector2i(lx * (tile + gap) + gap / 2, ly * (tile + gap) + gap / 2)


func _draw_rounded_tile(lx: int, ly: int, col: Color) -> void:
	var o := _tile_origin(lx, ly)
	for py in range(tile):
		for px in range(tile):
			# soft corner
			var corner := false
			if (px < 2 or px >= tile - 2) and (py < 2 or py >= tile - 2):
				if (px == 0 or px == tile - 1) and (py == 0 or py == tile - 1):
					corner = true
			if corner:
				continue
			var c := col
			if px == 0 or py == 0 or px == tile - 1 or py == tile - 1:
				c = COL_TILE_EDGE
			_put(o.x + px, o.y + py, c)


func _draw_player(lx: int, ly: int) -> void:
	var o := _tile_origin(lx, ly)
	var cx := o.x + tile / 2
	var cy := o.y + tile / 2
	# glow
	for py in range(-3, 4):
		for px in range(-3, 4):
			if px * px + py * py <= 10:
				_put(cx + px, cy + py, COL_PLAYER.darkened(0.15))
	for py in range(-2, 3):
		for px in range(-2, 3):
			if px * px + py * py <= 4:
				_put(cx + px, cy + py, COL_PLAYER)
	# facing
	if _player:
		var forward := -_player.global_transform.basis.z
		var fx := 0
		var fy := 0
		if absf(forward.x) > absf(forward.z):
			fx = 1 if forward.x > 0.0 else -1
		else:
			fy = 1 if forward.z > 0.0 else -1
		_put(cx + fx * 3, cy + fy * 3, Color(1, 1, 0.7))
		_put(cx + fx * 4, cy + fy * 4, Color(1, 0.95, 0.5))


## Skull marking a pack. Readable at 14px: dark outline first so the bone reads
## against parchment, then eye sockets, jaw and a green witch-fire tuft.
## Skull marking a pack — deliberately drawn LARGER than its tile. A pack is the
## thing a player actually navigates by, so it must be spottable at a glance in
## a wall of identical corridor squares.
func _draw_skull_icon(lx: int, ly: int) -> void:
	var o := _tile_origin(lx, ly)
	var cx := o.x + tile / 2
	var cy := o.y + tile / 2 + 1
	var s := maxf(1.0, float(tile) / 14.0) * 1.55  # scale with tile, then bigger

	# dark outline first so bone reads against parchment
	_disc(cx, cy, 7.4 * s, COL_FIGHT_INK)
	_disc(cx, cy, 5.6 * s, COL_FIGHT)
	# jaw
	_rect(cx - int(3.0 * s), cy + int(3.2 * s), int(6.0 * s), int(2.2 * s), COL_FIGHT_INK)
	_rect(cx - int(2.4 * s), cy + int(3.0 * s), int(4.8 * s), int(1.6 * s), COL_FIGHT)
	# eye sockets
	_disc(cx - 2.4 * s, cy - 1.2 * s, 1.9 * s, COL_FIGHT_INK)
	_disc(cx + 2.4 * s, cy - 1.2 * s, 1.9 * s, COL_FIGHT_INK)
	# nose + teeth
	_rect(cx, cy + int(1.0 * s), maxi(1, int(1.2 * s)), maxi(1, int(1.6 * s)), COL_FIGHT_INK)
	for t in [-1, 1]:
		_rect(cx + int(float(t) * 1.4 * s), cy + int(3.0 * s),
			maxi(1, int(0.9 * s)), maxi(1, int(1.6 * s)), COL_FIGHT_INK)
	# witch-fire above
	_disc(cx, cy - 8.2 * s, 1.5 * s, COL_FIGHT_GLOW)
	_disc(cx, cy - 9.6 * s, 1.0 * s, COL_FIGHT_GLOW.lightened(0.3))


func _disc(cx: float, cy: float, r: float, col: Color) -> void:
	var ri := int(ceil(r))
	for py in range(-ri, ri + 1):
		for px in range(-ri, ri + 1):
			if float(px * px + py * py) <= r * r:
				_put(int(cx) + px, int(cy) + py, col)


func _rect(x: int, y: int, w: int, h: int, col: Color) -> void:
	for py in range(h):
		for px in range(w):
			_put(x + px, y + py, col)


func _draw_campfire_icon(lx: int, ly: int) -> void:
	var o := _tile_origin(lx, ly)
	var cx := o.x + tile / 2
	var cy := o.y + tile / 2 + 1
	_put(cx - 2, cy + 1, Color(0.35, 0.28, 0.22))
	_put(cx + 2, cy + 1, Color(0.35, 0.28, 0.22))
	_put(cx, cy, Color(1.0, 0.55, 0.15))
	_put(cx, cy - 1, Color(1.0, 0.75, 0.25))
	_put(cx, cy - 2, Color(1.0, 0.4, 0.1))


## Coin pouch mark for map merchant (§8.3 C).
func _draw_merchant_icon(lx: int, ly: int) -> void:
	var o := _tile_origin(lx, ly)
	var cx := o.x + tile / 2
	var cy := o.y + tile / 2
	var gold := Color(0.95, 0.78, 0.25)
	var bag := Color(0.45, 0.32, 0.15)
	for py in range(-2, 3):
		for px in range(-3, 4):
			if absi(px) + absi(py) <= 3:
				_put(cx + px, cy + py, bag)
	_put(cx, cy - 1, gold)
	_put(cx - 1, cy, gold)
	_put(cx + 1, cy, gold)


func _draw_dot(lx: int, ly: int, col: Color, r: float) -> void:
	var o := _tile_origin(lx, ly)
	var cx := o.x + tile / 2
	var cy := o.y + tile / 2
	var ri := int(tile * r)
	for py in range(-ri, ri + 1):
		for px in range(-ri, ri + 1):
			if px * px + py * py <= ri * ri:
				_put(cx + px, cy + py, col)


func _put(x: int, y: int, col: Color) -> void:
	if _img == null:
		return
	if x < 0 or y < 0 or x >= _img.get_width() or y >= _img.get_height():
		return
	_img.set_pixel(x, y, col)
