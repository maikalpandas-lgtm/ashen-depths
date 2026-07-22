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
