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
const LabelLayout = preload("res://scripts/ui/label_layout.gd")
const FanLayout = preload("res://scripts/ui/fan_layout.gd")

## Fan geometry lives in FanLayout so the test can exercise the real maths.
const CARD_W := int(FanLayout.CARD_W)
const CARD_H := int(FanLayout.CARD_H)
const DRAG_LIFT := 26.0  ## how far a held card rises out of the hand
const FLASH_TIME := 0.22  ## how long a struck monster stays lit
const POPUP_TIME := 1.1  ## how long a damage number lives
const IMPACT_TIME := 0.34  ## how long a hit burst lives
const MOTE_COUNT := 90  ## floating dust specks

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
## Hand index the cursor is over, so a card can lift and glow before it is
## even picked up — the reference previews the card you are about to play.
var _hover_card: int = -1
## Screen slashes left by enemy swings: {points, age}. Faded out in _process.
var _slashes: Array = []
var _shake := 0.0  ## camera kick when the party is hit
## Hit flash per enemy index, in seconds remaining. Sprite tint and scale have
## exactly ONE writer (_update_enemy_visuals): a tween on modulate used to be
## wiped by the next _refresh in the same frame, so no hit ever flashed.
var _enemy_flash: Dictionary = {}
## Damage numbers rising off a monster: {world, text, age, crit, colour}.
## Anchored to a WORLD point and re-projected each frame, so a number stays over
## the monster it belongs to even while the camera shakes.
var _popups: Array = []
## Impact bursts at the point a card landed: {world, age, crit}. Every hit gets
## one, mine included — a number appearing with nothing behind it reads as a
## spreadsheet, not a blow.
var _impacts: Array = []
## Floating dust motes. The reference fills its cave with slow white specks and
## they do more for the mood than any single effect — a still frame stops
## looking like a screenshot of a menu.
var _motes: Array = []
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
var _hand_row: Control = null
var _status: Label = null
var _banner: Label = null
var _log: Label = null
var _end_button: Button = null


## Formation lives in EnemySprites — the generator lays the pack out in the
## world with the same numbers, so nothing shifts when the fight opens.
static func form_spacing(pack: Array) -> float:
	return EnemySprites.form_spacing(pack)


static func form_scale(pack: Array) -> float:
	return EnemySprites.form_scale(pack)


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


## The generator records the pack in spawn order on the node. Fall back to a
## name scan only for packs built before that existed.
func _collect_enemy_nodes() -> void:
	_enemy_nodes.clear()
	if not is_instance_valid(_source):
		return
	if _source.has_meta("enemy_nodes"):
		for n in _source.get_meta("enemy_nodes"):
			if is_instance_valid(n):
				_enemy_nodes.append(n)
	if _enemy_nodes.is_empty():
		for child in _source.get_children():
			if child is Node3D and str(child.name).begins_with("Enemy_"):
				_enemy_nodes.append(child)
	print("[Combat] pack nodes=%d kind=%s" % [_enemy_nodes.size(), _pack_kind()])


## Stage a left→right line in *camera* space, so the row reads the same however
## the player walked in. Spacing is tuned to keep it inside the corridor now
## that corridors are wide enough to hold a pack.
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
	# Same numbers the generator used in the world
	var pack_ids: Array = []
	for e in _combat.enemies:
		pack_ids.append(e["id"])
	var layout := EnemySprites.form_layout(pack_ids)
	var spacing := float(layout["spacing"])
	var combat_scale := float(layout["scale"])

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
	# Closer than before: the art is the reason these monsters were drawn, and
	# at 5-7m they were postage stamps. A narrower FOV keeps a wide pack framed
	# without having to back away from it.
	# A touch further back than the closest framing: at 3.4m a big monster fills
	# the frame and its name/HP had nowhere to sit but on its own legs.
	var dist: float = 4.1 if n_pack <= 2 else (4.8 if n_pack == 3 else 5.4)
	var fov: float = 60.0 if n_pack <= 2 else 68.0

	if _cam and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = Camera3D.new()
	_cam.fov = fov
	_cam.near = 0.05
	_cam.far = 40.0
	get_tree().current_scene.add_child(_cam)
	# Looking a little higher lifts the monsters up the frame, which is what
	# leaves clear floor under them for the labels.
	_cam.global_position = pack + back * dist + Vector3.UP * 2.1
	_cam.look_at(pack + Vector3.UP * 1.15, Vector3.UP)
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

	_update_motes(_delta)
	_update_enemy_visuals(_delta)
	if not _impacts.is_empty():
		for imp in _impacts:
			imp["age"] += _delta
		_impacts = _impacts.filter(func(imp): return imp["age"] < IMPACT_TIME)
		_fx_layer.queue_redraw()
	if not _popups.is_empty():
		for pop in _popups:
			pop["age"] += _delta
		_popups = _popups.filter(func(pop): return pop["age"] < POPUP_TIME)
		_fx_layer.queue_redraw()
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

	# No shade strip behind the hand: the cards are opaque and carry their own
	# outline, so a translucent band only muddied the corridor beneath them.

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

	# Free positioning, not a box container: a fan needs per-card rotation and
	# overlap, which no container will do.
	_hand_row = Control.new()
	_hand_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hand_row.offset_left = 250
	_hand_row.offset_right = -230
	_hand_row.offset_top = -CARD_H - 64
	_hand_row.offset_bottom = -8
	_hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hand_row)

	_end_button = Button.new()
	_end_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_end_button.offset_left = -210
	_end_button.offset_top = -126
	_end_button.offset_right = -26
	_end_button.offset_bottom = -58
	UiTheme.cartoon_button(_end_button, 19, Color(0.20, 0.56, 0.46))
	_end_button.pressed.connect(_on_end_turn)
	_root.add_child(_end_button)


