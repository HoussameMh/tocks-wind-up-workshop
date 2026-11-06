class_name BoltBlaster
extends Node3D
## The Bolt Blaster: fire rate, the bolt pool, target choice and the target ring. It knows nothing
## of input; Player passes in one tick of intent. Implements design/expansion-spec.md section 3.
##
## A target is any Node3D in TARGET_GROUP with aim_point() -> Vector3, bolt_hit() -> void and
## bolt_bounds() -> AABB (world space, used for the swept hit test). It leaves the group when it
## can no longer be hit. An optional aim_score_scale() -> float favors it, for the boss weak spot.
## POPPABLE_GROUP is the same contract without aim_point: hit by bolts, but never aimed at.

signal fired
signal clinked

const TARGET_GROUP := "bolt_targets"
const POPPABLE_GROUP := "bolt_poppable"
const RING_OUTER := 0.42
const RING_INNER := 0.34
const RING_LIFT := 0.55
const RING_COLOR := Color.WHITE

static var _ring_mesh: ArrayMesh

## Seconds between bolts; tests may change it to reach the alive cap.
var cooldown := 0.0
## The current target, or null. Refreshed on a timer and when firing.
var current_target: Node3D

var _max_bolts := 0
var _bolt_speed := 0.0
var _bolt_range := 0.0
var _steer_radians := 0.0
var _fire_grace := 0.0
var _muzzle_height := 0.0
var _aim_refresh := 0.0
var _aim: BoltAim
var _bolts: Array[Bolt] = []
var _ring: MeshInstance3D
var _armed := false
var _grace_left := 0.0
var _cooldown_left := 0.0
var _refresh_left := 0.0
var _los_query: PhysicsRayQueryParameters3D
var _bolt_query: PhysicsRayQueryParameters3D


## Call before adding to the tree.
func setup(tuning: Tuning) -> void:
	cooldown = tuning.num("blaster", "cooldown")
	_max_bolts = int(tuning.num("blaster", "max_bolts"))
	_bolt_speed = tuning.num("blaster", "bolt_speed")
	_bolt_range = tuning.num("blaster", "bolt_range")
	_steer_radians = deg_to_rad(tuning.num("blaster", "steer_degrees"))
	_fire_grace = tuning.num("blaster", "fire_grace")
	_muzzle_height = tuning.num("blaster", "muzzle_height")
	_aim_refresh = tuning.num("blaster", "aim_refresh")
	_aim = BoltAim.new(tuning)
	_los_query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Player.LAYER_WORLD)
	_bolt_query = PhysicsRayQueryParameters3D.create(
		Vector3.ZERO, Vector3.ONE, Player.LAYER_WORLD | Player.LAYER_HIDDEN
	)
	for _i in _max_bolts:
		var bolt := Bolt.new()
		bolt.setup()
		bolt.speed = _bolt_speed
		bolt.flight_range = _bolt_range
		bolt.steer_radians = _steer_radians
		add_child(bolt)
		_bolts.append(bolt)
	_ring = MeshInstance3D.new()
	_ring.mesh = _get_ring_mesh()
	_ring.material_override = Look.material("halo")
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	_ring.visible = false
	add_child(_ring)


## Ignores the trigger for a moment, so the button that closed a menu fires nothing.
func begin_grace() -> void:
	_grace_left = _fire_grace


## Turns firing and the target ring on or off. Bolts in flight keep flying.
func set_armed(armed: bool) -> void:
	_armed = armed
	if not armed:
		current_target = null
		_ring.visible = false


## Number of bolts in flight.
func alive_count() -> int:
	var count := 0
	for bolt in _bolts:
		if bolt.active:
			count += 1
	return count


## Removes every bolt in flight.
func clear_bolts() -> void:
	for bolt in _bolts:
		bolt.retire()


## One physics tick. feet is Tock's origin and direction is the flat way he faces.
func tick(delta: float, trigger: bool, feet: Vector3, direction: Vector3) -> void:
	_grace_left = maxf(_grace_left - delta, 0.0)
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_step_bolts(delta)
	if not _armed:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_target(feet, direction)
	if trigger and _grace_left <= 0.0 and _cooldown_left <= 0.0:
		_fire(feet, direction)
	_update_ring()


func _step_bolts(delta: float) -> void:
	if alive_count() == 0:
		return
	var space := get_world_3d().direct_space_state
	var candidates := get_tree().get_nodes_in_group(TARGET_GROUP)
	candidates.append_array(get_tree().get_nodes_in_group(POPPABLE_GROUP))
	for bolt in _bolts:
		if not bolt.active:
			continue
		var result := bolt.step(delta, space, _bolt_query, candidates)
		if result == Bolt.Result.HIT_WORLD or result == Bolt.Result.SPENT:
			clinked.emit()


func _refresh_target(feet: Vector3, direction: Vector3) -> void:
	_refresh_left = _aim_refresh
	current_target = _pick_target(feet, direction)


func _pick_target(feet: Vector3, direction: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var space := get_world_3d().direct_space_state
	var muzzle := feet + Vector3.UP * _muzzle_height
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		var point: Vector3 = node.call("aim_point")
		var scale_factor := 1.0
		if node.has_method("aim_score_scale"):
			scale_factor = node.call("aim_score_scale")
		var score := _aim.score(feet, direction, point, scale_factor)
		if score == BoltAim.OUT_OF_CONE or score >= best_score:
			continue
		# Rays only for a candidate that would win, so a crowded cone stays cheap.
		_los_query.from = muzzle
		_los_query.to = point
		if space.intersect_ray(_los_query).is_empty():
			best = node
			best_score = score
	return best


func _fire(feet: Vector3, direction: Vector3) -> void:
	var bolt := _free_bolt()
	if bolt == null:
		return
	_refresh_target(feet, direction)
	var from := feet + Vector3.UP * _muzzle_height
	var launch_direction := direction
	if current_target != null:
		launch_direction = (current_target.call("aim_point") as Vector3) - from
	bolt.launch(from, launch_direction, current_target)
	_cooldown_left = cooldown
	fired.emit()


func _free_bolt() -> Bolt:
	for bolt in _bolts:
		if not bolt.active:
			return bolt
	return null


func _update_ring() -> void:
	if not is_instance_valid(current_target) or not current_target.is_in_group(TARGET_GROUP):
		current_target = null
		_ring.visible = false
		return
	var bounds: AABB = current_target.call("bolt_bounds")
	_ring.global_position = bounds.get_center() + Vector3.UP * (bounds.size.y * 0.5 + RING_LIFT)
	_ring.visible = true


## A thin ring with a tick pointing down at the target, in the billboard's XY plane.
static func _get_ring_mesh() -> ArrayMesh:
	if _ring_mesh != null:
		return _ring_mesh
	var batch := MeshBatch.new()
	batch.add_mesh(
		MeshKit.torus(RING_INNER, RING_OUTER),
		Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO),
		RING_COLOR
	)
	batch.add_box(Vector3.DOWN * (RING_OUTER + 0.1), Vector3(0.07, 0.2, 0.02), 0.0, Vector2.ZERO, RING_COLOR)
	_ring_mesh = batch.commit()
	return _ring_mesh
