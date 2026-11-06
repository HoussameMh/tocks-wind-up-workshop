class_name CourseObjects
extends RefCounted
## Small course pieces: moving platform, spring pad, checkpoint and Golden Key.


## Platform that eases back and forth between two points, carrying Tock.
class MovingPlatform:
	extends AnimatableBody3D

	const VISUAL_WRENCH := "wrench"
	const JAW_DROP := 0.05
	const JAW_LENGTH := 1.3
	const JAW_THICKNESS := 0.35
	const JAW_HEIGHT := 0.3
	const JAW_SPREAD := 0.6

	var _a := Vector3.ZERO
	var _b := Vector3.ZERO
	var _speed := 0.0
	var _progress := 0.0

	## look is the platform's palette entry: its material and edge trim rows. visual "wrench" draws
	## a giant open-jawed wrench over the same box collider; the default is a lead-screw plate.
	func setup(a: Vector3, b: Vector3, size: Vector3, speed: float, look: Dictionary, visual := "") -> void:
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
		if visual == VISUAL_WRENCH:
			_build_wrench(size, look)
		else:
			_build_visual(size, look)

	func _physics_process(delta: float) -> void:
		_progress += delta * _speed / _a.distance_to(_b)
		position = _a.lerp(_b, smoothstep(0.0, 1.0, pingpong(_progress, 1.0)))

	## A steel wrench lying flat: the handle is the walkable box, and an open jaw at each end of
	## its long side is decoration that sits below the walking surface, so nothing trips Tock.
	func _build_wrench(size: Vector3, look: Dictionary) -> void:
		var row: String = look["material"]
		var plate := MeshBatch.new()
		plate.add_box(Vector3.ZERO, size, Look.uv_per_unit(row))
		MeshKit.part(self, plate.commit(), row)
		var long_x := size.x > size.z
		var along := Vector3.RIGHT if long_x else Vector3.BACK
		var across := Vector3.BACK if long_x else Vector3.RIGHT
		var half_long := (size.x if long_x else size.z) * 0.5
		var half_wide := (size.z if long_x else size.x) * 0.5
		var drop := Vector3.DOWN * (size.y * 0.5 + JAW_DROP)
		var jaw_long := along * JAW_LENGTH + across * JAW_THICKNESS + Vector3.UP * JAW_HEIGHT
		var jaw_back := along * JAW_THICKNESS + across * (half_wide * 2.0 + JAW_SPREAD) + Vector3.UP * JAW_HEIGHT
		var jaws := MeshBatch.new()
		for end: float in [-1.0, 1.0]:
			var neck := along * end * (half_long - JAW_THICKNESS * 0.5) + drop
			jaws.add_box(neck, jaw_back.abs())
			for side: float in [-1.0, 1.0]:
				var tip := across * side * (half_wide + JAW_SPREAD * 0.5 - JAW_THICKNESS * 0.5)
				jaws.add_box(neck + along * end * JAW_LENGTH * 0.5 + tip, jaw_long.abs())
		MeshKit.part(self, jaws.commit(), look["edge"], Vector3.ZERO, false)

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


