extends RefCounted
## Draws one card. Shared by the deck peek and by combat, so a card looks the
## same wherever it appears.
##
## Layout follows the competitor: the illustration BLEEDS across the top half of
## the card, a cost medallion overlaps its top-left corner, a name ribbon sits on
## the seam, a small type tab hangs under it, and the rules text has the lower
## parchment to itself.
##
## This replaced card_frame.png, whose painted window was only 79x53px on a
## 138x193 card — a square illustration ended up filling 11% of the card against
## the reference's ~55%, i.e. five times too small. The frame is still in
## assets/ and ART_PROMPTS.md §3.5; regenerate it to THIS layout if a painted
## frame is wanted back.
##
## Name / cost / text are NEVER baked into art: they follow the card database,
## or the first balance pass makes every card lie about itself.

const CardDB = preload("res://scripts/cards/card_db.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const ART_DIR := "res://assets/textures/"

## Zones as fractions of the card.
const ART_RECT := Rect2(0.0, 0.0, 1.0, 0.60)
const COST_RECT := Rect2(0.02, 0.015, 0.26, 0.185)
const NAME_RECT := Rect2(0.05, 0.535, 0.90, 0.105)
const TYPE_RECT := Rect2(0.30, 0.645, 0.40, 0.070)
const TEXT_RECT := Rect2(0.07, 0.735, 0.86, 0.235)

const PARCHMENT := Color(0.91, 0.86, 0.73)
const INK := Color(0.16, 0.11, 0.07)
const EDGE := Color(0.24, 0.16, 0.11)

## Colour + label per card type, so a hand reads at a glance (reference does the
## same with its CUT / PREP / SEASON tabs).
const TYPE_TAG := {
	CardDB.Type.STRIKE: ["УДАР", Color(0.62, 0.24, 0.20)],
	CardDB.Type.GUARD: ["ЗАЩИТА", Color(0.22, 0.40, 0.58)],
	CardDB.Type.SKILL: ["ПРИЁМ", Color(0.36, 0.44, 0.26)],
	CardDB.Type.SPELL: ["ЧАРЫ", Color(0.45, 0.28, 0.55)],
	CardDB.Type.BLOOD: ["КРОВЬ", Color(0.55, 0.13, 0.18)],
}

## Keyword → colour. Rules text is scanned for these and they are tinted, so a
## player can spot "this one pierces" without reading the whole card. Longer
## phrases come first: "Пробой брони" must win over a bare "брони".
const KEYWORDS := [
	["Пробой брони", "6fd0ff"],
	["по щиту", "9fd8ff"],
	["вампиризм", "ff6f8a"],
	["Остриё", "ffd166"],
	["Эхо", "c9a4ff"],
	["кость", "e8e2cf"],
	["кости", "e8e2cf"],
	["шип", "b0f0a0"],
	["брони", "6fd0ff"],
	["урона", "ff9b6a"],
	["HP", "ff6f8a"],
]

static var _tex_cache: Dictionary = {}


## Rules text with keywords wrapped in BBCode colour tags.
static func colourise(text: String) -> String:
	var out := text
	for pair in KEYWORDS:
		var word: String = pair[0]
		# Skip anything already inside a tag from an earlier, longer keyword
		if out.find("[color") >= 0 and out.find(word) >= 0:
			var guarded := ""
			var rest := out
			while true:
				var at := rest.find(word)
				if at < 0:
					guarded += rest
					break
				var before := rest.substr(0, at)
				# inside a tag already if the last "[color" is unclosed
				var open_at := before.rfind("[color")
				var close_at := before.rfind("[/color]")
				if open_at > close_at:
					guarded += rest.substr(0, at + word.length())
				else:
					guarded += before + "[color=#%s]%s[/color]" % [pair[1], word]
				rest = rest.substr(at + word.length())
			out = guarded
		else:
			out = out.replace(word, "[color=#%s]%s[/color]" % [pair[1], word])
	return out


static func build(card: Dictionary, owner_colour: Color, card_size: Vector2) -> Control:
	var is_blood := int(card["blood"]) > 0

	var root := Control.new()
	root.custom_minimum_size = card_size
	root.clip_contents = true

	# --- body -------------------------------------------------------------
	var body := Panel.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = PARCHMENT
	body_style.border_color = EDGE
	body_style.set_border_width_all(3)
	body_style.set_corner_radius_all(9)
	body.add_theme_stylebox_override("panel", body_style)
	root.add_child(body)

	# --- illustration, bleeding across the top ----------------------------
	# Clipped by its own frame so KEEP_ASPECT_COVERED can crop instead of
	# letterboxing the art into a stamp.
	var art_clip := Control.new()
	art_clip.clip_contents = true
	_place(art_clip, ART_RECT)
	root.add_child(art_clip)

	var art := TextureRect.new()
	art.texture = load_art(card["art"])
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_clip.add_child(art)

	# Owner tint: three decks are merged into one, and this is how they stay
	# tellable apart (DESIGN §7.5)
	var tint := Panel.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tint_style := StyleBoxFlat.new()
	tint_style.bg_color = Color(0, 0, 0, 0)
	tint_style.border_color = Color(owner_colour, 0.95)
	tint_style.set_border_width_all(3)
	tint_style.set_corner_radius_all(9)
	tint.add_theme_stylebox_override("panel", tint_style)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tint)

	# --- name ribbon ------------------------------------------------------
	var ribbon := Panel.new()
	var ribbon_style := StyleBoxFlat.new()
	ribbon_style.bg_color = Color(0.86, 0.80, 0.65)
	ribbon_style.border_color = EDGE
	ribbon_style.set_border_width_all(2)
	ribbon_style.set_corner_radius_all(4)
	ribbon_style.shadow_color = Color(0, 0, 0, 0.35)
	ribbon_style.shadow_size = 4
	ribbon.add_theme_stylebox_override("panel", ribbon_style)
	_place(ribbon, NAME_RECT)
	root.add_child(ribbon)

	var name_label := Label.new()
	name_label.text = str(card["name"]).to_upper()
	var name_box := card_size * NAME_RECT.size
	UiTheme.as_title(name_label, fit_font_size(
		UiTheme.title_font(), name_label.text, name_box * Vector2(0.94, 0.9), 15, 7, false), INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(name_label, NAME_RECT)
	root.add_child(name_label)

	# --- type tab ---------------------------------------------------------
	var tag: Array = TYPE_TAG.get(int(card.get("type", -1)), ["", Color.GRAY])
	if str(tag[0]) != "":
		var tab := Panel.new()
		var tab_style := StyleBoxFlat.new()
		tab_style.bg_color = tag[1]
		tab_style.border_color = EDGE
		tab_style.set_border_width_all(2)
		tab_style.corner_radius_bottom_left = 5
		tab_style.corner_radius_bottom_right = 5
		tab.add_theme_stylebox_override("panel", tab_style)
		_place(tab, TYPE_RECT)
		root.add_child(tab)

		var tab_label := Label.new()
		tab_label.text = str(tag[0])
		UiTheme.as_title(tab_label, fit_font_size(UiTheme.title_font(), tab_label.text,
			card_size * TYPE_RECT.size * Vector2(0.9, 0.9), 10, 6, false),
			Color(0.97, 0.94, 0.88))
		tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_place(tab_label, TYPE_RECT)
		root.add_child(tab_label)

	# --- rules text -------------------------------------------------------
	var raw_text := str(card["text"])
	var text_box := card_size * TEXT_RECT.size
	var text_size := fit_font_size(UiTheme.title_font(), raw_text, text_box, 12, 7, true)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = false
	text.scroll_active = false
	text.text = "[center]%s[/center]" % colourise(raw_text)
	if UiTheme.title_font():
		text.add_theme_font_override("normal_font", UiTheme.title_font())
	text.add_theme_font_size_override("normal_font_size", text_size)
	text.add_theme_color_override("default_color", Color(0.21, 0.16, 0.12))
	_place(text, TEXT_RECT)
	root.add_child(text)

	# --- cost medallion, last so nothing covers it ------------------------
	var badge := Panel.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.62, 0.16, 0.18) if is_blood else Color(0.16, 0.28, 0.45)
	badge_style.border_color = Color(0.93, 0.87, 0.72)
	badge_style.set_border_width_all(3)
	badge_style.set_corner_radius_all(64)  # a circle at any card size
	badge_style.shadow_color = Color(0, 0, 0, 0.5)
	badge_style.shadow_size = 5
	badge.add_theme_stylebox_override("panel", badge_style)
	_place(badge, COST_RECT)
	root.add_child(badge)

	var cost := Label.new()
	cost.text = str(card["blood"]) if is_blood else str(card["energy"])
	UiTheme.as_title(cost, int(card_size.y * 0.105), Color(1.0, 0.97, 0.92))
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(cost, COST_RECT)
	root.add_child(cost)

	# A card is decoration — clicking it is always someone else's job (the hand
	# puts a button over it, the draft wraps it in one). Panel defaults to
	# MOUSE_FILTER_STOP, so the body panel silently ate every click meant for a
	# parent button and the draft could not be picked. Force the whole subtree
	# transparent to the mouse rather than remembering it per node.
	_ignore_mouse(root)
	return root


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


## Largest size at which `text` still fits `box`, measured with the real font
## metrics. Card names range from "Сеча" to "Навий хлыст" — a fixed size either
## clips the long ones or wastes the short ones.
static func fit_font_size(font: Font, text: String, box: Vector2,
		max_size: int, min_size: int, wrap: bool) -> int:
	if font == null or text.is_empty():
		return max_size
	for size in range(max_size, min_size - 1, -1):
		var used: Vector2
		if wrap:
			used = font.get_multiline_string_size(
				text, HORIZONTAL_ALIGNMENT_CENTER, box.x, size)
		else:
			used = font.get_string_size(
				text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
		if used.x <= box.x and used.y <= box.y:
			return size
	return min_size


## Anchor a child to a fractional rect of the card, so every element keeps its
## place at any card size.
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
	# Check the file first: Image.load on a missing path spams hard errors.
	if FileAccess.file_exists(path):
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		if tex == null:
			var img := Image.new()
			if img.load(path) == OK:
				tex = ImageTexture.create_from_image(img)
	if tex == null:
		print("[CardView] art not drawn yet: %s" % id)
	_tex_cache[id] = tex
	return tex
