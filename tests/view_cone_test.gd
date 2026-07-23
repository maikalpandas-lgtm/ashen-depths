extends SceneTree
## The minimap cone must point where the player faces and never leak backwards.
## Mirrors the wedge test from Minimap._draw_view_cone.

const TILE := 16.0
const SPREAD := 0.62


func in_cone(dx: int, dy: int, f: Vector2i) -> bool:
	var reach: float = TILE * 3.4
	var depth: float = float(dx * f.x + dy * f.y)
	var side: float = absf(float(dx * -f.y + dy * f.x))
	if depth <= 1.0 or depth > reach:
		return false
	return side <= depth * SPREAD


func _init() -> void:
	var failed := 0
	for f in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
		# straight ahead is lit
		if not in_cone(f.x * 20, f.y * 20, f):
			printerr("  FAIL facing %s: straight ahead is dark" % f)
			failed += 1
		# straight behind is never lit
		if in_cone(-f.x * 20, -f.y * 20, f):
			printerr("  FAIL facing %s: the cone leaks backwards" % f)
			failed += 1
		# sideways is not lit
		var side := Vector2i(-f.y, f.x)
		if in_cone(side.x * 20, side.y * 20, f):
			printerr("  FAIL facing %s: the cone leaks sideways" % f)
			failed += 1
		# it widens: at depth 30 it reaches further across than at depth 10
		var narrow := in_cone(f.x * 10 + side.x * 12, f.y * 10 + side.y * 12, f)
		var wide := in_cone(f.x * 30 + side.x * 12, f.y * 30 + side.y * 12, f)
		if narrow or not wide:
			printerr("  FAIL facing %s: cone does not widen with distance" % f)
			failed += 1
	if failed == 0:
		print("  ok   view cone points the right way (4 facings)")
	quit(1 if failed > 0 else 0)
