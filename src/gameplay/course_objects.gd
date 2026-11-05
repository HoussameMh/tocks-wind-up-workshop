class_name CourseObjects
extends RefCounted
## Small course pieces: moving platform, spring pad, checkpoint and Golden Key.


## Platform that eases back and forth between two points, carrying Tock.
class MovingPlatform:
	extends AnimatableBody3D

	var _a := Vector3.ZERO
	var _b := Vector3.ZERO
	var _speed := 0.0
	var _progress := 0.0

	func setup(a: Vector3, b: Vector3, size: Vector3, speed: float, color: Color) -> void:
		_a = a
		_b = b
		_speed = speed
		position = a
		sync_to_physics = true
		collision_layer = Player.LAYER_WORLD
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		add_child(collider)
		MeshKit.part(self, MeshKit.box(size), color, Vector3.ZERO, 0.6, 0.45)

	func _physics_process(delta: float) -> void:
		_progress += delta * _speed / _a.distance_to(_b)
		position = _a.lerp(_b, smoothstep(0.0, 1.0, pingpong(_progress, 1.0)))


## Launches Tock upward on contact.
class SpringPad:
	extends Area3D

	signal used

	var _launch_speed := 0.0
	var _coil: Node3D

	func setup(at: Vector3, launch_speed: float) -> void:
		_launch_speed = launch_speed
		position = at
		collision_layer = 0
		collision_mask = Player.LAYER_PLAYER
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.2, 0.8, 2.2)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = 0.4
		add_child(collider)
		MeshKit.part(self, MeshKit.cylinder(1.1, 1.2, 0.14), Color("3a3d42"), Vector3(0.0, 0.07, 0.0))
		_coil = Node3D.new()
		add_child(_coil)
		for i in 3:
			MeshKit.part(_coil, MeshKit.torus(0.55, 0.75), Color("c7d3dd"), Vector3(0.0, 0.18 + i * 0.12, 0.0), 0.9, 0.25)
		MeshKit.part(_coil, MeshKit.cylinder(1.0, 1.0, 0.1), Color("d9483b"), Vector3(0.0, 0.52, 0.0))

	func _ready() -> void:
		body_entered.connect(_on_body_entered)

	func _on_body_entered(body: Node3D) -> void:
		if body is Player:
			(body as Player).launch(_launch_speed)
			used.emit()
			var tween := create_tween()
			tween.tween_property(_coil, "scale:y", 1.8, 0.07)
			tween.tween_property(_coil, "scale:y", 1.0, 0.2)


## Sets the respawn point the first time Tock touches it.
class Checkpoint:
	extends Area3D

	signal reached(respawn_at: Vector3)

	const OFF_COLOR := Color("77706a")
	const ON_COLOR := Color("4caf6a")

	var _respawn_at := Vector3.ZERO
	var _lamp: MeshInstance3D
	var _reached := false

	func setup(at: Vector3, respawn_at: Vector3) -> void:
		_respawn_at = respawn_at
		position = at
		collision_layer = 0
		collision_mask = Player.LAYER_PLAYER
		var shape := BoxShape3D.new()
		shape.size = Vector3(10.0, 5.0, 2.0)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = Vector3(-position.x, 2.5, 0.0)
		add_child(collider)
		MeshKit.part(self, MeshKit.cylinder(0.08, 0.1, 2.0, 10), Color("3a3d42"), Vector3(0.0, 1.0, 0.0))
		_lamp = MeshKit.part(self, MeshKit.sphere(0.32), OFF_COLOR, Vector3(0.0, 2.2, 0.0))

	func _ready() -> void:
		body_entered.connect(_on_body_entered)

	func _on_body_entered(body: Node3D) -> void:
		if _reached or not body is Player:
			return
		_reached = true
		var material := _lamp.material_override as StandardMaterial3D
		material.albedo_color = ON_COLOR
		material.emission_enabled = true
		material.emission = ON_COLOR
		reached.emit(_respawn_at)


## The Golden Key that ends the level.
class GoalKey:
	extends Area3D

	signal reached

	const SPIN_RATE := 1.4
	const GOLD := Color("ffd24a")

	func setup(at: Vector3, area_size: Vector3) -> void:
		position = at
		collision_layer = 0
		collision_mask = Player.LAYER_PLAYER
		var shape := BoxShape3D.new()
		shape.size = area_size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		add_child(collider)
		var key := MeshKit.windup_key(self, GOLD, 3.2)
		key.rotation.x = -PI / 2.0
		for child in key.get_children():
			var material := (child as MeshInstance3D).material_override as StandardMaterial3D
			material.emission_enabled = true
			material.emission = GOLD
			material.emission_energy_multiplier = 0.35

	func _ready() -> void:
		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		rotation.y += SPIN_RATE * delta

	func _on_body_entered(body: Node3D) -> void:
		if body is Player:
			reached.emit()
