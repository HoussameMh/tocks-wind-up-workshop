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

	## look is the platform's palette entry: its material and edge trim rows.
	func setup(a: Vector3, b: Vector3, size: Vector3, speed: float, look: Dictionary) -> void:
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
		_build_visual(size, look)

	func _physics_process(delta: float) -> void:
		_progress += delta * _speed / _a.distance_to(_b)
		position = _a.lerp(_b, smoothstep(0.0, 1.0, pingpong(_progress, 1.0)))

	## Mesh-local UVs, because this object moves and world UVs would swim.
	func _build_visual(size: Vector3, look: Dictionary) -> void:
		var row: String = look["material"]
		var plate := MeshBatch.new()
		plate.add_box(Vector3.ZERO, size, Look.uv_per_unit(row))
		MeshKit.part(self, plate.commit(), row)
		var width := Look.num("readability", "edge", "width") * 1.5
		var y := size.y * 0.5 - width * 0.5 + 0.006
		var half := size * 0.5
		var trim := MeshBatch.new()
		for side: float in [-1.0, 1.0]:
			trim.add_box(Vector3(0.0, y, side * (half.z - width * 0.5 + 0.006)), Vector3(size.x + 0.012, width, width))
			trim.add_box(Vector3(side * (half.x - width * 0.5 + 0.006), y, 0.0), Vector3(width, width, size.z + 0.012))
		# The nut that rides the lead screw under the plate.
		trim.add_box(Vector3(0.0, -half.y - 0.3, 0.0), Vector3(0.9, 0.6, 1.4))
		MeshKit.part(self, trim.commit(), look["edge"], Vector3.ZERO, false)


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
		MeshKit.part(self, MeshKit.cylinder(1.1, 1.2, 0.14), "spring_base", Vector3(0.0, 0.07, 0.0), false)
		_coil = Node3D.new()
		add_child(_coil)
		var rings := MeshBatch.new()
		var ring := MeshKit.torus(0.55, 0.75)
		for i in 3:
			rings.add_mesh(ring, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18 + i * 0.12, 0.0)))
		MeshKit.part(_coil, rings.commit(), "coil_metal", Vector3.ZERO, false)
		MeshKit.part(_coil, MeshKit.cylinder(1.0, 1.0, 0.1), "spring_top", Vector3(0.0, 0.52, 0.0))

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

	const LAMP_LIT_SCALE := 1.2

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
		# A stubby pilot lamp, 1.6 tall: wide brass base with the lamp sitting directly on it.
		MeshKit.part(self, MeshKit.cylinder(0.3, 0.42, 1.2, 12), "checkpoint_base", Vector3(0.0, 0.6, 0.0))
		_lamp = MeshKit.part(self, MeshKit.sphere(0.34), "checkpoint_off", Vector3(0.0, 1.3, 0.0), false)

	func _ready() -> void:
		body_entered.connect(_on_body_entered)

	func _on_body_entered(body: Node3D) -> void:
		if _reached or not body is Player:
			return
		_reached = true
		_lamp.material_override = Look.material("checkpoint_on")
		_lamp.scale = Vector3.ONE * LAMP_LIT_SCALE
		reached.emit(_respawn_at)


## The Golden Key that ends the level.
class GoalKey:
	extends Area3D

	signal reached

	const SPIN_RATE := 1.4

	func setup(at: Vector3, area_size: Vector3) -> void:
		position = at
		collision_layer = 0
		collision_mask = Player.LAYER_PLAYER
		var shape := BoxShape3D.new()
		shape.size = area_size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		add_child(collider)
		var key := MeshKit.windup_key(self, "golden_key", 3.2)
		key.rotation.x = -PI / 2.0
		add_child(Look.omni("key_glow"))
		_add_halo()

	func _ready() -> void:
		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		rotation.y += SPIN_RATE * delta

	## A cheap additive billboard: full-screen glow costs too much on the target GPU (see data_reference.md).
	func _add_halo() -> void:
		var batch := MeshBatch.new()
		var radius := Look.num("readability", "halo", "radius")
		var alpha := Look.num("readability", "halo", "alpha")
		var tint := Look.color("readability", "halo", "color")
		batch.add_soft_disc(Vector3.ZERO, Vector2.ONE * radius, alpha, tint, 20, true)
		MeshKit.part(self, batch.commit(), "halo", Vector3.ZERO, false)

	func _on_body_entered(body: Node3D) -> void:
		if body is Player:
			reached.emit()