# ------------------------------------------------------------------- rendering

func _refresh() -> void:
	if _combat == null:
		return
	_hand_dirty = true
	_sync_world_visibility()

	var hp_now := _party_hp()
	var hp_max := _party_max_hp()
	_status.text = "⚡ %d/%d    🛡 %d    🦴 %d    ❤ %d/%d" % [
		_combat.energy, Combat.START_ENERGY, _combat.party_block,
		_combat.bones, hp_now, hp_max,
	]
	_log.text = "   ·   ".join(_combat.log_lines.slice(maxi(0, _combat.log_lines.size() - 2)))
	# Keep left HUD in sync — party HP lives on GameState.party (same ref)
	_sync_left_hud()

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


## Tint and scale of every living monster, recomputed each frame. One writer:
## a hit flash and the hover highlight both want the sprite's colour, and when
## they were separate a tween on modulate got overwritten by the next refresh
## in the same frame, so hits never flashed at all.
func _update_enemy_visuals(delta: float) -> void:
	if _combat == null or not _root.visible:
		return
	var hovered := _hover_enemy() if _dragging >= 0 else -1
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.011)
	var base_scale := _form_scale_for(0)
	for i in range(mini(_enemy_nodes.size(), _combat.enemies.size())):
		var node := _enemy_nodes[i] as Node3D
		if not is_instance_valid(node):
			continue
		var spr := node.get_node_or_null("Sprite") as Sprite3D
		if spr == null or not spr.visible:
			continue

		var flash: float = float(_enemy_flash.get(i, 0.0))
		if flash > 0.0:
			flash = maxf(0.0, flash - delta)
			_enemy_flash[i] = flash

		var tint := Color.WHITE
		var scale_f := base_scale
		if i == hovered:
			tint = Color(1.5, 1.4, 1.05).lerp(Color(2.1, 1.85, 1.25), pulse)
			scale_f *= 1.05 + 0.02 * pulse
		if flash > 0.0:
			# Blow past the hover tint — being hit must always be the loud thing
			var t: float = flash / FLASH_TIME
			tint = tint.lerp(Color(3.2, 2.5, 2.3), t)
			scale_f *= 1.0 + 0.12 * t
		spr.modulate = tint
		node.scale = Vector3.ONE * scale_f


## Corpse visibility only — tint and scale belong to _update_enemy_visuals.
func _sync_world_visibility() -> void:
	for i in range(mini(_enemy_nodes.size(), _combat.enemies.size())):
		var node := _enemy_nodes[i] as Node3D
		if not is_instance_valid(node):
			continue
		var spr := node.get_node_or_null("Sprite") as Sprite3D
		if spr == null:
			continue
		var dead := int(_combat.enemies[i]["hp"]) <= 0
		# Hide dead fully so living HP UI isn't buried under corpses
		spr.visible = not dead
		spr.transparency = 0.0


## Living enemy indices only (hp > 0). Dead never get bars or aim slots.
func _living_indices() -> Array:
	var out: Array = []
	if _combat == null:
		return out
	for i in range(_combat.enemies.size()):
		if int(_combat.enemies[i].get("hp", 0)) > 0:
			out.append(i)
	return out


