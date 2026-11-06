class_name GearBeetle
extends EnemyBase
## Patrolling enemy. Tock stomps it from above; any other contact hurts Tock.

signal stomped

const GEAR_SPIN := 3.0
const TURN_RATE := 10.0

static var _shared_meshes: Dictionary = {}

## Patrol speed; tests may set this to 0 to hold it in place.
var speed := 0.0

var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _travel := 0.0
var _speed_scale := 1.0
var _bolt_score := 0
var _gear: Node3D
var _body: Node3D


## Call before adding to the tree. y in a and b is floor height.
func setup(a: Vector3, b: Vector3, patrol_speed: float, tuning: Tuning) -> void:
	_a = a
	_b = b
	speed = patrol_speed
	_bolt_score = int(tuning.num("score", "bolt_gear"))
	var width := tuning.num("enemy", "hitbox_width")
	_setup_base(tuning, a, Vector3(width, tuning.num("enemy", "hitbox_height"), width))
	_build_model()


func _enemy_tick(delta: float) -> void:
	_gear.rotation.y += GEAR_SPIN * delta
	var distance := _a.distance_to(_b)
	if distance > 0.0 and speed > 0.0:
		_travel += delta * speed * _speed_scale / distance
		var previous := position
		position = _a.lerp(_b, pingpong(_travel, 1.0))
		var step := position - previous
		if step.length_squared() > 0.0:
			var yaw := atan2(step.x, step.z)
			_body.rotation.y = lerp_angle(_body.rotation.y, yaw, clampf(TURN_RATE * delta, 0.0, 1.0))


func _on_stomped(player: Player) -> void:
	_squash(player)
	stomped.emit()


func _on_bolted() -> void:
	_defeat()
	scored.emit(_bolt_score, "bolt_hit")
	_play_knockout()


func _squash(player: Player) -> void:
	_defeat()
	player.bounce()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.3, 0.15, 1.3), 0.12)
	tween.tween_interval(0.25)
	tween.tween_callback(queue_free)


## Flips onto its back with its legs in the air.
func _play_knockout() -> void:
	var tween := create_tween()
	tween.tween_property(_body, "rotation:z", PI, 0.15)
	tween.parallel().tween_property(_body, "position:y", 0.9, 0.15)
	tween.tween_interval(0.25)
	tween.tween_callback(queue_free)


func _build_model() -> void:
	_bake_meshes()
	var far := Look.num("readability", "beetle", "cull_distance")
	var near := Look.num("readability", "beetle", "detail_cull_distance")
	var blob := MeshKit.blob(self, Look.num("readability", "blob", "beetle_radius"))
	blob.position.y = Look.num("readability", "blob", "lift")
	blob.visibility_range_end = near
	_body = Node3D.new()
	add_child(_body)
	var dome := MeshKit.part(_body, _shared_meshes["shell"], "beetle_shell", Vector3(0.0, 0.42, 0.0))
	dome.scale = Vector3(1.0, 0.72, 1.15)
	dome.visibility_range_end = far
	MeshKit.part(_body, _shared_meshes["eyes"], "beetle_eyes", Vector3.ZERO, false).visibility_range_end = far
	MeshKit.part(_body, _shared_meshes["legs"], "beetle_legs", Vector3.ZERO, false).visibility_range_end = near
	_gear = Node3D.new()
	_gear.position = Vector3(0.0, 0.84, 0.0)
	_body.add_child(_gear)
	var gear_mesh := MeshKit.part(_gear, MeshKit.cog_mesh(), "beetle_gear")
	gear_mesh.rotation.x = PI / 2.0
	gear_mesh.visibility_range_end = near


static func _bake_meshes() -> void:
	if not _shared_meshes.is_empty():
		return
	_shared_meshes["shell"] = MeshKit.sphere(0.55)
	var eyes := MeshBatch.new()
	var eye := MeshKit.sphere(0.11, 8)
	var legs := MeshBatch.new()
	var leg := MeshKit.box(Vector3(0.14, 0.2, 0.14))
	for side: float in [-1.0, 1.0]:
		eyes.add_mesh(eye, Transform3D(Basis.IDENTITY, Vector3(side * 0.2, 0.52, 0.5)))
		for row: float in [-0.3, 0.3]:
			legs.add_mesh(leg, Transform3D(Basis.IDENTITY, Vector3(side * 0.42, 0.1, row)))
	_shared_meshes["eyes"] = eyes.commit()
	_shared_meshes["legs"] = legs.commit()
