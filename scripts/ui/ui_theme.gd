extends RefCounted
## Fantasy typography, one place.
##
## Two faces, used for different jobs on purpose:
##   TITLE — Cinzel, an engraved roman. Reads as carved stone, stays legible in
##           caps at small sizes, so it carries card names and headings.
##   BODY  — MedievalSharp, a quill hand. Full of character but mushy below
##           ~13px, so it never gets card rules text or HP numbers.
##
## Both are SIL Open Font License (licences sit next to the files); free to ship
## in a commercial build.

const TITLE_PATH := "res://assets/fonts/Cinzel.ttf"
const BODY_PATH := "res://assets/fonts/MedievalSharp.ttf"

static var _title: FontFile = null
static var _body: FontFile = null


static func title_font() -> FontFile:
	if _title == null:
		_title = _load(TITLE_PATH)
	return _title


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
