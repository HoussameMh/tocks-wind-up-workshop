class_name Pickup
extends Area3D
## A collectible: "cog", "coil" (Coil Spring), "bolt" (Bolt Blaster) or "life" (spare key).

signal collected(kind: String, player: Player)

const SPIN_RATE := 3.0
static var _coil_mesh: ArrayMesh
static var _bolt_mesh: ArrayMesh

var kind := ""


## Call before adding to the tree.
func setup(pickup_kind: String, at: Vector3) -> void:
	kind = pickup_kind
	position = at
	collision_layer = 0
	collision_mask = Player.LAYER_PLAYER
	var shape := SphereShape3D.new()
	shape.radius = 0.75
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	match kind:
		"cog":
			var cog := MeshKit.part(self, MeshKit.cog_mesh(), "cog", Vector3.ZERO, false)
			cog.visibility_range_end = Look.num("readability", "cog", "cull_distance")
		"coil":
			MeshKit.part(self, _get_coil_mesh(), "coil_metal", Vector3.ZERO, false)
		"bolt":
			MeshKit.part(self, _get_bolt_mesh(), "beetle_gear", Vector3.ZERO, false)
		"life":
			MeshKit.windup_key(self, "spare_key", 1.1, false)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	rotation.y += SPIN_RATE * delta


func _on_body_entered(body: Node3D) -> void:
	# A dead Tock collects nothing: the form table ignores every pickup while BROKEN.
	if body is Player and (body as Player).alive:
		collected.emit(kind, body as Player)
		set_deferred("monitoring", false)
		queue_free()


static func _get_coil_mesh() -> ArrayMesh:
	if _coil_mesh != null:
		return _coil_mesh
	var batch := MeshBatch.new()
	var ring := MeshKit.torus(0.2, 0.34)
	for i in 4:
		batch.add_mesh(ring, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.27 + i * 0.18, 0.0)))
	_coil_mesh = batch.commit()
	return _coil_mesh


## A steel hex nut on a stubby barrel, deliberately unlike the round Coil Spring.
static func _get_bolt_mesh() -> ArrayMesh:
	if _bolt_mesh != null:
		return _bolt_mesh
	var axis_z := Basis(Vector3.RIGHT, PI / 2.0)
	var batch := MeshBatch.new()
	batch.add_mesh(MeshKit.cylinder(0.2, 0.2, 0.75, 10), Transform3D(axis_z, Vector3(0.0, 0.0, 0.1)))
	batch.add_mesh(MeshKit.cylinder(0.46, 0.46, 0.24, 6), Transform3D(axis_z, Vector3(0.0, 0.0, -0.1)))
	_bolt_mesh = batch.commit()
	return _bolt_mesh
