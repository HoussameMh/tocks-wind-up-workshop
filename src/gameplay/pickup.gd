class_name Pickup
extends Area3D
## A collectible: "cog", "coil" (Coil Spring) or "life" (spare key).

signal collected(kind: String, player: Player)

const SPIN_RATE := 3.0
const BRASS := Color("e3b23c")
const SILVER := Color("c7d3dd")

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
			MeshKit.part(self, MeshKit.cog_mesh(), BRASS, Vector3.ZERO, 0.15, 0.4)
		"coil":
			for i in 4:
				MeshKit.part(self, MeshKit.torus(0.2, 0.34), SILVER, Vector3(0.0, -0.27 + i * 0.18, 0.0), 0.9, 0.2)
		"life":
			MeshKit.windup_key(self, Color("4caf6a"), 1.1)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	rotation.y += SPIN_RATE * delta


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		collected.emit(kind, body as Player)
		set_deferred("monitoring", false)
		queue_free()
