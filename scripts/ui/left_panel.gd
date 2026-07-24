extends PanelContainer
## Left HUD column — competitor layout (Spice Mines-ish):
## title + gear · big zoomed minimap · large cartoon portrait · HP · gold · inventory.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const EnemySprites = preload("res://scripts/enemy_sprites.gd")

const REACT_TIME := 0.42
const REACT_COLOURS := {
	"hit": Color(1.0, 0.32, 0.28),
	"heal": Color(0.42, 0.92, 0.5),
	"buff": Color(1.0, 0.78, 0.3),
}
const ART_DIR := "res://assets/textures/"

signal inventory_pressed
signal settings_pressed

@export var minimap_path: NodePath
@export var portrait_size: float = 100.0

const CIRCLE_MASK = preload("res://shaders/circle_mask.gdshader")

var _title: Label = null
var _floor: Label = null
var _portrait: TextureRect = null
## Seconds of "just got hit" left on the portrait. The reference's goblin reacts
## to events, not only to a health threshold — that is what sells it as a face
## rather than a stat readout.
var _react := 0.0
var _react_kind := ""
var _react_ring: Panel = null
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
		# Compact HUD map (competitor-sized panel, still readable)
		_minimap.set("tile", 16)
		_minimap.set("gap", 2)
		_minimap.set("view_radius", 5)
		_minimap.set("panel_size", 168)


func set_minimap_node(m: Control) -> void:
	bind_minimap(m)


func refresh() -> void:
	var floor_i := 1
	var gold := 0
	# Fallback only — a real run always has a hero. 88 was the old three-hero
	# total; a solo run's pool is whatever that hero carries.
	var party_hp := 82
	var party_max := 82
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
	var forest := GameState and str(GameState.biome) == "forest"
	if _title:
		_title.text = "Заповедный Лес" if forest else "Навьи Копи"
	if _floor:
		var realm := EnemySprites.realm_name(floor_i,
			str(GameState.biome) if GameState else "mine")
		var lvl := 1
		var xp_s := ""
		if GameState:
			lvl = GameState.level
			# "ур." is the HERO level, not the floor. Both numbers sat side by
			# side unlabelled and read as "floor 1, floor 2".
			xp_s = "  ·  герой ур.%d" % lvl
		_floor.text = "%s  ·  этаж %d%s" % [realm, floor_i, xp_s]
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
		_portrait.texture = _load_tex(_portrait_for(portrait_id, party_hp, party_max))
		# Tint is the fallback when a mood portrait has not been drawn yet: a
		# hurt hero still reads as hurt, just less expressively.
		_portrait.modulate = _portrait_tint(party_hp, party_max)


## Mood portraits: `<id>_hurt` under half HP, `<id>_low` under a quarter.
##
## Falls back to the plain portrait when the variant is missing, so this can
## ship BEFORE the art does — see docs/ART_PROMPTS.md §3.11. The reference
## leans on this hard: its goblin visibly reacts, and it costs nothing at
## runtime.
## Flash the portrait on a combat event. `kind`: "hit" | "heal" | "buff".
##
## Deliberately a RING and a shake rather than a swapped image: this fires
## several times a fight, and swapping the texture that often would fight the
## HP-threshold portrait for control of the same node.
func react(kind: String) -> void:
	_react_kind = kind
	_react = REACT_TIME
	set_process(true)


func _process(delta: float) -> void:
	if _react <= 0.0:
		set_process(false)
		if _react_ring:
			_react_ring.modulate = Color(1, 1, 1, 0)
		if _portrait:
			_portrait.position = Vector2.ZERO
		return
	_react = maxf(0.0, _react - delta)
	var t: float = _react / REACT_TIME
	if _react_ring:
		_react_ring.modulate = Color(REACT_COLOURS.get(_react_kind,
			REACT_COLOURS["hit"]), t)
	if _portrait and _react_kind == "hit":
		# Small horizontal shake — a vertical one reads as the whole panel
		# jumping, which is far more distracting than the hit deserves.
		_portrait.position = Vector2(sin(t * 46.0) * 4.0 * t, 0.0)