## After a kill, re-spread survivors left→right. Dead stay hidden (no HP bar).
func _reform_living() -> void:
	if not is_instance_valid(_source) or _cam == null or not is_instance_valid(_cam):
		return
	var living := _living_indices()
	if living.is_empty():
		return
	var right := _cam.global_transform.basis.x
	right.y = 0.0
	if right.length() < 0.01:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var to_cam := _cam.global_position - _source.global_position
	to_cam.y = 0.0
	if to_cam.length() < 0.01:
		to_cam = Vector3.BACK
	else:
		to_cam = to_cam.normalized()
	var center: Vector3 = _source.global_position + to_cam * 0.45
	var dungeon := _source.get_parent().get_parent() if _source.get_parent() else null
	var n := living.size()
	# Re-form from the SURVIVORS' ids: once a wide brute dies, the rest can
	# spread back out instead of keeping the dead one's cramped spacing.
	var living_ids: Array = []
	for idx in living:
		if int(idx) < _combat.enemies.size():
			living_ids.append(_combat.enemies[int(idx)]["id"])
	var layout2 := EnemySprites.form_layout(living_ids)
	var spacing := float(layout2["spacing"])
	var combat_scale := float(layout2["scale"])
	for k in range(n):
		var i: int = int(living[k])
		if i >= _enemy_nodes.size():
			continue
		var node := _enemy_nodes[i] as Node3D
		if not is_instance_valid(node):
			continue
		var offset := (float(k) - float(n - 1) * 0.5) * spacing
		var spot: Vector3 = center + right * offset
		var ground := spot.y
		if dungeon and dungeon.has_method("floor_height_at"):
			ground = float(dungeon.call("floor_height_at", spot.x, spot.z))
		node.global_position = Vector3(spot.x, ground, spot.z)
		node.scale = Vector3(combat_scale, combat_scale, combat_scale)


## HP + intent only for LIVE foes. Killed mobs: no bar, no name, no intent.
func _draw_world_overlay() -> void:
	if _combat == null:
		return
	var font := UiTheme.title_font()
	var hovered := _hover_enemy() if _dragging >= 0 else -1
	var living := _living_indices()
	if living.is_empty():
		return

	var cam := get_viewport().get_camera_3d()
	var vp := _world_layer.size
	if vp.x < 8.0 or vp.y < 8.0:
		vp = get_viewport().get_visible_rect().size
	var n := living.size()

	# Bars are wider than the gap between three monsters standing shoulder to
	# shoulder, so they collided. Project everyone FIRST, then push the labels
	# apart along X before drawing any of them.
	var bar_w: float = 112.0 if n <= 2 else 92.0
	var min_gap := bar_w + 10.0
	var spots: Array[Vector2] = []
	var head_ys: Array[float] = []
	for k in range(n):
		var i: int = int(living[k])
		var p := Vector2.ZERO
		var head_y := 0.0
		var have_proj := false
		if cam and i < _enemy_nodes.size():
			var node := _enemy_nodes[i] as Node3D
			if is_instance_valid(node) and node.visible:
				# Anchor at the FEET: the reference puts name and bar UNDER its
				# monsters. Project the head separately rather than subtracting
				# a guessed height — a brute and a grub need very different
				# offsets, and guessing put the intent up by the ceiling.
				var feet: Vector3 = node.global_position
				var head: Vector3 = feet + Vector3.UP * _enemy_top(i)
				if not cam.is_position_behind(feet):
					p = cam.unproject_position(feet)
					have_proj = true
					head_y = cam.unproject_position(head).y if not cam.is_position_behind(head) else p.y - 90.0
		if not have_proj:
			var left_m := 240.0
			var usable: float = maxf(160.0, vp.x - left_m - 40.0)
			var t: float = 0.5 if n == 1 else float(k) / float(n - 1)
			p = Vector2(left_m + usable * t, 150.0)
			head_y = p.y - 90.0
		# Only a floor clamp: dragging the feet UP puts the labels on the sprite
		# Only a floor clamp, and it must clear the hand strip below
		p.y = minf(p.y, vp.y - 300.0)
		spots.append(p)
		head_ys.append(head_y)

	LabelLayout.separate(spots, min_gap, 230.0, vp.x - 50.0)

	for k in range(n):
		var i: int = int(living[k])
		var e: Dictionary = _combat.enemies[i]
		# Belt-and-suspenders: never paint a corpse bar
		if int(e.get("hp", 0)) <= 0:
			continue
		var p: Vector2 = spots[k]
		# Clear of the feet, name above the bar (reference order). The gap is
		# generous because a sprite's paws and tail hang below its node origin.
		var bar := Rect2(p.x - bar_w * 0.5, p.y + 46.0, bar_w, 15.0)
		# Rounded pill, like the reference, rather than a flat rectangle
		_pill(bar.grow(2.5), Color(0.06, 0.04, 0.05, 0.95))
		_pill(bar, Color(0.30, 0.10, 0.12, 0.98))
		var frac: float = clampf(float(e["hp"]) / maxf(1.0, float(e["max_hp"])), 0.0, 1.0)
		if frac > 0.001:
			_pill(Rect2(bar.position, Vector2(maxf(bar.size.y, bar.size.x * frac), bar.size.y)),
				Color(0.88, 0.30, 0.31))
		if i == hovered:
			_pill(bar.grow(5.0), Color(1.0, 0.88, 0.35, 0.35))

		if font == null:
			continue
		# Numbers on the bar
		_world_layer.draw_string(font, Vector2(bar.position.x, bar.position.y + 12.0),
			"%d/%d" % [e["hp"], e["max_hp"]],
			HORIZONTAL_ALIGNMENT_CENTER, bar_w, 12, Color(1.0, 0.96, 0.93))
		# Name between the feet and the bar, outlined so it survives dark rock
		_outlined(font, Vector2(bar.position.x, bar.position.y - 8.0), str(e["name"]),
			bar_w, 14, Color(0.97, 0.94, 0.88))
		# Intent just over the real head, not a guessed offset
		var it: Dictionary = e["intent"]
		var is_block: bool = it.get("type", "attack") == "block"
		var intent_y: float = maxf(72.0, float(head_ys[k]) - 8.0)
		_outlined(font, Vector2(bar.position.x, intent_y),
			("🛡 %d" if is_block else "🗡 %d") % it.get("value", 0),
			bar_w, 21, Color(0.65, 0.88, 1.0) if is_block else Color(1.0, 0.66, 0.45))
		if int(e["block"]) > 0:
			_world_layer.draw_string(font, Vector2(bar.end.x + 4.0, bar.position.y + 12.0),
				"🛡%d" % e["block"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(0.7, 0.88, 1.0))


## Rounded-end bar. draw_rect gives hard corners, which read as a debug widget
## next to painted art.
func _pill(r: Rect2, col: Color) -> void:
	var radius: float = r.size.y * 0.5
	if r.size.x <= r.size.y:
		_world_layer.draw_circle(r.position + r.size * 0.5, radius, col)
		return
	_world_layer.draw_rect(Rect2(r.position.x + radius, r.position.y,
		r.size.x - radius * 2.0, r.size.y), col)
	_world_layer.draw_circle(Vector2(r.position.x + radius, r.position.y + radius), radius, col)
	_world_layer.draw_circle(Vector2(r.end.x - radius, r.position.y + radius), radius, col)


## Text with a dark outline — labels sit over rock, fire and monsters at once.
func _outlined(font: Font, at: Vector2, text: String, width: float, size: int,
		col: Color) -> void:
	for off in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5),
			Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
		_world_layer.draw_string(font, at + off, text,
			HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(0.04, 0.03, 0.04, 0.95))
	_world_layer.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


