class_name GearBeetle
extends Area3D
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
var _stomp_margin := 0.0
var _touching: Player
var _squashed := false
var _gear: Node3D
var _body: Node3D


## Call before adding to the tree. y in a and b is floor height.
func setup(a: Vector3, b: Vector3, patrol_speed: float, tuning: Tuning) -> void:
	_a = a
	_b = b
	speed = patrol_speed
	_stomp_margin = tuning.num("enemy", "stomp_margin")
	position = a
	collision_layer = 0
	collision_mask = Player.LAYER_PLAYER

	var width := tuning.num("enemy", "hitbox_width")
	var height := tuning.num("enemy", "hitbox_height")
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, width)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = height * 0.5
	add_child(collider)
	_build_model()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _squashed:
		return
	_gear.rotation.y += GEAR_SPIN * delta
	var distance := _a.distance_to(_b)
	if distance > 0.0 and speed > 0.0:
		_travel += delta * speed / distance
		var previous := position
		position = _a.lerp(_b, pingpong(_travel, 1.0))
		var step := position - previous
		if step.length_squared() > 0.0:
			var yaw := atan2(step.x, step.z)
			_body.rotation.y = lerp_angle(_body.rotation.y, yaw, clampf(TURN_RATE * delta, 0.0, 1.0))
	if _touching != null:
		_resolve_contact(_touching)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_touching = body


func _on_body_exited(body: Node3D) -> void:
	if body == _touching:
		_touching = null


func _resolve_contact(player: Player) -> void:
	if StompRules.is_stomp(
		player.global_position.y, player.fall_velocity_y, global_position.y, _stomp_margin
	):
		_squash(player)
	else:
		player.take_hit()


func _squash(player: Player) -> void:
	_squashed = true
	_touching = null
	set_deferred("monitoring", false)
	player.bounce()
	stomped.emit()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.3, 0.15, 1.3), 0.12)
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
