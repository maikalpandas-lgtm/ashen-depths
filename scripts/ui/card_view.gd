extends RefCounted
## Draws one card: the frame image, the skill art seated in its window, and the
## numbers composited on top. Shared by the deck peek and by combat, so a card
## looks the same wherever it appears.

const CardDB = preload("res://scripts/cards/card_db.gd")

const ART_DIR := "res://assets/textures/"

## Zones inside the frame, as fractions of the card. MEASURED off card_frame.png
## rather than guessed — the delivered frame put its window and ribbon well
## inside my original estimates, so text would have sat on bare parchment.
## Same table is mirrored in docs/ART_PROMPTS.md §3.5 for the next frame.
const COST_RECT := Rect2(0.126, 0.081, 0.238, 0.170)  ## medallion socket
const ART_RECT := Rect2(0.210, 0.147, 0.570, 0.276)  ## inside the wooden window
const NAME_RECT := Rect2(0.260, 0.487, 0.480, 0.069)  ## flat middle of the ribbon
const TEXT_RECT := Rect2(0.160, 0.600, 0.680, 0.280)  ## empty parchment below

static var _tex_cache: Dictionary = {}


## A card is one frame image with the skill art dropped into its window and the
## numbers drawn on top. Name / cost / text are NEVER baked into art: they have
## to follow the card database, or the first balance pass makes every card lie.
static func build(card: Dictionary, owner_colour: Color, card_size: Vector2) -> Control:
	var is_blood := int(card["blood"]) > 0

	var root := Control.new()
	root.custom_minimum_size = card_size

	var frame_tex := load_art("card_frame")
	if frame_tex != null:
		var bg := TextureRect.new()
		bg.texture = frame_tex
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		root.add_child(bg)
	else:
		# Frame art not delivered yet — keep the view usable meanwhile
		var panel := Panel.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.82, 0.76, 0.62, 0.97)
		style.border_color = Color(0.28, 0.2, 0.14)
		style.set_border_width_all(3)
		style.set_corner_radius_all(7)
		panel.add_theme_stylebox_override("panel", style)
		root.add_child(panel)

	# Owner tint: three decks are merged into one, and the border colour is how
	# they stay tellable apart (DESIGN §7.5)
	var tint := Panel.new()
	_place(tint, Rect2(0.0, 0.0, 1.0, 1.0))
	var tint_style := StyleBoxFlat.new()
	tint_style.bg_color = Color(0, 0, 0, 0)
	tint_style.border_color = Color(owner_colour, 0.9)
	tint_style.set_border_width_all(3)
	tint_style.set_corner_radius_all(7)
	tint.add_theme_stylebox_override("panel", tint_style)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tint)

	var art := TextureRect.new()
	art.texture = load_art(card["art"])
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(art, ART_RECT)
	root.add_child(art)

	# The frame's medallion socket overlaps the top-left of its own art window,
	# so the badge has to go ON TOP of the illustration or the art buries it.
	var badge := TextureRect.new()
	badge.texture = load_art("card_cost_badge_blood" if is_blood else "card_cost_badge")
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_place(badge, COST_RECT)
	root.add_child(badge)

	var cost := Label.new()
	cost.text = str(card["blood"]) if is_blood else str(card["energy"])
	cost.add_theme_font_size_override("font_size", 17)
	cost.add_theme_color_override("font_color",
		Color(1.0, 0.72, 0.72) if is_blood else Color(0.86, 0.95, 1.0))
	cost.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1))
	cost.add_theme_constant_override("outline_size", 5)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(cost, COST_RECT)
	root.add_child(cost)

	var name_label := Label.new()
	name_label.text = str(card["name"]).to_upper()
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.16, 0.11, 0.07))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(name_label, NAME_RECT)
	root.add_child(name_label)

	var text := Label.new()
	text.text = card["text"]
	text.add_theme_font_size_override("font_size", 10)
	text.add_theme_color_override("font_color", Color(0.2, 0.16, 0.12))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(text, TEXT_RECT)
	root.add_child(text)

	return root


## Anchor a child to a fractional rect of the card, so every element keeps its
## place on the frame at any card size.
static func _place(node: Control, r: Rect2) -> void:
	node.anchor_left = r.position.x
	node.anchor_top = r.position.y
	node.anchor_right = r.position.x + r.size.x
	node.anchor_bottom = r.position.y + r.size.y
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Card art is only present for some cards so far — a missing PNG must not
## crash the view, it just leaves an empty slot.
static func load_art(id: String) -> Texture2D:
	if _tex_cache.has(id):
		return _tex_cache[id]
	var path := ART_DIR + id + ".png"
	var tex: Texture2D = null
	# Check the file first: half the card art and the frame are not drawn yet,
	# and Image.load on a missing path spams the log with hard errors.
	if FileAccess.file_exists(path):
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		if tex == null:
			var img := Image.new()
			if img.load(path) == OK:
				tex = ImageTexture.create_from_image(img)
	if tex == null:
		print("[CardTest] art not drawn yet: %s" % id)
	_tex_cache[id] = tex
	return tex
