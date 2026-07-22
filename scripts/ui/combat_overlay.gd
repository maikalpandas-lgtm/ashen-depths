extends CanvasLayer
## Card combat, fought IN PLACE. The corridor stays on screen and the pack keeps
## standing where it stood — this is a HUD over the 3D view, not a separate
## scene that re-draws the enemies in a row.
##
## Targeting is a drag: press a card, a line follows the cursor, release over an
## enemy to play it there. HP bars and intents are projected onto the world
## sprites with Camera3D.unproject_position, so the numbers sit on the actual
## monster rather than on a UI copy of it.
##
## No board (DESIGN §7.0). Rules live in combat_state.gd, which has no idea any
## of this exists.

const CardDB = preload("res://scripts/cards/card_db.gd")
const CardView = preload("res://scripts/ui/card_view.gd")
const Combat = preload("res://scripts/combat/combat_state.gd")
const Party = preload("res://scripts/party.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const EnemySprites = preload("res://scripts/enemy_sprites.gd")

const CARD_W := 138
const CARD_H := 193
const DRAG_LIFT := 26.0  ## how far a held card rises out of the hand

var _combat: Combat = null
var _source: Node3D = null  ## pack node in the world, freed on victory
var _enemy_nodes: Array = []  ## world node per combat.enemies index
var _dragging: int = -1  ## hand index being dragged, -1 = none
var _drag_from := Vector2.ZERO
## Rebuilding the hand happens on the next frame, never inside a card's own
## button signal: freeing the button that is mid-emit makes add_child fail with
## "parent node is busy setting up children" and the hand vanishes.
var _hand_dirty := false
## Card face nodes by hand index, so a held card can be lifted WITHOUT rebuilding
## the row it lives in.
var _card_views: Array = []
## Screen slashes left by enemy swings: {points, age}. Faded out in _process.
var _slashes: Array = []
var _shake := 0.0  ## camera kick when the party is hit
var _fx_layer: Control = null

## Combat framing: a dedicated camera and light, both dropped in for the fight
## and removed after. Fighting through the crawler camera put the pack tiny,
## unlit and half-hidden behind the player's own torch.
var _cam: Camera3D = null
var _stage_light: OmniLight3D = null
var _viewmodel: Node3D = null

var _root: Control = null
var _world_layer: Control = null  ## HP bars drawn over the 3D view
var _line_layer: Control = null  ## the targeting line
var _hand_row: HBoxContainer = null
var _status: Label = null
var _banner: Label = null
var _log: Label = null
var _end_button: Button = null


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false
	if GameState and GameState.has_signal("combat_requested"):
		GameState.combat_requested.connect(_on_combat_requested)


func _on_combat_requested(pack: Array, source: Node) -> void:
	if _root.visible:
		return
	_source = source as Node3D
	_collect_enemy_nodes()
	var party: Party = GameState.party if GameState and GameState.party else Party.new()
	var fight_seed: int = (GameState.current_seed if GameState else 1) + Time.get_ticks_msec()
	_combat = Combat.new(party, pack, fight_seed)
	_dragging = -1
	_face_the_pack()
	_form_up()
	_enter_combat_view()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


## The pack node holds one Enemy_* child per member, in pack order.
func _collect_enemy_nodes() -> void:
	_enemy_nodes.clear()
	if not is_instance_valid(_source):
		return
	for child in _source.get_children():
		if child is Node3D and str(child.name).begins_with("Enemy_"):
			_enemy_nodes.append(child)


## Line the pack up across the corridor, facing whoever just walked in.
##
## In the world they are scattered around their tile, so depending on which way
## the player arrived some ended up BEHIND the others and could not be seen or
## clicked. Combat re-forms them into a row perpendicular to the approach, which
## also means the same pack reads the same from any direction.
func _form_up() -> void:
	if not is_instance_valid(_source) or _enemy_nodes.is_empty():
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D

	# "Forward" = from player toward pack (along corridor). Row spreads on `right`.
	var forward := _source.global_position - player.global_position
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	# Pull the line slightly toward the player so fat sprites sit in free air,
	# not half-buried in the rock wall behind the pack tile.
	var center: Vector3 = _source.global_position - forward * 0.35

	var dungeon := _source.get_parent().get_parent() if _source.get_parent() else null
	var n := _enemy_nodes.size()
	# Corridor free width ~2.0–2.2m. Prefer a clear left→right row even if tight:
	# grubs are wide (~1m art) so for 3+ we use denser spacing + slight scale-down.
	var half_span: float = 0.95 if n <= 2 else 1.05
	var spacing: float = 0.0 if n <= 1 else (2.0 * half_span) / float(n - 1)
	var combat_scale: float = 1.0 if n <= 2 else (0.82 if n == 3 else 0.72)

	for i in range(n):
		var node := _enemy_nodes[i] as Node3D
		if not is_instance_valid(node):
			continue
		var offset := (float(i) - float(n - 1) * 0.5) * spacing
		var spot: Vector3 = center + right * offset
		var ground := spot.y
		if dungeon and dungeon.has_method("floor_height_at"):
			ground = float(dungeon.call("floor_height_at", spot.x, spot.z))
		node.global_position = Vector3(spot.x, ground, spot.z)
		node.scale = Vector3(combat_scale, combat_scale, combat_scale)
		# Billboard FIXED_Y on the sprite handles facing — don't yaw the holder


## Turn the crawler to look at the pack. The trigger fires from the neighbouring
## tile, so they stand one cell ahead — but the player may have arrived sideways.
func _face_the_pack() -> void:
	if not is_instance_valid(_source):
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D
	var to_pack := _source.global_position - player.global_position
	to_pack.y = 0.0
	if to_pack.length() < 0.01:
		return
	# Grid crawler: snap to the nearest 90°, never a loose angle
	var yaw := atan2(-to_pack.x, -to_pack.z)
	player.rotation.y = round(yaw / (PI * 0.5)) * (PI * 0.5)


## Frame the pack: camera pulled back and lifted, looking slightly down so the
## monsters sit in the upper half above the hand, plus a light so they are not
## silhouettes. The player's hands are hidden — they fill a third of the screen
## and there is nothing to swing during a card fight.
func _enter_combat_view() -> void:
	if not is_instance_valid(_source):
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D

	_viewmodel = player.get_node_or_null("Head/Camera3D/ViewModel") as Node3D
	if _viewmodel:
		_viewmodel.visible = false

	var pack: Vector3 = _source.global_position
	var back := (player.global_position - pack)
	back.y = 0.0
	if back.length() < 0.01:
		back = Vector3.BACK
	back = back.normalized()

	_cam = Camera3D.new()
	# Wider FOV + step back so a 3-wide pack fits side-by-side on screen
	_cam.fov = 68.0
	_cam.near = 0.05
	_cam.far = 40.0
	get_tree().current_scene.add_child(_cam)
	_cam.global_position = pack + back * 4.1 + Vector3.UP * 2.15
	_cam.look_at(pack + Vector3.UP * 0.7, Vector3.UP)
	_cam.current = true

	_stage_light = OmniLight3D.new()
	_stage_light.light_color = Color(1.0, 0.9, 0.78)
	_stage_light.light_energy = 4.2
	_stage_light.omni_range = 7.0
	_stage_light.omni_attenuation = 1.1
	get_tree().current_scene.add_child(_stage_light)
	_stage_light.global_position = pack + Vector3.UP * 2.6 + back * 1.2


func _exit_combat_view() -> void:
	if _viewmodel and is_instance_valid(_viewmodel):
		_viewmodel.visible = true
	_viewmodel = null
	if _cam and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	if _stage_light and is_instance_valid(_stage_light):
		_stage_light.queue_free()
	_stage_light = null
	# Hand the view back to the crawler
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var pc := (players[0] as Node3D).get_node_or_null("Head/Camera3D") as Camera3D
		if pc:
			pc.current = true


func _close() -> void:
	_exit_combat_view()
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_combat = null
	_source = null
	_enemy_nodes.clear()


func _process(_delta: float) -> void:
	if not _root.visible:
		return
	# Never rebuild mid-drag: freeing the pressed button kills its button_up,
	# and the card would stick to the cursor forever.
	if _hand_dirty and _dragging < 0:
		_hand_dirty = false
		_render_hand()
	_world_layer.queue_redraw()
	# Always, not only while dragging: a canvas item keeps its last draw, so
	# skipping this left the targeting line burned on screen after the hit.
	_line_layer.queue_redraw()

	if not _slashes.is_empty():
		for f in _slashes:
			f["age"] += _delta
		_slashes = _slashes.filter(func(f): return f["age"] < 0.45)
		_fx_layer.queue_redraw()
	if _shake > 0.0 and _cam:
		_shake = maxf(0.0, _shake - _delta * 4.0)
		_cam.h_offset = sin(Time.get_ticks_msec() * 0.06) * _shake
		_cam.v_offset = cos(Time.get_ticks_msec() * 0.083) * _shake * 0.6


# ---------------------------------------------------------------- construction

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Only a soft floor gradient — the corridor must stay visible
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.5)
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -212
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	_world_layer = Control.new()
	_world_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_layer.draw.connect(_draw_world_overlay)
	_root.add_child(_world_layer)

	_fx_layer = Control.new()
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.draw.connect(_draw_fx)
	_root.add_child(_fx_layer)

	_line_layer = Control.new()
	_line_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_line_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_layer.draw.connect(_draw_target_line)
	_root.add_child(_line_layer)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 10
	_banner.offset_bottom = 48
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.as_display(_banner, 26, Color(1.0, 0.86, 0.6))
	_root.add_child(_banner)

	_log = Label.new()
	_log.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_log.offset_top = 50
	_log.offset_bottom = 74
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.as_title(_log, 13, Color(0.72, 0.8, 0.86))
	_root.add_child(_log)

	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 26
	_status.offset_top = -212
	_status.offset_right = 470
	_status.offset_bottom = -178
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.as_title(_status, 19, Color(0.95, 0.96, 1.0))
	_root.add_child(_status)

	_hand_row = HBoxContainer.new()
	_hand_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hand_row.offset_left = 200
	_hand_row.offset_right = -210
	_hand_row.offset_top = -CARD_H - 30
	_hand_row.offset_bottom = -14
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_row.add_theme_constant_override("separation", 6)
	_root.add_child(_hand_row)

	_end_button = Button.new()
	_end_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_end_button.offset_left = -190
	_end_button.offset_top = -120
	_end_button.offset_right = -26
	_end_button.offset_bottom = -62
	UiTheme.style_button(_end_button, 18)
	_end_button.pressed.connect(_on_end_turn)
	_root.add_child(_end_button)