## How tall this monster looks on screen right now, so labels can sit above its
## head without guessing at a fixed pixel offset.
func _enemy_screen_height(index: int) -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null or index >= _enemy_nodes.size():
		return 120.0
	var node := _enemy_nodes[index] as Node3D
	if not is_instance_valid(node):
		return 120.0
	var feet: Vector3 = node.global_position
	var head: Vector3 = feet + Vector3.UP * _enemy_top(index)
	if cam.is_position_behind(feet) or cam.is_position_behind(head):
		return 120.0
	return absf(cam.unproject_position(feet).y - cam.unproject_position(head).y)


## Slow drifting specks, respawned forever while the fight is open.
func _update_motes(delta: float) -> void:
	var area := _root.size
	if area.x < 10.0:
		area = get_viewport().get_visible_rect().size
	while _motes.size() < MOTE_COUNT:
		_motes.append({
			"pos": Vector2(randf() * area.x, randf() * area.y * 0.75),
			"vel": Vector2(randf_range(-7.0, 7.0), randf_range(-16.0, -5.0)),
			"r": randf_range(1.2, 2.8),
			"phase": randf() * TAU,
		})
	for m in _motes:
		var pos: Vector2 = m["pos"]
		var vel: Vector2 = m["vel"]
		m["phase"] = float(m["phase"]) + delta * 1.4
		# Sway sideways so they drift rather than march
		pos += Vector2(vel.x + sin(float(m["phase"])) * 5.0, vel.y) * delta
		if pos.y < -10.0:
			pos = Vector2(randf() * area.x, area.y * 0.78)
		m["pos"] = pos
	_fx_layer.queue_redraw()


func _draw_motes() -> void:
	var area := _root.size
	for m in _motes:
		var pos: Vector2 = m["pos"]
		# Fade out towards the top of the arena
		var a: float = clampf(pos.y / maxf(area.y * 0.55, 1.0), 0.0, 1.0) * 0.5
		a *= 0.6 + 0.4 * sin(float(m["phase"]) * 0.8)
		_fx_layer.draw_circle(pos, float(m["r"]), Color(1.0, 0.98, 0.92, a))


