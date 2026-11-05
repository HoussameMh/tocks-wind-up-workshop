class_name Pickup
extends Area3D
## A collectible: "cog", "coil" (Coil Spring) or "life" (spare key).

signal collected(kind: String, player: Player)

const SPIN_RATE := 3.0
static var _coil_mesh: ArrayMesh

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
		"life":
			MeshKit.windup_key(self, "spare_key", 1.1, false)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	rotation.y += SPIN_RATE * delta


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
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