# ------------------------------------------------------------------- rendering

func _refresh() -> void:
	if _combat == null:
		return
	_hand_dirty = true
	_sync_world_sprites()

	_status.text = "⚡ %d/%d    🛡 %d    🦴 %d    ❤ %d" % [
		_combat.energy, Combat.START_ENERGY, _combat.party_block,
		_combat.bones, _party_hp(),
	]
	_log.text = "   ·   ".join(_combat.log_lines.slice(maxi(0, _combat.log_lines.size() - 2)))

	match _combat.phase:
		Combat.Phase.WON:
			_banner.text = "СТАЯ ПОБИТА"
			_end_button.text = "ДАЛЬШЕ"
		Combat.Phase.LOST:
			_banner.text = "ДРУЖИНА ПАЛА"
			_end_button.text = "ДАЛЬШЕ"
		_:
			_banner.text = "ХОД %d" % _combat.turn
			_end_button.text = "КОНЕЦ ХОДА"


## Fade a corpse, and light up whichever monster the dragged card is aimed at.
func _sync_world_sprites() -> void:
	var hovered := _hover_enemy() if _dragging >= 0 else -1
	for i in range(mini(_enemy_nodes.size(), _combat.enemies.size())):
		var node := _enemy_nodes[i] as Node3D
		if not is_instance_valid(node):
			continue
		var spr := node.get_node_or_null("Sprite") as Sprite3D
		if spr == null:
			continue
		var dead := int(_combat.enemies[i]["hp"]) <= 0
		spr.transparency = 0.75 if dead else 0.0
		# Targeted monster glows; a rectangle around its HP bar was too subtle
		spr.modulate = Color(1.7, 1.55, 1.15) if i == hovered else Color.WHITE


