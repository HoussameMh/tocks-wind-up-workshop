class_name GoldenGear
extends Area3D
## One of a level's three hidden golden gears. A gear found on an earlier clear shows as a pale
## ghost: still worth touching for score, but it adds nothing to the saved count.
## Implements design/release-spec.md section 3.
##
## Usage:
##   var gear := GoldenGear.new()
##   gear.setup(0, Vector3(0, 1, -159), false)
##   gear.collected.connect(_on_gear_collected)
##   level.add_child(gear)

## Touched by a living Tock. ghost is true for a gear already banked.
signal collected(index: int, ghost: bool)

const SPIN_RATE := 1.6
const BOB_HEIGHT := 0.15
const BOB_RATE := 2.2
const SIZE := 2.6
const RADIUS := 0.9
const HALO_SIZE := 3.2

## Which of the level's gears this is, from 0.
var index := 0
## Already banked by an earlier clear.
var ghost := false

var _model: Node3D
var _base_y := 0.0
var _clock := 0.0


## Call before adding to the tree.
func setup(gear_index: int, at: Vector3, found_before: bool) -> void:
	index = gear_index
	ghost = found_before
	position = at
	_base_y = at.y
	collision_layer = 0
	collision_mask = Player.LAYER_PLAYER
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	_model = Node3D.new()
	_model.scale = Vector3.ONE * SIZE
	add_child(_model)
	# Emissive only, with no light of its own: each extra light redraws everything it touches,
	# which the integrated graphics the game targets cannot afford.
	var row := "golden_gear_found" if ghost else "golden_gear"
	var cull := Look.num("readability", "cog", "cull_distance")
	var mesh := MeshKit.part(_model, MeshKit.cog_mesh(), row, Vector3.ZERO, false)
	mesh.visibility_range_end = cull
	# A soft halo sets it apart from ordinary cogs, which are the same shape.
	if not ghost:
		var halo := QuadMesh.new()
		halo.size = Vector2.ONE * HALO_SIZE
		var glow := MeshKit.part(self, halo, "golden_gear_halo", Vector3.ZERO, false)
		glow.visibility_range_end = cull


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_clock += delta
	_model.rotation.y += SPIN_RATE * delta
	position.y = _base_y + sin(_clock * BOB_RATE) * BOB_HEIGHT


func _on_body_entered(body: Node3D) -> void:
	# A dead Tock collects nothing, as with every pickup.
	if body is Player and (body as Player).alive:
		collected.emit(index, ghost)
		set_deferred("monitoring", false)
		queue_free()
