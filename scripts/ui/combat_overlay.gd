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


func is_open() -> bool:
	return _root != null and _root.visible


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
	# Camera FIRST, then form_up along camera-right so the row is always
	# left↔right on screen (player/pack world axes were stacking along the tunnel).
	_enter_combat_view()
	_form_up()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Sfx:
		Sfx.play("combat_start", -2.0)
		if _pack_kind() == "floor_boss":
			Sfx.play("hit_heavy", -6.0)
	if Music:
		Music.play_combat()
	_refresh()


## The pack node holds one Enemy_* child per member, in pack order.
func _collect_enemy_nodes() -> void:
	_enemy_nodes.clear()
	if not is_instance_valid(_source):
		return
	for child in _source.get_children():
		if child is Node3D and str(child.name).begins_with("Enemy_"):
			_enemy_nodes.append(child)
	print("[Combat] pack nodes=%d kind=%s" % [_enemy_nodes.size(), _pack_kind()])


## Stage a left→right line in *camera* space. Corridor width does not matter:
## we place past the walls so every billboard has its own screen column.
func _form_up() -> void:
	if not is_instance_valid(_source) or _enemy_nodes.is_empty():
		return

	var right := Vector3.RIGHT
	var to_cam := Vector3.BACK
	if _cam and is_instance_valid(_cam):
		right = _cam.global_transform.basis.x
		right.y = 0.0
		if right.length() < 0.01:
			right = Vector3.RIGHT
		else:
			right = right.normalized()
		to_cam = _cam.global_position - _source.global_position
		to_cam.y = 0.0
		if to_cam.length() < 0.01:
			to_cam = Vector3.BACK
		else:
			to_cam = to_cam.normalized()
	else:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var player := players[0] as Node3D
			to_cam = player.global_position - _source.global_position
			to_cam.y = 0.0
			if to_cam.length() > 0.01:
				to_cam = to_cam.normalized()
			right = Vector3(-to_cam.z, 0.0, to_cam.x)

	# Slightly toward the camera so sprites clear the rock wall
	var center: Vector3 = _source.global_position + to_cam * 0.45

	var dungeon := _source.get_parent().get_parent() if _source.get_parent() else null
	var n := _enemy_nodes.size()
	# Fat grubs need large centre gaps so silhouettes don't merge
	var spacing: float = 0.0
	var combat_scale: float = 1.0
	match n:
		1:
			spacing = 0.0
			combat_scale = 1.0
		2:
			spacing = 1.85
			combat_scale = 0.9
		3:
			spacing = 1.75
			combat_scale = 0.72
		_:
			spacing = 1.5
			combat_scale = 0.62

	for i in range(n):
		var node := _enemy_nodes[i] as Node3D
		if not is_instance_valid(node):
			continue
		var offset := (float(i) - float(n - 1) * 0.5) * spacing
		# Same depth for all — pure left↔right line (no depth stacking)
		var spot: Vector3 = center + right * offset
		var ground := spot.y
		if dungeon and dungeon.has_method("floor_height_at"):
			ground = float(dungeon.call("floor_height_at", spot.x, spot.z))
		node.global_position = Vector3(spot.x, ground, spot.z)
		node.scale = Vector3(combat_scale, combat_scale, combat_scale)
	print("[Combat] form_up n=%d spacing=%.2f along camera-right" % [n, spacing])


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