## Burst where a blow landed: an expanding ring plus a few slash strokes.
func _draw_impacts() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for imp in _impacts:
		var t: float = clampf(float(imp["age"]) / IMPACT_TIME, 0.0, 1.0)
		var world: Vector3 = imp["world"]
		if cam.is_position_behind(world):
			continue
		var p := cam.unproject_position(world)
		var crit: bool = imp["crit"]
		var fade: float = 1.0 - t
		var colour := Color(1.0, 0.78, 0.35) if crit else Color(1.0, 0.95, 0.88)

		# Ring, opening fast and thinning as it goes
		var r: float = lerpf(10.0, 92.0 if crit else 66.0, 1.0 - pow(1.0 - t, 2.2))
		_fx_layer.draw_arc(p, r, 0.0, TAU, 28,
			Color(colour, fade * 0.85), lerpf(7.0, 1.5, t), true)
		# White core, gone almost immediately — the "spark" of contact
		if t < 0.35:
			var ct: float = t / 0.35
			_fx_layer.draw_circle(p, lerpf(26.0, 4.0, ct),
				Color(1.0, 1.0, 0.95, (1.0 - ct) * 0.85))
		# Slash strokes, angled off the seed so repeats never match
		var strokes: int = 4 if crit else 3
		for k in range(strokes):
			var a: float = float(imp["seed"]) + float(k) * (TAU / float(strokes))
			var dir := Vector2(cos(a), sin(a))
			var inner: float = r * 0.45
			var outer: float = r * (1.25 if crit else 1.1)
			_fx_layer.draw_line(p + dir * inner, p + dir * outer,
				Color(colour, fade * 0.9), lerpf(9.0, 2.0, t), true)


## Damage numbers, rising and fading. Drawn manually rather than as Labels so
## they cost nothing to spawn and cannot disturb the UI layout.
func _draw_popups() -> void:
	var cam := get_viewport().get_camera_3d()
	var font := UiTheme.display_font()
	if cam == null or font == null:
		return
	for pop in _popups:
		var t: float = clampf(float(pop["age"]) / POPUP_TIME, 0.0, 1.0)
		var world: Vector3 = pop["world"]
		if cam.is_position_behind(world):
			continue
		var p := cam.unproject_position(world)
		# Rise and drift, easing out so the number pops then floats
		p.y -= 62.0 * (1.0 - pow(1.0 - t, 2.6))
		p.x += float(pop["drift"]) * t * 34.0

		var crit: bool = pop["crit"]
		# Much larger than before. The reference throws a huge white number with
		# a small caption over it; a modest number next to a monster reads as a
		# tooltip, not as a blow landing.
		var size: int = 92 if crit else 62
		if t < 0.18:
			size = int(lerpf(float(size) * 1.45, float(size), t / 0.18))
		var alpha: float = 1.0 if t < 0.6 else (1.0 - (t - 0.6) / 0.4)
		var text: String = str(pop["text"])
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		var at := p - Vector2(w * 0.5, 0.0)
		# Heavy outline so a number stays readable over pale rock or fire
		for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2),
				Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
			_fx_layer.draw_string(font, at + off, text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.05, 0.03, 0.04, alpha))
		_fx_layer.draw_string(font, at, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(pop["colour"], alpha))
		var tag: String = str(pop.get("tag", ""))
		if tag != "":
			var tag_size := 24
			var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_CENTER, -1, tag_size).x
			var tag_at := p - Vector2(tw * 0.5, float(size) * 0.72)
			for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
				_fx_layer.draw_string(font, tag_at + off, tag,
					HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, Color(0.05, 0.03, 0.04, alpha))
			_fx_layer.draw_string(font, tag_at, tag,
				HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size,
				Color(1.0, 0.88, 0.4, alpha))


## Slashes left on screen by an enemy swing, fading out.
func _draw_fx() -> void:
	_draw_motes()
	_draw_impacts()
	_draw_popups()
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
	var any_died := false
	for ev in _combat.events:
		var i: int = int(ev["index"])
		match ev["kind"]:
			"enemy_hit":
				_flinch_enemy(i)
				_spawn_impact(i, bool(ev.get("crit", false)))
				_spawn_popup(i, int(ev["amount"]), bool(ev.get("crit", false)))
				if Sfx:
					var amt: int = int(ev.get("amount", 0))
					Sfx.play("hit_heavy" if amt >= 10 else "hit", -1.0)
			"enemy_died":
				any_died = true
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
	if any_died:
		_reform_living()


## Scale the formation gave this monster, so the hover swell can return to it
## instead of snapping everyone back to 1.0.
func _form_scale_for(_index: int) -> float:
	var pack_ids: Array = []
	for e in _combat.enemies:
		pack_ids.append(e["id"])
	return EnemySprites.form_scale(pack_ids)


func _enemy_sprite(index: int) -> Sprite3D:
	if index < 0 or index >= _enemy_nodes.size():
		return null
	var node := _enemy_nodes[index] as Node3D
	if not is_instance_valid(node):
		return null
	return node.get_node_or_null("Sprite") as Sprite3D