func _portrait_for(base_id: String, hp: int, max_hp: int) -> String:
	if max_hp <= 0:
		return base_id
	var frac := float(hp) / float(max_hp)
	var want := base_id
	if frac <= 0.25:
		want = base_id + "_low"
	elif frac <= 0.5:
		want = base_id + "_hurt"
	if want != base_id and _load_tex(want) != null:
		return want
	return base_id


func _portrait_tint(hp: int, max_hp: int) -> Color:
	if max_hp <= 0:
		return Color.WHITE
	var frac := float(hp) / float(max_hp)
	if frac <= 0.25:
		return Color(1.0, 0.72, 0.68)
	if frac <= 0.5:
		return Color(1.0, 0.88, 0.84)
	return Color.WHITE


func _build() -> void:
	# Wipe scene-template children — this script owns the layout
	for c in get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	# --- header: title + gear ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	col.add_child(header)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_font_size_override("font_size", 15)
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
	_floor.add_theme_font_size_override("font_size", 11)
	_floor.add_theme_color_override("font_color", Color(0.72, 0.66, 0.78))
	if UiTheme.title_font():
		_floor.add_theme_font_override("font", UiTheme.title_font())
	col.add_child(_floor)

	# --- compact minimap (competitor scale) ---
	var map_frame := PanelContainer.new()
	map_frame.name = "MinimapFrame"
	map_frame.custom_minimum_size = Vector2(176, 176)
	map_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var map_style := StyleBoxFlat.new()
	map_style.bg_color = Color(0.28, 0.22, 0.16, 1)
	map_style.border_color = Color(0.55, 0.4, 0.25, 1)
	map_style.set_border_width_all(3)
	map_style.set_corner_radius_all(8)
	map_style.content_margin_left = 4
	map_style.content_margin_right = 4
	map_style.content_margin_top = 4
	map_style.content_margin_bottom = 4
	map_frame.add_theme_stylebox_override("panel", map_style)
	col.add_child(map_frame)
	var map_slot := Control.new()
	map_slot.name = "MinimapSlot"
	map_slot.custom_minimum_size = Vector2(168, 168)
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
	# Keep the portrait inside the ring rather than under it
	ring_style.set_content_margin_all(5.0)
	port_ring.add_theme_stylebox_override("panel", ring_style)
	port_wrap.add_child(port_ring)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# clip_contents would only clip to the RECTANGLE; the round ring behind it is
	# just paint, so the art spilled past it. A real circular mask instead.
	var mask := ShaderMaterial.new()
	mask.shader = CIRCLE_MASK
	_portrait.material = mask
	port_ring.add_child(_portrait)

	# Reaction ring, transparent until react() fires. Sits OVER the portrait and
	# ignores the mouse so it can never eat a click on the panel.
	_react_ring = Panel.new()
	var react_style := StyleBoxFlat.new()
	react_style.bg_color = Color(0, 0, 0, 0)
	react_style.border_color = Color(1, 1, 1, 1)
	react_style.set_border_width_all(4)
	react_style.set_corner_radius_all(int(portrait_size))
	_react_ring.add_theme_stylebox_override("panel", react_style)
	_react_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_react_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_react_ring.modulate = Color(1, 1, 1, 0)
	port_ring.add_child(_react_ring)

	_hero_name = Label.new()
	_hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_name.add_theme_font_size_override("font_size", 13)
	_hero_name.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	if UiTheme.title_font():
		_hero_name.add_theme_font_override("font", UiTheme.title_font())
	col.add_child(_hero_name)

	# --- HP ---
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 12)
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
	_gold_label.add_theme_font_size_override("font_size", 15)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	if UiTheme.title_font():
		_gold_label.add_theme_font_override("font", UiTheme.title_font())
	bottom.add_child(_gold_label)

	var inv := Button.new()
	inv.text = " 🎒 "
	inv.tooltip_text = "Инвентарь / колода"
	inv.custom_minimum_size = Vector2(40, 30)
	inv.pressed.connect(func(): inventory_pressed.emit())
	bottom.add_child(inv)

	custom_minimum_size = Vector2(188, 520)


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
