extends PanelContainer
## Left HUD column — competitor layout (Spice Mines-ish):
## title + gear · big zoomed minimap · large cartoon portrait · HP · gold · inventory.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const ART_DIR := "res://assets/textures/"

signal inventory_pressed
signal settings_pressed

@export var minimap_path: NodePath
@export var portrait_size: float = 148.0

var _title: Label = null
var _floor: Label = null
var _portrait: TextureRect = null
var _hero_name: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _gold_label: Label = null
var _minimap: Control = null
var _tex_cache: Dictionary = {}


func _ready() -> void:
	_build()
	refresh()


func bind_minimap(m: Control) -> void:
	_minimap = m
	if _minimap and _minimap.has_method("setup"):
		# Zoomed-in map: fewer cells, larger tiles
		_minimap.set("tile", 24)
		_minimap.set("gap", 3)
		_minimap.set("view_radius", 5)
		_minimap.set("panel_size", 240)


func set_minimap_node(m: Control) -> void:
	bind_minimap(m)


func refresh() -> void:
	var floor_i := 1
	var gold := 0
	var party_hp := 88
	var party_max := 88
	var portrait_id := "hero_vityaz"
	var name_s := "Витязь"
	if GameState:
		floor_i = GameState.floor_index
		gold = GameState.gold
		if GameState.party and not GameState.party.members.is_empty():
			party_hp = GameState.party.total_hp()
			party_max = GameState.party.total_max_hp()
			var lead: Dictionary = GameState.party.members[0]
			portrait_id = str(lead.get("portrait", portrait_id))
			name_s = str(lead.get("name", name_s))
	if _title:
		_title.text = "Навьи Копи"
	if _floor:
		var realm := "Рудники" if floor_i < 3 else "Навь"
		_floor.text = "%s  ·  этаж %d" % [realm, floor_i]
	if _hp_bar:
		_hp_bar.max_value = party_max
		_hp_bar.value = party_hp
	if _hp_label:
		_hp_label.text = "❤  %d/%d" % [party_hp, party_max]
	if _gold_label:
		_gold_label.text = "🪙  %d" % gold
	if _hero_name:
		_hero_name.text = name_s
	if _portrait:
		_portrait.texture = _load_tex(portrait_id)


func _build() -> void:
	# Wipe scene-template children — this script owns the layout
	for c in get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	# --- header: title + gear ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	col.add_child(header)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	if UiTheme.display_font():
		_title.add_theme_font_override("font", UiTheme.display_font())
	header.add_child(_title)

	var inv_top := _icon_btn("🎒", "Инвентарь / колода")
	inv_top.pressed.connect(func(): inventory_pressed.emit())
	header.add_child(inv_top)

	var gear := _icon_btn("⚙", "Настройки")
	gear.pressed.connect(func(): settings_pressed.emit())
	header.add_child(gear)

	_floor = Label.new()
	_floor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor.add_theme_font_size_override("font_size", 12)
	_floor.add_theme_color_override("font_color", Color(0.72, 0.66, 0.78))
	if UiTheme.title_font():
		_floor.add_theme_font_override("font", UiTheme.title_font())
	col.add_child(_floor)

	# --- big minimap (slot; real Minimap reparented by main) ---
	var map_frame := PanelContainer.new()
	map_frame.name = "MinimapFrame"
	map_frame.custom_minimum_size = Vector2(248, 248)
	map_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var map_style := StyleBoxFlat.new()
	map_style.bg_color = Color(0.28, 0.22, 0.16, 1)
	map_style.border_color = Color(0.55, 0.4, 0.25, 1)
	map_style.set_border_width_all(3)
	map_style.set_corner_radius_all(10)
	map_style.content_margin_left = 6
	map_style.content_margin_right = 6
	map_style.content_margin_top = 6
	map_style.content_margin_bottom = 6
	map_frame.add_theme_stylebox_override("panel", map_style)
	col.add_child(map_frame)
	# Placeholder so main can reparent minimap here
	var map_slot := Control.new()
	map_slot.name = "MinimapSlot"
	map_slot.custom_minimum_size = Vector2(236, 236)
	map_frame.add_child(map_slot)

	# --- large portrait (cartoon, emotional) ---
	var port_wrap := CenterContainer.new()
	col.add_child(port_wrap)

	var port_ring := PanelContainer.new()
	port_ring.custom_minimum_size = Vector2(portrait_size + 16, portrait_size + 16)
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0.12, 0.09, 0.07, 1)
	ring_style.border_color = Color(0.65, 0.48, 0.28, 1)
	ring_style.set_border_width_all(4)
	ring_style.set_corner_radius_all(int(portrait_size))
	port_ring.add_theme_stylebox_override("panel", ring_style)
	port_wrap.add_child(port_ring)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.clip_contents = true
	port_ring.add_child(_portrait)

	_hero_name = Label.new()
	_hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_name.add_theme_font_size_override("font_size", 16)
	_hero_name.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	if UiTheme.title_font():
		_hero_name.add_theme_font_override("font", UiTheme.title_font())
	col.add_child(_hero_name)

	# --- HP ---
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 16)
	_hp_bar.show_percentage = false
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.12, 0.08, 0.1, 1)
	hp_bg.set_corner_radius_all(5)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.78, 0.28, 0.32, 1)
	hp_fill.set_corner_radius_all(5)
	_hp_bar.add_theme_stylebox_override("background", hp_bg)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	col.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 13)
	_hp_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.55))
	col.add_child(_hp_label)

	# --- gold + inventory row ---
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(bottom)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	if UiTheme.title_font():
		_gold_label.add_theme_font_override("font", UiTheme.title_font())
	bottom.add_child(_gold_label)

	var inv := Button.new()
	inv.text = " 🎒 Инвентарь "
	inv.custom_minimum_size = Vector2(0, 36)
	inv.pressed.connect(func(): inventory_pressed.emit())
	bottom.add_child(inv)

	custom_minimum_size = Vector2(268, 620)


func take_minimap_slot() -> Control:
	return find_child("MinimapSlot", true, false) as Control


func _icon_btn(glyph: String, tip: String) -> Button:
	var b := Button.new()
	b.text = glyph
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(36, 32)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _load_tex(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var path := ART_DIR + id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		var img := Image.new()
		if img.load(path) == OK:
			tex = ImageTexture.create_from_image(img)
	_tex_cache[id] = tex
	return tex