## Burst at chest height on the monster that was struck.
func _spawn_impact(index: int, crit: bool) -> void:
	if index < 0 or index >= _enemy_nodes.size():
		return
	var node := _enemy_nodes[index] as Node3D
	if not is_instance_valid(node):
		return
	_impacts.append({
		"world": node.global_position + Vector3.UP * (_enemy_top(index) * 0.55),
		"age": 0.0,
		"crit": crit,
		"seed": randf() * TAU,
	})


## A damage number over the monster that took it.
func _spawn_popup(index: int, amount: int, crit: bool) -> void:
	if index < 0 or index >= _enemy_nodes.size():
		return
	var node := _enemy_nodes[index] as Node3D
	if not is_instance_valid(node):
		return
	var text := str(amount)
	var colour := Color(1.0, 0.92, 0.72) if crit else Color(1.0, 0.98, 0.95)
	var tag := "КРИТ!" if crit else ""
	if amount <= 0:
		text = "0"
		tag = "БЛОК"
		colour = Color(0.7, 0.88, 1.0)
	elif int(_combat.enemies[index]["hp"]) <= 0:
		tag = "ДОБИТ"
	_popups.append({
		"world": node.global_position + Vector3.UP * (_enemy_top(index) * 1.15),
		"text": text,
		"age": 0.0,
		"crit": crit,
		"colour": colour,
		"tag": tag,
		"drift": randf_range(-1.0, 1.0),
	})


