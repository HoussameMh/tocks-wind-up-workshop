class_name Bolt
extends MeshInstance3D
## One pooled steel hex rod with a white core. No flame, no bounce. Owned by BoltBlaster.
## Implements the hit rules in design/expansion-spec.md section 3.

enum Result { FLYING, HIT_TARGET, HIT_WORLD, SPENT }

const LENGTH := 0.7
const RADIUS := 0.17
const CORE_RADIUS := 0.1
const CORE_EXTRA := 0.1
## Hit tests grow each target by this, since the rod has thickness and the segment does not.
const HIT_MARGIN := 0.08
const STEEL_COLOR := Color("c9ced2")
const CORE_COLOR := Color.WHITE

static var _mesh: ArrayMesh

var active := false
var speed := 0.0
var flight_range := 0.0
var steer_radians := 0.0
## The enemy this bolt steers toward. It flies straight once this stops being a target.
var target: Node3D
var direction := Vector3.FORWARD

var _travelled := 0.0


## Call before adding to the tree.
func setup() -> void:
	mesh = _get_mesh()
	material_override = Look.material("box_trim")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	visible = false


## Starts a flight from the pool.
func launch(from: Vector3, aim_direction: Vector3, aim_target: Node3D) -> void:
	active = true
	visible = true
	target = aim_target
	direction = aim_direction.normalized()
	_travelled = 0.0
	global_position = from
	_face_direction()


## Returns to the pool.
func retire() -> void:
	active = false
	visible = false
	target = null


## Advances one physics tick and resolves what it hit. candidates are enemies and bubbles.
func step(delta: float, space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, candidates: Array[Node]) -> Result:
	_steer(delta)
	var from := global_position
	var to := from + direction * speed * delta
	query.from = from
	query.to = to
	var world_hit := space.intersect_ray(query)
	var nearest := from.distance_to(to)
	if not world_hit.is_empty():
		nearest = from.distance_to(world_hit["position"])
	var struck: Node = null
	for candidate in candidates:
		var bounds: AABB = candidate.call("bolt_bounds")
		var entry: Variant = bounds.grow(HIT_MARGIN).intersects_segment(from, to)
		if entry == null:
			continue
		var distance := from.distance_to(entry)
		if distance <= nearest:
			nearest = distance
			struck = candidate
	if struck != null:
		struck.call("bolt_hit")
		retire()
		return Result.HIT_TARGET
	if not world_hit.is_empty():
		var collider: Object = world_hit["collider"]
		if collider.has_method("bolt_hit"):
			collider.call("bolt_hit")
		retire()
		return Result.HIT_WORLD
	global_position = to
	_travelled += speed * delta
	if _travelled >= flight_range:
		retire()
		return Result.SPENT
	return Result.FLYING


func _steer(delta: float) -> void:
	if target == null:
		return
	if not is_instance_valid(target) or not target.is_in_group(BoltBlaster.TARGET_GROUP):
		target = null
		return
	var wanted: Vector3 = (target.call("aim_point") as Vector3) - global_position
	if wanted.length_squared() < 0.0001:
		return
	wanted = wanted.normalized()
	var angle := direction.angle_to(wanted)
	if angle < 0.0001 or angle > PI - 0.001:
		return
	direction = direction.slerp(wanted, minf(steer_radians * delta / angle, 1.0)).normalized()
	_face_direction()


func _face_direction() -> void:
	var up := Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	global_basis = Basis.looking_at(direction, up, true)


static func _get_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var axis_z := Basis(Vector3.RIGHT, PI / 2.0)
	var batch := MeshBatch.new()
	batch.add_mesh(MeshKit.cylinder(RADIUS, RADIUS, LENGTH, 6), Transform3D(axis_z, Vector3.ZERO), STEEL_COLOR)
	batch.add_mesh(
		MeshKit.cylinder(CORE_RADIUS, CORE_RADIUS, LENGTH + CORE_EXTRA, 6),
		Transform3D(axis_z, Vector3.ZERO),
		CORE_COLOR
	)
	_mesh = batch.commit()
	return _mesh