## A slick patch of paint: Tock's grip drops while he stands in it. The top face sits just proud of
## the floor at center.y. Implements design/expansion-spec.md section 5, L3.
class PaintSpill:
	extends Area3D

	## Tock ran in fast enough to deserve the sound.
	signal slooped

	const AREA_HEIGHT := 0.6
	const LIFT := 0.02
	const THICKNESS := 0.03
	const EDGE_BLOB_SPACING := 1.7
	const EDGE_BLOB_RADIUS := 0.55
	const EDGE_BLOB_WOBBLE := 0.3

	var _sloop_speed := 0.0

	## center's y is the floor height; size is x and z.
	func setup(center: Vector3, size: Vector2, sloop_speed: float) -> void:
		_sloop_speed = sloop_speed
		position = center
		collision_layer = 0
		collision_mask = Player.LAYER_PLAYER
		var shape := BoxShape3D.new()
		shape.size = Vector3(size.x, AREA_HEIGHT, size.y)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = AREA_HEIGHT * 0.5
		add_child(collider)
		var inset := size - Vector2.ONE * EDGE_BLOB_RADIUS * 2.0
		var batch := MeshBatch.new()
		batch.add_box(Vector3.UP * LIFT, Vector3(inset.x, THICKNESS, inset.y))
		_add_blobby_edge(batch, inset)
		MeshKit.part(self, batch.commit(), "paint_spill", Vector3.ZERO, false)

	## Soft lobes round the rectangle, kept inside the real slick area. Same pattern every time.
	func _add_blobby_edge(batch: MeshBatch, inset: Vector2) -> void:
		var half := inset * 0.5
		var count_x := maxi(ceili(inset.x / EDGE_BLOB_SPACING), 1)
		var count_z := maxi(ceili(inset.y / EDGE_BLOB_SPACING), 1)
		for i in count_x + 1:
			var x := -half.x + inset.x * i / count_x
			var wobble := 1.0 - EDGE_BLOB_WOBBLE * float(i % 3) * 0.5
			var disc := MeshKit.cylinder(EDGE_BLOB_RADIUS * wobble, EDGE_BLOB_RADIUS * wobble, THICKNESS, 10)
			batch.add_mesh(disc, Transform3D(Basis.IDENTITY, Vector3(x, LIFT, half.y)))
			batch.add_mesh(disc, Transform3D(Basis.IDENTITY, Vector3(-x, LIFT, -half.y)))
		for i in count_z + 1:
			var z := -half.y + inset.y * i / count_z
			var wobble := 1.0 - EDGE_BLOB_WOBBLE * float((i + 1) % 3) * 0.5
			var disc := MeshKit.cylinder(EDGE_BLOB_RADIUS * wobble, EDGE_BLOB_RADIUS * wobble, THICKNESS, 10)
			batch.add_mesh(disc, Transform3D(Basis.IDENTITY, Vector3(half.x, LIFT, z)))
			batch.add_mesh(disc, Transform3D(Basis.IDENTITY, Vector3(-half.x, LIFT, -z)))

	func _ready() -> void:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	func _on_body_entered(body: Node3D) -> void:
		if body is Player:
			(body as Player).set_on_paint(true)
			var flat := Vector2((body as Player).velocity.x, (body as Player).velocity.z)
			if flat.length() > _sloop_speed:
				slooped.emit()

	func _on_body_exited(body: Node3D) -> void:
		if body is Player:
			(body as Player).set_on_paint(false)


## Launches Tock upward on contact. visual "band" stretches a rubber band between two pegs instead
## of the coil spring, for the junk drawer.
class SpringPad:
	extends Area3D

	signal used

	const VISUAL_BAND := "band"
	const BAND_PEG_X := 1.1

	var _launch_speed := 0.0
	var _coil: Node3D

	func setup(at: Vector3, launch_speed: float, visual := "") -> void:
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
		_coil = Node3D.new()
		add_child(_coil)
		if visual == VISUAL_BAND:
			_build_band()
			return
		MeshKit.part(self, MeshKit.cylinder(1.1, 1.2, 0.14), "spring_base", Vector3(0.0, 0.07, 0.0), false)
		var rings := MeshBatch.new()
		var ring := MeshKit.torus(0.55, 0.75)
		for i in 3:
			rings.add_mesh(ring, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18 + i * 0.12, 0.0)))
		MeshKit.part(_coil, rings.commit(), "coil_metal", Vector3.ZERO, false)
		MeshKit.part(_coil, MeshKit.cylinder(1.0, 1.0, 0.1), "spring_top", Vector3(0.0, 0.52, 0.0))

	## Two thumbtack pegs and a fat red band across them, which is what stretches on a bounce.
	func _build_band() -> void:
		var pegs := MeshBatch.new()
		for side: float in [-1.0, 1.0]:
			var peg := MeshKit.cylinder(0.14, 0.2, 0.55, 8)
			pegs.add_mesh(peg, Transform3D(Basis.IDENTITY, Vector3(side * BAND_PEG_X, 0.27, 0.0)))
		MeshKit.part(self, pegs.commit(), "steel_trim", Vector3.ZERO, false)
		var band := MeshBatch.new()
		band.add_box(Vector3(0.0, 0.42, 0.14), Vector3(BAND_PEG_X * 2.0 + 0.3, 0.16, 0.1))
		band.add_box(Vector3(0.0, 0.42, -0.14), Vector3(BAND_PEG_X * 2.0 + 0.3, 0.16, 0.1))
		MeshKit.part(_coil, band.commit(), "rubber_band", Vector3.ZERO, false)

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
