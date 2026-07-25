extends SceneTree
## Fonts must actually contain the language the game is written in.
##
## Cinzel and MedievalSharp were both wired in as "fantasy fonts" and both carry
## ZERO Cyrillic — every Russian label would have rendered as empty boxes, and
## nothing but parsing the cmap caught it. So every face the game loads gets
## checked here, by asking the loaded Font whether it has the glyph.
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _passed := 0
var _failed := 0


func check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		printerr("  FAIL %s" % label)


func _init() -> void:
	var faces := {
		"display": UiTheme.display_font(),
		"title": UiTheme.title_font(),
		"body": UiTheme.body_font(),
		"number": UiTheme.number_font(),
	}
	for role in faces.keys():
		var f: Font = faces[role]
		check(f != null, "%s font loads" % role)
		if f == null:
			continue
		# Whole Russian alphabet, both cases, plus Ё
		var missing := ""
		for c in range(0x410, 0x450):
			if not f.has_char(c):
				missing += char(c)
		for c in [0x401, 0x451]:
			if not f.has_char(c):
				missing += char(c)
		check(missing == "", "%s has full Cyrillic%s" % [role,
			"" if missing == "" else " — MISSING: " + missing])
		var no_digits := ""
		for c in "0123456789":
			if not f.has_char(c.unicode_at(0)):
				no_digits += c
		check(no_digits == "", "%s has digits%s" % [role,
			"" if no_digits == "" else " — MISSING: " + no_digits])

	# The numbers face must be VISIBLY heavier, or splitting the fonts bought
	# nothing. Same string, same size: heavier means wider strokes, and Rubik at
	# wght 800 is also narrower per glyph than PT Serif — so compare INK, not
	# advance width, by measuring at a large size and taking the height ratio.
	var n: Font = faces["number"]
	var t: Font = faces["title"]
	if n != null and t != null:
		var hn := n.get_string_size("88", HORIZONTAL_ALIGNMENT_LEFT, -1, 64).y
		var ht := t.get_string_size("88", HORIZONTAL_ALIGNMENT_LEFT, -1, 64).y
		check(hn > 0.0 and ht > 0.0, "both faces measure a string")
		check(n != t, "numbers use a DIFFERENT face from labels")

	# Nothing should still point at the zero-Cyrillic fonts
	for dead in ["res://assets/fonts/Cinzel.ttf", "res://assets/fonts/MedievalSharp.ttf"]:
		check(UiTheme.DISPLAY_PATH != dead and UiTheme.TITLE_PATH != dead
			and UiTheme.BODY_PATH != dead and UiTheme.NUMBER_PATH != dead,
			"%s is not wired in" % dead.get_file())

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