## HP bar + intent, drawn over each monster where it actually stands.
func _draw_world_overlay() -> void:
	if _combat == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var font := UiTheme.title_font()
	var hovered := _hover_enemy() if _dragging >= 0 else -1
	for i in range(mini(_enemy_nodes.size(), _combat.enemies.size())):
		var node := _enemy_nodes[i] as Node3D
		var e: Dictionary = _combat.enemies[i]
		if not is_instance_valid(node) or int(e["hp"]) <= 0:
			continue
		var head: Vector3 = node.global_position + Vector3.UP * _enemy_top(i)
		if cam.is_position_behind(head):
			continue
		var p := cam.unproject_position(head)
		# A tall monster projects its bar up into the banner and log. Keep the
		# readouts below them and clear of the hand at the bottom.
		p.y = clampf(p.y, 100.0, _world_layer.size.y - 260.0)

		var w := 108.0
		var bar := Rect2(p.x - w * 0.5, p.y - 6.0, w, 12.0)
		_world_layer.draw_rect(bar.grow(2.0), Color(0.05, 0.04, 0.06, 0.85))
		_world_layer.draw_rect(bar, Color(0.22, 0.09, 0.1, 0.95))
		var frac: float = clampf(float(e["hp"]) / maxf(1.0, float(e["max_hp"])), 0.0, 1.0)
		_world_layer.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)),
			Color(0.78, 0.26, 0.28))
		if i == hovered:
			_world_layer.draw_rect(bar.grow(5.0), Color(1.0, 0.85, 0.4), false, 2.0)

		if font == null:
			continue
		_world_layer.draw_string(font, p + Vector2(-w * 0.5, 26.0),
			"%d/%d" % [e["hp"], e["max_hp"]],
			HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(0.95, 0.9, 0.88))
		var it: Dictionary = e["intent"]
		var is_block: bool = it.get("type", "attack") == "block"
		_world_layer.draw_string(font, p + Vector2(-w * 0.5, -16.0),
			("🛡 %d" if is_block else "🗡 %d") % it.get("value", 0),
			HORIZONTAL_ALIGNMENT_CENTER, w, 20,
			Color(0.6, 0.85, 1.0) if is_block else Color(1.0, 0.62, 0.42))
		_world_layer.draw_string(font, p + Vector2(-w * 0.5, 44.0), str(e["name"]),
			HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.86, 0.83, 0.79))
		if int(e["block"]) > 0:
			_world_layer.draw_string(font, p + Vector2(w * 0.5 + 6.0, 8.0),
				"🛡%d" % e["block"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.7, 0.88, 1.0))


