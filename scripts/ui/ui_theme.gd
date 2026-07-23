extends RefCounted
## Fantasy typography, one place.
##
## The game is in Russian, and that rules most "fantasy" fonts straight out:
## Cinzel and MedievalSharp carry ZERO Cyrillic glyphs (verified — 0 of 64), so
## every Russian label would have rendered as empty boxes. Both are kept in the
## repo for a possible English build, but nothing points at them.
##
## Two faces, split by job:
##   DISPLAY — Ruslan Display, cut after Old Slavonic lettering. Heavy character,
##             so it only ever gets the game title and big banners.
##   TITLE   — Forum, an elegant roman with full Cyrillic. Legible in caps at
##             small sizes, so it carries card names, enemy names and buttons.
##
## Body text stays on the engine default: card rules are 10px, and every
## decorative face turns to mush there.
##
## All SIL Open Font License (licences sit beside the files); free to ship
## in a commercial build.

const DISPLAY_PATH := "res://assets/fonts/RuslanDisplay.ttf"
const TITLE_PATH := "res://assets/fonts/Forum.ttf"
const BODY_PATH := "res://assets/fonts/Forum.ttf"

static var _title: FontFile = null
static var _body: FontFile = null


static var _display: FontFile = null


static func title_font() -> FontFile:
	if _title == null:
		_title = _load(TITLE_PATH)
	return _title


## Game title and big banners only — too characterful for anything smaller.
static func display_font() -> FontFile:
	if _display == null:
		_display = _load(DISPLAY_PATH)
	return _display


static func as_display(label: Label, size: int, colour: Color = Color.WHITE) -> Label:
	var f := display_font()
	if f:
		label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


static func body_font() -> FontFile:
	if _body == null:
		_body = _load(BODY_PATH)
	return _body


## Card names, headings, banners.
static func as_title(label: Label, size: int, colour: Color = Color.WHITE) -> Label:
	var f := title_font()
	if f:
		label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


## Flavour text where character matters more than density.
static func as_body(label: Label, size: int, colour: Color = Color.WHITE) -> Label:
	var f := body_font()
	if f:
		label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


static func style_button(button: Button, size: int) -> Button:
	var f := title_font()
	if f:
		button.add_theme_font_override("font", f)
	button.add_theme_font_size_override("font_size", size)
	return button


## Chunky cartoon button: thick dark outline, rounded, a lighter top edge and a
## drop shadow that shrinks when pressed, so it reads as a physical thing being
## pushed in. Flat engine-default buttons looked like a debug menu next to the
## painted cards.
static func cartoon_button(button: Button, size: int,
		fill: Color = Color(0.22, 0.55, 0.45),
		text_col: Color = Color(0.98, 0.95, 0.88)) -> Button:
	style_button(button, size)
	button.add_theme_color_override("font_color", text_col)
	button.add_theme_color_override("font_hover_color", text_col.lightened(0.15))
	button.add_theme_color_override("font_pressed_color", text_col.darkened(0.1))
	button.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.62, 0.7))
	button.add_theme_stylebox_override("normal", _btn_box(fill, 6))
	button.add_theme_stylebox_override("hover", _btn_box(fill.lightened(0.12), 7))
	# Pressed: less shadow and nudged down — the "push" everything else fakes
	var pressed := _btn_box(fill.darkened(0.12), 1)
	pressed.content_margin_top = 12.0
	pressed.content_margin_bottom = 6.0
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled",
		_btn_box(Color(0.25, 0.25, 0.28), 2))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


static func _btn_box(fill: Color, shadow: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color(0.12, 0.09, 0.08)
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	# Lighter top edge fakes a bevel without a texture
	box.border_width_top = 3
	box.shadow_color = Color(0.05, 0.03, 0.04, 0.55)
	box.shadow_size = shadow
	box.shadow_offset = Vector2(0, float(shadow) * 0.6)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 9.0
	box.content_margin_bottom = 9.0
	return box


## Parchment panel with the same chunky outline, for overlays and pop-ups.
static func cartoon_panel(fill: Color = Color(0.16, 0.13, 0.17, 0.96)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color(0.12, 0.09, 0.08)
	box.set_border_width_all(3)
	box.set_corner_radius_all(16)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	box.shadow_size = 10
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	return box


static func _load(path: String) -> FontFile:
	if not FileAccess.file_exists(path):
		push_warning("[UiTheme] font missing: %s" % path)
		return null
	var f := FontFile.new()
	var err := f.load_dynamic_font(path)
	if err != OK:
		push_warning("[UiTheme] could not load %s (err %d)" % [path, err])
		return null
	return f