## Struck: flag the flash (drawn in _update_enemy_visuals) and knock the sprite
## back. Position is safe to tween — nothing else writes it.
func _flinch_enemy(index: int) -> void:
	_enemy_flash[index] = FLASH_TIME
	var spr := _enemy_sprite(index)
	if spr == null:
		return
	var base := spr.position
	var tw := create_tween()
	tw.tween_property(spr, "position", base + Vector3(0.0, 0.06, 0.24), 0.06)
	tw.tween_property(spr, "position", base, 0.18)


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

	# The cut runs DIAGONALLY, like the reference — a straight vertical split
	# reads as a sprite politely falling in two rather than as a sword stroke.
	# The halves are cut vertically in texture space, so tilting the whole
	# holder tilts the cut and the separation together.
	var cut_angle := deg_to_rad(randf_range(22.0, 38.0) * (1.0 if randf() < 0.5 else -1.0))
	holder.rotation.z = cut_angle

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

		# Hot edge along the cut, so the split reads as a wound rather than as
		# the sprite quietly falling in two.
		var sprite_h := float(tex.get_height()) * spr.pixel_size
		var edge := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.16, sprite_h * 1.02)
		edge.mesh = quad
		var emat := StandardMaterial3D.new()
		emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		emat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		emat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		emat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Starts white-hot: on the reference the cut is the brightest thing on
		# screen for a moment before it cools to ember.
		emat.albedo_color = Color(1.0, 1.0, 0.95, 1.0)
		emat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		emat.render_priority = 6
		edge.material_override = emat
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# On the INNER side of the half — where the cut actually is
		edge.position = Vector3(-float(side) * half_w * 0.5 * spr.pixel_size, 0.0, 0.01)
		piece.add_child(edge)

		# Apart along the local X, i.e. perpendicular to the tilted cut
		var away := Vector3(float(side) * 0.85, -0.12, 0.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(piece, "position", piece.position + away, 0.55)
		tw.tween_property(piece, "rotation_degrees:z", float(side) * -48.0, 0.55)
		tw.tween_property(piece, "transparency", 1.0, 0.55)
		# The glow dies faster than the halves: a flare at the moment of the cut,
		# not a torch carried off with the corpse.
		tw.tween_property(emat, "albedo_color", Color(1.0, 0.4, 0.15, 0.0), 0.5)
	get_tree().create_timer(0.7, true, false, true).timeout.connect(
		func(): if is_instance_valid(holder): holder.queue_free())


## Arc from the held card to the cursor, like the reference.
func _draw_target_line() -> void:
	if _dragging < 0:
		return
	var mouse := _line_layer.get_local_mouse_position()
	var target := _hover_enemy()
	var hot := target >= 0
	var colour := Color(0.62, 1.0, 0.45) if hot else Color(0.98, 0.86, 0.45)

	# Quadratic bend so the line arcs up out of the hand instead of cutting
	# straight across the board
	var lift: float = minf(190.0, _drag_from.distance_to(mouse) * 0.45)
	var mid := _drag_from.lerp(mouse, 0.5) - Vector2(0.0, lift)

	# One tapered ribbon rather than a chain of beads: sample the curve, then
	# stroke it segment by segment with the width growing toward the cursor.
	const STEPS := 26
	var pts: Array[Vector2] = []
	for i in range(STEPS + 1):
		var t := float(i) / float(STEPS)
		pts.append(_drag_from.lerp(mid, t).lerp(mid.lerp(mouse, t), t))

	var pulse: float = 0.85 + 0.15 * sin(float(Time.get_ticks_msec()) * 0.012)
	for i in range(STEPS):
		var t := float(i) / float(STEPS)
		var w: float = lerpf(6.0, 24.0, t * t) * (pulse if hot else 1.0)
		# dark liner first so the ribbon reads over pale rock as well as dark
		_line_layer.draw_line(pts[i], pts[i + 1], Color(0.05, 0.05, 0.07, 0.6), w + 7.0, true)
	for i in range(STEPS):
		var t := float(i) / float(STEPS)
		var w: float = lerpf(6.0, 24.0, t * t) * (pulse if hot else 1.0)
		var c := Color(colour, lerpf(0.4, 1.0, t))
		_line_layer.draw_line(pts[i], pts[i + 1], c, w, true)

	# Head of the throw — a soft halo with a bright core
	var head: float = 26.0 * pulse if hot else 18.0
	_line_layer.draw_circle(mouse, head + 8.0, Color(colour, 0.18))
	_line_layer.draw_circle(mouse, head, Color(colour, 0.42))
	_line_layer.draw_circle(mouse, head * 0.45, Color(1.0, 1.0, 0.95, 0.95))


func _render_hand() -> void:
	for c in _hand_row.get_children():
		_hand_row.remove_child(c)
		c.queue_free()
	_card_views.clear()
	var n := _combat.deck.hand.size()
	for i in range(n):
		_hand_row.add_child(_make_hand_card(i, n))


func _fan_slot(index: int, n: int) -> Dictionary:
	var area := _hand_row.size
	if area.x < 10.0:
		area = Vector2(900.0, FanLayout.CARD_H + 46.0)
	var raised := index == _dragging or index == _hover_card
	var slot := FanLayout.slot(index, n, area, raised, index == _dragging)
	slot["raised"] = raised
	return slot


func _make_hand_card(index: int, n: int) -> Control:
	var entry: Dictionary = _combat.deck.hand[index]
	var card: Dictionary = CardDB.resolve_entry(entry)
	var owner_colour := Color(0.7, 0.7, 0.7)
	for m in _combat.party.members:
		if m["id"] == entry["owner"]:
			owner_colour = m["colour"]

	var playable := _combat.can_play(index)
	var slot := _fan_slot(index, n)
	var raised: bool = slot["raised"] and playable

	var holder := Control.new()
	holder.size = Vector2(CARD_W, CARD_H)
	holder.custom_minimum_size = holder.size
	holder.position = slot["pos"]
	# Rotate about the bottom centre, the way a held card pivots in the fingers
	holder.pivot_offset = Vector2(CARD_W * 0.5, CARD_H)
	holder.rotation = deg_to_rad(float(slot["angle"]))
	holder.scale = Vector2.ONE * float(slot["scale"])
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if raised:
		var aura := Panel.new()
		aura.set_anchors_preset(Control.PRESET_FULL_RECT)
		var pad := 16.0 if index == _dragging else 11.0
		aura.offset_left = -pad
		aura.offset_top = -pad
		aura.offset_right = pad
		aura.offset_bottom = pad
		var glow := StyleBoxFlat.new()
		var strength := 1.0 if index == _dragging else 0.62
		glow.bg_color = Color(1.0, 0.88, 0.45, 0.18 * strength)
		glow.border_color = Color(1.0, 0.9, 0.55, 0.85 * strength)
		glow.set_border_width_all(3)
		glow.set_corner_radius_all(14)
		glow.shadow_color = Color(1.0, 0.82, 0.35, 0.6 * strength)
		glow.shadow_size = int(20.0 * strength) + 6
		aura.add_theme_stylebox_override("panel", glow)
		aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(aura)

	var view := CardView.build(card, owner_colour, Vector2(CARD_W, CARD_H))
	view.size = Vector2(CARD_W, CARD_H)
	# Unplayable cards grey out rather than vanish (§7.4)
	# Darkened, never faded: alpha let the cave show through the card face
	view.modulate = Color.WHITE if playable else Color(0.52, 0.50, 0.54)
	if raised:
		view.modulate = Color(1.12, 1.09, 1.02)
	holder.add_child(view)
	_card_views.append(view)

	var hit := Button.new()
	hit.flat = true
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Without this, moving the cursor off the card cancels the press — button_up
	# never fires on release over an enemy, so damage cards never resolve.
	hit.keep_pressed_outside = true
	hit.disabled = not playable or _combat.phase != Combat.Phase.PLAYER
	hit.focus_mode = Control.FOCUS_NONE
	hit.button_down.connect(func(): _start_drag(index, holder))
	hit.button_up.connect(_finish_drag)
	hit.mouse_entered.connect(func(): _set_hover_card(index))
	hit.mouse_exited.connect(func(): _set_hover_card(-1))
	holder.add_child(hit)

	# A raised card must draw over its neighbours, not under them
	if raised:
		holder.z_index = 10

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


## Hovering only re-lays the row when nothing is held: rebuilding mid-drag frees
## the pressed button and kills its release (see _hand_dirty).
func _set_hover_card(index: int) -> void:
	if _dragging >= 0:
		return
	if index == -1 and _hover_card == -1:
		return
	_hover_card = index
	_hand_dirty = true


func _start_drag(index: int, holder: Control) -> void:
	if _combat == null or _combat.phase != Combat.Phase.PLAYER:
		return
	_dragging = index
	_hover_card = -1
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


## Prefer the enemy under the cursor (sprite OR HP bar); else nearest if left hand.
## You can hit ANY living foe in the pack — aim at that rat / its bar.
func _pick_damage_target() -> int:
	var hovered := _hover_enemy()
	if hovered >= 0:
		return hovered
	var only := _only_living_enemy()
	if only >= 0:
		return only
	var mouse := get_viewport().get_mouse_position()
	var vp_h := get_viewport().get_visible_rect().size.y
	if mouse.y > vp_h - 210.0:
		return -1
	return _nearest_living_enemy(99999.0)


func _only_living_enemy() -> int:
	if _combat == null:
		return -1
	var found := -1
	for i in range(_combat.enemies.size()):
		if int(_combat.enemies[i]["hp"]) <= 0:
			continue
		if found >= 0:
			return -1
		found = i
	return found


## Screen anchor for targeting: HP-bar slot (stable) + 3D body samples.
func _enemy_aim_points(index: int) -> Array:
	var pts: Array = []
	# 1) Same fixed slot as the drawn HP bar — easiest way to pick "that" foe
	var slot := _hp_slot_center(index)
	if slot.x > -9000.0:
		pts.append(slot)
		pts.append(slot + Vector2(0, 40))
		pts.append(slot + Vector2(0, 90))
	# 2) 3D silhouette under the camera
	var cam := get_viewport().get_camera_3d()
	if cam and index >= 0 and index < _enemy_nodes.size():
		var node := _enemy_nodes[index] as Node3D
		if is_instance_valid(node) and int(_combat.enemies[index]["hp"]) > 0:
			var top_h := _enemy_top(index) * maxf(node.scale.y, 0.5)
			var cam_right := cam.global_transform.basis.x
			cam_right.y = 0.0
			if cam_right.length() < 0.01:
				cam_right = Vector3.RIGHT
			else:
				cam_right = cam_right.normalized()
			var base := node.global_position
			for mid in [
				base + Vector3.UP * (top_h * 0.5),
				base + Vector3.UP * (top_h * 0.25),
				base + Vector3.UP * (top_h * 0.75),
				base + Vector3.UP * (top_h * 0.45) + cam_right * 0.7,
				base + Vector3.UP * (top_h * 0.45) - cam_right * 0.7,
			]:
				if cam.is_position_behind(mid):
					continue
				pts.append(cam.unproject_position(mid))
	return pts


## Centre of the on-screen HP slot for enemy index (matches _draw_world_overlay).
func _hp_slot_center(enemy_index: int) -> Vector2:
	var living := _living_indices()
	var k := living.find(enemy_index)
	if k < 0:
		return Vector2(-99999, -99999)
	var vp := _world_layer.size if _world_layer else Vector2.ZERO
	if vp.x < 8.0:
		vp = get_viewport().get_visible_rect().size
	var left_m := 220.0
	var right_m := 40.0
	var usable: float = maxf(160.0, vp.x - left_m - right_m)
	var n := living.size()
	var t: float = 0.5 if n == 1 else float(k) / float(n - 1)
	return Vector2(left_m + usable * t, 92.0)


func _nearest_living_enemy(max_dist: float) -> int:
	if _combat == null:
		return -1
	var mouse := get_viewport().get_mouse_position()
	var best := -1
	var best_d := max_dist
	for i in range(_combat.enemies.size()):
		if int(_combat.enemies[i]["hp"]) <= 0:
			continue
		for p in _enemy_aim_points(i):
			var d: float = (p as Vector2).distance_to(mouse)
			if d < best_d:
				best_d = d
				best = i
	return best


## Cursor over this foe's bar or body (generous so any pack member is pickable).
func _hover_enemy() -> int:
	return _nearest_living_enemy(420.0)


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


func _party_max_hp() -> int:
	var sum := 0
	for m in _combat.party.members:
		sum += maxi(0, int(m["max_hp"]))
	return sum


func _sync_left_hud() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var panel = main.get_node_or_null("UI/LeftPanel")
	if panel and panel.has_method("refresh"):
		panel.call("refresh")