## Slashes left on screen by an enemy swing, fading out.
func _draw_fx() -> void:
	for f in _slashes:
		var t: float = clampf(float(f["age"]) / 0.45, 0.0, 1.0)
		var a: float = (1.0 - t) * (1.0 - t)
		var pts: PackedVector2Array = f["points"]
		_fx_layer.draw_polyline(pts, Color(0.05, 0.02, 0.03, a * 0.75), 16.0, true)
		_fx_layer.draw_polyline(pts, Color(0.95, 0.25, 0.22, a), 6.0, true)


## A claw mark torn across the screen. Angle and length vary so repeated hits
## never draw the same stroke twice.
func _spawn_slash(strength: int) -> void:
	var size := _root.size
	var centre := Vector2(
		randf_range(size.x * 0.28, size.x * 0.72),
		randf_range(size.y * 0.22, size.y * 0.55))
	var angle := randf_range(-0.9, -0.35) + (PI if randf() < 0.5 else 0.0)
	var length: float = clampf(160.0 + float(strength) * 22.0, 160.0, 520.0)
	var dir := Vector2(cos(angle), sin(angle))
	var pts := PackedVector2Array()
	for i in range(9):
		var t := float(i) / 8.0 - 0.5
		# slight bow, so it reads as a claw rather than a ruler line
		pts.append(centre + dir * (t * length) + dir.orthogonal() * (1.0 - abs(t * 2.0)) * 26.0)
	_slashes.append({"points": pts, "age": 0.0})


