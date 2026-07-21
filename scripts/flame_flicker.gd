extends Node
## Cheap flame animation: squash/stretch + light flicker + tiny wobble.
## Attach as child of a holder; assign sprite/light paths or set refs in code.

@export var sprite_path: NodePath
@export var light_path: NodePath
@export var light2_path: NodePath

## Base scale of the flame sprite (set after spawn if needed).
@export var base_scale: Vector3 = Vector3.ONE
## How much to squash/stretch (0.2 = ±20% — very readable on flame).
@export var stretch_amount: float = 0.16
## Side wobble in degrees.
@export var wobble_deg: float = 7.0
## Light energy flicker (off by default — static light is easier on the eyes).
@export var energy_min: float = 1.0
@export var energy_max: float = 1.0
@export var flicker_lights: bool = false
@export var speed: float = 1.35

var _sprite: Node3D
var _light: OmniLight3D
var _light2: OmniLight3D
var _base_energy: float = 1.0
var _base_energy2: float = 1.0
var _base_pos: Vector3 = Vector3.ZERO
var _t: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	_seed = randf() * 100.0
	_t = randf() * TAU
	if sprite_path != NodePath(""):
		_sprite = get_node_or_null(sprite_path) as Node3D
	if light_path != NodePath(""):
		_light = get_node_or_null(light_path) as OmniLight3D
	if light2_path != NodePath(""):
		_light2 = get_node_or_null(light2_path) as OmniLight3D
	if _sprite:
		base_scale = _sprite.scale
		_base_pos = _sprite.position
	if _light:
		_base_energy = _light.light_energy
	if _light2:
		_base_energy2 = _light2.light_energy


func setup(sprite: Node3D = null, light: OmniLight3D = null, light2: OmniLight3D = null) -> void:
	_sprite = sprite
	if sprite:
		base_scale = sprite.scale
		_base_pos = sprite.position
	if light:
		_light = light
		_base_energy = light.light_energy
	if light2:
		_light2 = light2
		_base_energy2 = light2.light_energy


func _process(delta: float) -> void:
	_t += delta * speed * (7.5 + sin(_seed) * 1.8)
	# Layered sines → organic, not robotic
	var s1 := sin(_t * 1.7 + _seed)
	var s2 := sin(_t * 3.1 + _seed * 0.7)
	var s3 := sin(_t * 5.3 + _seed * 1.3)
	var s4 := sin(_t * 8.1 + _seed * 2.1)
	var flicker := 0.5 * s1 + 0.28 * s2 + 0.15 * s3 + 0.07 * s4  # ~[-1,1]

	if _sprite and stretch_amount > 0.001:
		# Mostly vertical stretch (flame "breathes"); keep root position fixed
		var sy := 1.0 + flicker * stretch_amount
		var sx := 1.0 - flicker * stretch_amount * 0.35
		_sprite.scale = Vector3(base_scale.x * sx, base_scale.y * sy, base_scale.z)
		_sprite.rotation_degrees.z = s2 * wobble_deg * 0.5
		_sprite.position = _base_pos


	# Keep OmniLight steady unless explicitly enabled (screen flicker hurts eyes)
	if flicker_lights:
		if _light:
			var e := lerpf(energy_min, energy_max, 0.5 + 0.5 * flicker)
			_light.light_energy = _base_energy * e
		if _light2:
			var e2 := lerpf(energy_min, energy_max, 0.5 + 0.5 * (-flicker * 0.6 + s3 * 0.4))
			_light2.light_energy = _base_energy2 * e2
	else:
		if _light:
			_light.light_energy = _base_energy
		if _light2:
			_light2.light_energy = _base_energy2
