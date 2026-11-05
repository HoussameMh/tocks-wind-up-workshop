class_name GearBeetle
extends Area3D
## Patrolling enemy. Tock stomps it from above; any other contact hurts Tock.

signal stomped

const RUST := Color("a4532f")
const DARK := Color("2b2523")
const GEAR_SPIN := 3.0
const TURN_RATE := 10.0

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
	_body = Node3D.new()
	add_child(_body)
	var dome := MeshKit.part(_body, MeshKit.sphere(0.55), RUST, Vector3(0.0, 0.42, 0.0), 0.4, 0.75)
	dome.scale = Vector3(1.0, 0.72, 1.15)
	for side: float in [-1.0, 1.0]:
		MeshKit.part(_body, MeshKit.sphere(0.11, 8), Color.WHITE, Vector3(side * 0.2, 0.52, 0.5))
		MeshKit.part(_body, MeshKit.sphere(0.055, 8), DARK, Vector3(side * 0.2, 0.52, 0.59))
		for row: float in [-0.3, 0.3]:
			MeshKit.part(
				_body, MeshKit.box(Vector3(0.14, 0.2, 0.14)), DARK, Vector3(side * 0.42, 0.1, row)
			)
	_gear = Node3D.new()
	_gear.position = Vector3(0.0, 0.84, 0.0)
	_body.add_child(_gear)
	var gear_mesh := MeshKit.part(_gear, MeshKit.cog_mesh(), Color("8d8378"), Vector3.ZERO, 0.8, 0.45)
	gear_mesh.rotation.x = PI / 2.0