## Play whatever combat_state just reported.
func _play_events() -> void:
	if _combat == null:
		return
	for ev in _combat.events:
		var i: int = int(ev["index"])
		match ev["kind"]:
			"enemy_hit":
				_flinch_enemy(i)
			"enemy_died":
				_split_enemy(i)
			"enemy_attack":
				_lunge_enemy(i)
				_spawn_slash(int(ev["amount"]))
				_shake = maxf(_shake, 0.06 + float(ev["amount"]) * 0.004)
	_combat.events.clear()


func _enemy_sprite(index: int) -> Sprite3D:
	if index < 0 or index >= _enemy_nodes.size():
		return null
	var node := _enemy_nodes[index] as Node3D
	if not is_instance_valid(node):
		return null
	return node.get_node_or_null("Sprite") as Sprite3D


## Struck: a short white flash and a knock backwards.
func _flinch_enemy(index: int) -> void:
	var spr := _enemy_sprite(index)
	if spr == null:
		return
	var base := spr.position
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "modulate", Color(3.0, 2.4, 2.4), 0.05)
	tw.tween_property(spr, "position", base + Vector3(0.0, 0.06, 0.22), 0.06)
	tw.chain().set_parallel(true)
	tw.tween_property(spr, "modulate", Color.WHITE, 0.16)
	tw.tween_property(spr, "position", base, 0.16)


## Swinging: lunge at the camera and settle back.
func _lunge_enemy(index: int) -> void:
	if index < 0 or index >= _enemy_nodes.size():
		return
	var node := _enemy_nodes[index] as Node3D
	if not is_instance_valid(node):
		return
	var base := node.position
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", base + Vector3(0.0, 0.1, 0.75), 0.13)
	tw.tween_property(node, "position", base, 0.22)


