class_name Effects
extends Node3D
## Short particle bursts: brass sparks on a stomp, a glint on a pickup and dust on a hard landing.
## Every emitter is made up front and reused, so play allocates nothing. Off with Reduced motion.
## Values come from the "effects" section of assets/data/visual_look.json.
## Implements design/release-spec.md section 3.
##
## Usage:
##   var effects := Effects.new()
##   add_child(effects)
##   effects.set_scale_factor(0.5)
##   effects.burst(Effects.SPARK, tock.global_position)

const SPARK := "spark"
const GLINT := "glint"
const DUST := "dust"
const KINDS: Array[String] = [SPARK, GLINT, DUST]

## While false, burst() does nothing.
var enabled := true

var _pools: Dictionary = {}
var _next: Dictionary = {}
var _base_amounts: Dictionary = {}
var _scale_factor := 1.0
var _player: Player
var _land_min_speed := 0.0
var _was_on_floor := true
var _fall_speed := 0.0


func _ready() -> void:
	var sizes := Look.group("effects", "pool_size")
	_land_min_speed = Look.num("effects", "landing", "min_speed")
	for kind in KINDS:
		var pool: Array[CPUParticles3D] = []
		for _i in int(sizes.get(kind, 2)):
			var emitter := _make_emitter(kind)
			add_child(emitter)
			pool.append(emitter)
		_pools[kind] = pool
		_next[kind] = 0
	_apply_amounts()


## Watches Tock for hard landings. Call whenever a new Tock is built.
func follow(player: Player) -> void:
	_player = player
	_was_on_floor = true
	_fall_speed = 0.0


## Scales how many particles each burst has, from the graphics quality.
func set_scale_factor(factor: float) -> void:
	_scale_factor = clampf(factor, 0.1, 1.0)
	if is_inside_tree():
		_apply_amounts()


## Plays one burst of a kind at a point in the world.
func burst(kind: String, at: Vector3) -> void:
	if not enabled or not _pools.has(kind):
		return
	var pool: Array[CPUParticles3D] = _pools[kind]
	var index: int = _next[kind]
	_next[kind] = (index + 1) % pool.size()
	var emitter := pool[index]
	emitter.global_position = at
	emitter.visible = true
	emitter.restart()
	emitter.emitting = true


## Number of emitters currently playing, for tests.
func active_count() -> int:
	var count := 0
	for pool: Array in _pools.values():
		for emitter: CPUParticles3D in pool:
			if emitter.emitting:
				count += 1
	return count


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player) or not _player.alive:
		return
	var on_floor := _player.is_on_floor()
	if not on_floor:
		_fall_speed = maxf(_fall_speed, -_player.velocity.y)
	elif not _was_on_floor:
		if _fall_speed >= _land_min_speed:
			burst(DUST, _player.global_position)
		_fall_speed = 0.0
	_was_on_floor = on_floor


func _make_emitter(kind: String) -> CPUParticles3D:
	var values := Look.group("effects", kind)
	var emitter := CPUParticles3D.new()
	emitter.name = "Effect_%s" % kind
	emitter.one_shot = true
	emitter.emitting = false
	# An idle emitter would still cost a draw call every frame, so it hides between bursts.
	emitter.visible = false
	emitter.finished.connect(emitter.hide)
	emitter.explosiveness = 1.0
	emitter.lifetime = float(values.get("lifetime", 0.5))
	emitter.local_coords = false
	emitter.direction = Vector3.UP
	emitter.spread = float(values.get("spread", 60.0))
	var speed: Array = values.get("speed", [1.0, 2.0])
	emitter.initial_velocity_min = speed[0]
	emitter.initial_velocity_max = speed[1]
	emitter.gravity = Vector3(0.0, float(values.get("gravity", -9.8)), 0.0)
	emitter.scale_amount_min = 0.6
	emitter.scale_amount_max = 1.0
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = fade
	emitter.color = Look.to_color(values.get("color", "#ffffff"))
	var quad := QuadMesh.new()
	var size := float(values.get("size", 0.1))
	quad.size = Vector2(size, size)
	quad.material = Look.material(values.get("row", "spark"))
	emitter.mesh = quad
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_base_amounts[emitter] = int(values.get("amount", 10))
	return emitter


func _apply_amounts() -> void:
	for emitter: CPUParticles3D in _base_amounts.keys():
		emitter.amount = maxi(int(round(_base_amounts[emitter] * _scale_factor)), 1)