## Frame the pack: camera pulled well back so a 3-wide row of fat grubs still
## reads left-to-right above the hand. Hands hidden during the fight.
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

	var n_pack: int = maxi(1, _enemy_nodes.size())
	# Far enough that a 1.75m * 2 gap row still fits with margin
	var dist: float = 5.0 if n_pack <= 2 else (6.2 if n_pack == 3 else 6.8)
	var fov: float = 72.0 if n_pack <= 2 else 82.0

	if _cam and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = Camera3D.new()
	_cam.fov = fov
	_cam.near = 0.05
	_cam.far = 40.0
	get_tree().current_scene.add_child(_cam)
	_cam.global_position = pack + back * dist + Vector3.UP * 2.5
	_cam.look_at(pack + Vector3.UP * 0.5, Vector3.UP)
	_cam.current = true

	if _stage_light and is_instance_valid(_stage_light):
		_stage_light.queue_free()
	_stage_light = OmniLight3D.new()
	_stage_light.light_color = Color(1.0, 0.9, 0.78)
	_stage_light.light_energy = 4.5
	_stage_light.omni_range = 9.0
	_stage_light.omni_attenuation = 1.0
	get_tree().current_scene.add_child(_stage_light)
	_stage_light.global_position = pack + Vector3.UP * 2.8 + back * 1.4


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
	if Music:
		Music.play_explore()


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
	# Sit clear of the left HUD (~188px) so ⚡ energy is actually readable
	_status.offset_left = 210
	_status.offset_top = -212
	_status.offset_right = 620
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
			match _pack_kind():
				"floor_boss":
					_banner.text = "СТРАЖ ЭТАЖА  ·  ход %d" % _combat.turn
				"mini_boss":
					_banner.text = "ЭЛИТА  ·  ход %d" % _combat.turn
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
	# First pass: project heads. Second: push bars apart if they collide.
	var slots: Array = []  ## {i, p: Vector2, e}
	for i in range(mini(_enemy_nodes.size(), _combat.enemies.size())):
		var node := _enemy_nodes[i] as Node3D
		var e: Dictionary = _combat.enemies[i]
		if not is_instance_valid(node) or int(e["hp"]) <= 0:
			continue
		var head: Vector3 = node.global_position + Vector3.UP * _enemy_top(i)
		if cam.is_position_behind(head):
			continue
		var p := cam.unproject_position(head)
		p.y = clampf(p.y, 100.0, _world_layer.size.y - 260.0)
		slots.append({"i": i, "p": p, "e": e})
	# Spread overlapping bars horizontally so a 3-grub pack shows 3 readouts
	slots.sort_custom(func(a, b): return a["p"].x < b["p"].x)
	const MIN_BAR_GAP := 118.0
	for s in range(1, slots.size()):
		var prev: Vector2 = slots[s - 1]["p"]
		var cur: Vector2 = slots[s]["p"]
		if cur.x - prev.x < MIN_BAR_GAP:
			cur.x = prev.x + MIN_BAR_GAP
			slots[s]["p"] = cur

	var w := 100.0
	for slot in slots:
		var i: int = int(slot["i"])
		var p: Vector2 = slot["p"]
		var e: Dictionary = slot["e"]
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
			HORIZONTAL_ALIGNMENT_CENTER, w, 18,
			Color(0.6, 0.85, 1.0) if is_block else Color(1.0, 0.62, 0.42))
		_world_layer.draw_string(font, p + Vector2(-w * 0.5, 44.0), str(e["name"]),
			HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.86, 0.83, 0.79))
		if int(e["block"]) > 0:
			_world_layer.draw_string(font, p + Vector2(w * 0.5 + 4.0, 8.0),
				"🛡%d" % e["block"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
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
				if Sfx:
					var amt: int = int(ev.get("amount", 0))
					Sfx.play("hit_heavy" if amt >= 10 else "hit", -1.0)
			"enemy_died":
				_split_enemy(i)
				if Sfx:
					Sfx.play("enemy_die", -1.0)
			"enemy_attack":
				_lunge_enemy(i)
				_spawn_slash(int(ev["amount"]))
				_shake = maxf(_shake, 0.06 + float(ev["amount"]) * 0.004)
				if Sfx:
					Sfx.play("party_hit", -1.0)
			"enemy_block":
				if Sfx:
					Sfx.play("block", -4.0)
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
	var card: Dictionary = CardDB.resolve_entry(entry)
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
	# Without this, moving the cursor off the card cancels the press — button_up
	# never fires on release over an enemy, so damage cards never resolve.
	hit.keep_pressed_outside = true
	hit.disabled = not playable or _combat.phase != Combat.Phase.PLAYER
	hit.button_down.connect(func(): _start_drag(index, holder))
	hit.button_up.connect(_finish_drag)
	holder.add_child(hit)

	return holder


# ---------------------------------------------------------------- interaction

## Global mouse-up is the reliable finish: Button.button_up alone fails when the
## release lands outside the card (which is every real target drop).
func _input(event: InputEvent) -> void:
	if not _root.visible or _dragging < 0:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()


func _start_drag(index: int, holder: Control) -> void:
	if _combat == null or _combat.phase != Combat.Phase.PLAYER:
		return
	_dragging = index
	_drag_from = holder.global_position + holder.size * 0.5
	if Sfx:
		Sfx.play("card_pick", -6.0, 0.04)
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
	var card := CardDB.resolve_entry(_combat.deck.hand[index])
	var played := false
	if int(card["damage"]) <= 0:
		played = _combat.play_card(index, 0)
	else:
		var target := _pick_damage_target()
		if target >= 0:
			played = _combat.play_card(index, target)
		else:
			# Missed the drop: give a short log so it doesn't feel broken
			if _status:
				_status.text = "наведи карту на врага  ·  ⚡ %d" % _combat.energy
			if Sfx:
				Sfx.play("miss", -4.0)
	if played:
		_sfx_card_cast(card)
	_play_events()
	_refresh()


## Whoosh / spell layer for the card that just resolved (hits still fire in events).
func _sfx_card_cast(card: Dictionary) -> void:
	if not Sfx:
		return
	Sfx.play("card_play", -8.0, 0.03)
	var ctype: int = int(card.get("type", CardDB.Type.STRIKE))
	if int(card.get("block", 0)) > 0 and int(card.get("damage", 0)) <= 0:
		Sfx.play("block", -3.0)
		return
	match ctype:
		CardDB.Type.SPELL:
			Sfx.play("spell", -2.0)
		CardDB.Type.BLOOD:
			Sfx.play("hit_heavy", -3.0)
		_:
			if int(card.get("damage", 0)) > 0:
				Sfx.play("slash", -2.0)


## Prefer the enemy under the cursor; else nearest living if the cursor left the hand.
func _pick_damage_target() -> int:
	var hovered := _hover_enemy()
	if hovered >= 0:
		return hovered
	var only := _only_living_enemy()
	if only >= 0:
		return only
	# Cursor still over the hand strip → cancel, don't auto-fire
	var mouse := get_viewport().get_mouse_position()
	var vp_h := get_viewport().get_visible_rect().size.y
	if mouse.y > vp_h - 210.0:
		return -1
	# Anywhere else on the stage: hit the nearest living foe
	return _nearest_living_enemy(99999.0)


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


## Closest living enemy within max screen distance, or -1.
func _nearest_living_enemy(max_dist: float) -> int:
	if _combat == null:
		return -1
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return -1
	var mouse := get_viewport().get_mouse_position()
	var best := -1
	var best_d := max_dist
	for i in range(_combat.enemies.size()):
		if int(_combat.enemies[i]["hp"]) <= 0:
			continue
		var screen := _enemy_screen_pos(i, cam)
		if screen.x < -9000.0:
			continue
		var d: float = screen.distance_to(mouse)
		if d < best_d:
			best_d = d
			best = i
	return best


## Which living enemy the cursor is over (generous radius for fat sprites).
func _hover_enemy() -> int:
	return _nearest_living_enemy(380.0)


## Project an enemy silhouette sample to viewport pixels. Returns far-off point
## if the node/camera cannot resolve it (so distance checks fail closed).
func _enemy_screen_pos(index: int, cam: Camera3D) -> Vector2:
	if index < 0 or index >= _enemy_nodes.size():
		var n := _combat.enemies.size()
		if n <= 0:
			return Vector2(-99999, -99999)
		var vp := get_viewport().get_visible_rect().size
		var t := 0.5 if n == 1 else float(index) / float(n - 1)
		return Vector2(lerpf(vp.x * 0.22, vp.x * 0.78, t), vp.y * 0.36)
	var node := _enemy_nodes[index] as Node3D
	if not is_instance_valid(node):
		return Vector2(-99999, -99999)
	var top_h := _enemy_top(index) * maxf(node.scale.y, 0.5)
	# Sample in camera-relative lateral axes so wide billboards hit easily
	var cam_right := cam.global_transform.basis.x
	cam_right.y = 0.0
	if cam_right.length() < 0.01:
		cam_right = Vector3.RIGHT
	else:
		cam_right = cam_right.normalized()
	var base := node.global_position
	var points: Array[Vector3] = [
		base + Vector3.UP * (top_h * 0.5),
		base + Vector3.UP * (top_h * 0.2),
		base + Vector3.UP * (top_h * 0.8),
		base + Vector3.UP * (top_h * 0.45) + cam_right * 0.55,
		base + Vector3.UP * (top_h * 0.45) - cam_right * 0.55,
		base + Vector3.UP * (top_h * 0.45) + cam_right * 0.95,
		base + Vector3.UP * (top_h * 0.45) - cam_right * 0.95,
	]
	var best := Vector2(-99999, -99999)
	var best_d := INF
	var mouse := get_viewport().get_mouse_position()
	for mid in points:
		if cam.is_position_behind(mid):
			continue
		var p := cam.unproject_position(mid)
		var d := p.distance_to(mouse)
		if d < best_d:
			best_d = d
			best = p
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
			if Sfx:
				Sfx.play("end_turn", -3.0)
			_combat.end_turn()
			_play_events()
			_refresh()


func _pack_kind() -> String:
	if is_instance_valid(_source) and _source.get("pack_kind") != null:
		return str(_source.get("pack_kind"))
	return "normal"


func _finish_victory() -> void:
	var kind := _pack_kind()
	var reward := 10 + _combat.turn * 2
	var xp_gain := 16
	match kind:
		"mini_boss":
			reward = int(float(reward) * 1.6) + 10
			xp_gain = 30
		"floor_boss":
			reward = int(float(reward) * 2.4) + 20
			xp_gain = 55
	var paid := reward
	if GameState:
		paid = GameState.award_combat_gold(reward)
		GameState.grant_combat_xp(xp_gain)
		GameState.queue_combat_loot(kind)
	if Sfx:
		Sfx.play("victory", -1.0)
		Sfx.play("gold", -6.0)
	if Music:
		Music.play_jingle("win", -5.0)
	if is_instance_valid(_source):
		# Clear the grid cell too, or the minimap keeps its skull forever
		var dungeon := _source.get_parent().get_parent() if _source.get_parent() else null
		if dungeon and dungeon.has_method("clear_encounter_at"):
			dungeon.call("clear_encounter_at", _source.global_position)
		_source.queue_free()
	_close()
	# Layer 1 draft → (level-up) → item loot (DESIGN §7.6 + §8.3)
	if GameState and GameState.has_signal("draft_requested"):
		GameState.draft_requested.emit(paid)


func _finish_defeat() -> void:
	if Sfx:
		Sfx.play("defeat", -1.0)
	if Music:
		Music.play_jingle("lose", -4.0)
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