## Death: cut the sprite down the middle and throw the halves apart.
##
## The halves cannot keep the fixed-Y billboard — it would overwrite any spin
## we put on them — so they hang under a holder that is yawed at the camera once
## and then rotate freely inside it.
func _split_enemy(index: int) -> void:
	var spr := _enemy_sprite(index)
	if spr == null or spr.texture == null:
		return
	var node := _enemy_nodes[index] as Node3D
	var tex := spr.texture
	var cam := get_viewport().get_camera_3d()
	spr.visible = false

	var holder := Node3D.new()
	holder.position = spr.position
	node.add_child(holder)
	if cam:
		var to_cam := cam.global_position - node.global_position
		holder.global_rotation = Vector3(0.0, atan2(to_cam.x, to_cam.z), 0.0)

	var half_w := tex.get_width() / 2
	for side in [-1, 1]:
		var piece := Sprite3D.new()
		piece.texture = tex
		piece.pixel_size = spr.pixel_size
		piece.centered = true
		piece.transparent = true
		piece.shaded = false
		piece.double_sided = true
		piece.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		piece.alpha_scissor_threshold = 0.2
		piece.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		piece.render_priority = 4
		piece.region_enabled = true
		piece.region_rect = Rect2(
			0 if side < 0 else half_w, 0, half_w, tex.get_height())
		piece.position = Vector3(float(side) * half_w * 0.5 * spr.pixel_size, 0.0, 0.0)
		holder.add_child(piece)

		var away := Vector3(float(side) * 0.75, -0.15, 0.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(piece, "position", piece.position + away, 0.55)
		tw.tween_property(piece, "rotation_degrees:z", float(side) * -55.0, 0.55)
		tw.tween_property(piece, "transparency", 1.0, 0.55)
	get_tree().create_timer(0.7, true, false, true).timeout.connect(
		func(): if is_instance_valid(holder): holder.queue_free())


## Arc from the held card to the cursor, like the reference.
func _draw_target_line() -> void:
	if _dragging < 0:
		return
	var mouse := _line_layer.get_local_mouse_position()
	var target := _hover_enemy()
	var colour := Color(0.55, 0.95, 0.5) if target >= 0 else Color(0.78, 0.8, 0.82, 0.75)

	# Quadratic bend so the line arcs up out of the hand instead of cutting
	# straight across the board
	var lift: float = minf(190.0, _drag_from.distance_to(mouse) * 0.45)
	var mid := _drag_from.lerp(mouse, 0.5) - Vector2(0.0, lift)

	# A string of beads rather than a stroke — that is what the reference does,
	# and it reads as an aimed throw instead of a drawn ruler line.
	const BEADS := 16
	for i in range(BEADS):
		var t := float(i) / float(BEADS - 1)
		var pos := _drag_from.lerp(mid, t).lerp(mid.lerp(mouse, t), t)
		# grows toward the cursor, so the eye follows it to the target
		var r: float = lerpf(3.0, 8.5, t)
		_line_layer.draw_circle(pos, r + 2.0, Color(0.04, 0.05, 0.07, 0.65))
		_line_layer.draw_circle(pos, r, colour)
	# Head of the throw
	_line_layer.draw_circle(mouse, 16.0, Color(colour, 0.28))
	_line_layer.draw_circle(mouse, 10.0, Color(0.04, 0.05, 0.07, 0.7))
	_line_layer.draw_circle(mouse, 7.5, colour)


func _render_hand() -> void:
	for c in _hand_row.get_children():
		_hand_row.remove_child(c)
		c.queue_free()
	_card_views.clear()
	for i in range(_combat.deck.hand.size()):
		_hand_row.add_child(_make_hand_card(i))


func _make_hand_card(index: int) -> Control:
	var entry: Dictionary = _combat.deck.hand[index]
	var card: Dictionary = CardDB.get_card(entry["card"])
	var owner_colour := Color(0.7, 0.7, 0.7)
	for m in _combat.party.members:
		if m["id"] == entry["owner"]:
			owner_colour = m["colour"]

	var playable := _combat.can_play(index)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(CARD_W, CARD_H + DRAG_LIFT)

	# Aura behind the held card, so it is obvious which one is in the air
	if index == _dragging:
		var aura := Panel.new()
		aura.set_anchors_preset(Control.PRESET_FULL_RECT)
		aura.offset_left = -14
		aura.offset_top = -14
		aura.offset_right = 14
		aura.offset_bottom = 14 - DRAG_LIFT
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(1.0, 0.88, 0.45, 0.22)
		glow.border_color = Color(1.0, 0.9, 0.55, 0.9)
		glow.set_border_width_all(3)
		glow.set_corner_radius_all(14)
		glow.shadow_color = Color(1.0, 0.82, 0.35, 0.55)
		glow.shadow_size = 16
		aura.add_theme_stylebox_override("panel", glow)
		aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(aura)

	var view := CardView.build(card, owner_colour, Vector2(CARD_W, CARD_H))
	# Unplayable cards grey out rather than vanish (§7.4); the held one lifts
	view.modulate = Color.WHITE if playable else Color(0.5, 0.5, 0.55, 0.8)
	view.position = Vector2(0.0, 0.0 if index == _dragging else DRAG_LIFT)
	holder.add_child(view)
	_card_views.append(view)

	var hit := Button.new()
	hit.flat = true
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.disabled = not playable or _combat.phase != Combat.Phase.PLAYER
	hit.button_down.connect(func(): _start_drag(index, holder))
	hit.button_up.connect(_finish_drag)
	holder.add_child(hit)

	return holder


# ---------------------------------------------------------------- interaction

func _start_drag(index: int, holder: Control) -> void:
	if _combat == null or _combat.phase != Combat.Phase.PLAYER:
		return
	_dragging = index
	_drag_from = holder.global_position + holder.size * 0.5
	# Lift the existing node. Rebuilding here is what broke the drag: it freed
	# the very button that is mid-press, so button_up never arrived.
	if index < _card_views.size() and is_instance_valid(_card_views[index]):
		(_card_views[index] as Control).position = Vector2.ZERO


## Released: over an enemy it resolves there; a card that needs no target
## resolves anywhere; otherwise it simply drops back into the hand.
func _finish_drag() -> void:
	if _combat == null or _dragging < 0:
		return
	var index := _dragging
	_dragging = -1
	if index >= _combat.deck.hand.size():
		_refresh()
		return
	if not _combat.can_play(index):
		_refresh()
		return
	var card := CardDB.get_card(_combat.deck.hand[index]["card"])
	if int(card["damage"]) <= 0:
		_combat.play_card(index, 0)
	else:
		var target := _hover_enemy()
		if target < 0:
			target = _only_living_enemy()
		if target >= 0:
			_combat.play_card(index, target)
		else:
			# Missed the drop: give a short log so it doesn't feel broken
			if _status:
				_status.text = "наведи карту на врага"
	_play_events()
	_refresh()


## One living foe left → always a valid target (solo packs / last standing).
func _only_living_enemy() -> int:
	if _combat == null:
		return -1
	var found := -1
	for i in range(_combat.enemies.size()):
		if int(_combat.enemies[i]["hp"]) <= 0:
			continue
		if found >= 0:
			return -1  # more than one
		found = i
	return found


## Which living enemy the cursor is over, by screen distance to its sprite.
func _hover_enemy() -> int:
	if _combat == null:
		return -1
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return -1
	# Viewport coords — matches Camera3D.unproject_position (not Control-local)
	var mouse := get_viewport().get_mouse_position()
	var best := -1
	var best_d := 260.0  # generous — fat sprites + offset UI
	for i in range(mini(_enemy_nodes.size(), _combat.enemies.size())):
		var node := _enemy_nodes[i] as Node3D
		if not is_instance_valid(node) or int(_combat.enemies[i]["hp"]) <= 0:
			continue
		var top_h := _enemy_top(i)
		# Test mid + a few points on the silhouette so tall/short enemies all hit
		var points: Array[Vector3] = [
			node.global_position + Vector3.UP * (top_h * 0.55),
			node.global_position + Vector3.UP * (top_h * 0.25),
			node.global_position + Vector3.UP * (top_h * 0.85),
		]
		for mid in points:
			if cam.is_position_behind(mid):
				continue
			var d := cam.unproject_position(mid).distance_to(mouse)
			if d < best_d:
				best_d = d
				best = i
	return best


func _enemy_top(index: int) -> float:
	var id: String = _combat.enemies[index]["id"]
	var def: Dictionary = EnemySprites.ENEMIES.get(id, {})
	return float(def.get("height", 1.6)) + 0.35


func _on_end_turn() -> void:
	if _combat == null:
		return
	match _combat.phase:
		Combat.Phase.WON:
			_finish_victory()
		Combat.Phase.LOST:
			_finish_defeat()
		_:
			_dragging = -1
			_combat.end_turn()
			_play_events()
			_refresh()


func _finish_victory() -> void:
	var reward := 10 + _combat.turn * 2
	if GameState:
		GameState.gold += reward
	if is_instance_valid(_source):
		# Clear the grid cell too, or the minimap keeps its skull forever
		var dungeon := _source.get_parent().get_parent() if _source.get_parent() else null
		if dungeon and dungeon.has_method("clear_encounter_at"):
			dungeon.call("clear_encounter_at", _source.global_position)
		_source.queue_free()
	_close()
	# Layer 1 draft — pick a card or skip for gold (DESIGN §7.6)
	if GameState and GameState.has_signal("draft_requested"):
		GameState.draft_requested.emit(reward)


func _finish_defeat() -> void:
	_close()
	var defeat := get_node_or_null("../DefeatOverlay")
	if defeat and defeat.has_method("show_defeat"):
		defeat.call("show_defeat")
	else:
		# Fallback if overlay missing
		if GameState and GameState.party:
			for m in GameState.party.members:
				m["hp"] = maxi(1, int(m["hp"]))


func _party_hp() -> int:
	var sum := 0
	for m in _combat.party.members:
		sum += maxi(0, int(m["hp"]))
	return sum
