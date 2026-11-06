class_name TockModel
extends Node3D
## Tock's look and procedural animation. Feet are at y = 0 and the model faces +Z.

const EYE_WHITE := Color("f5f1e6")
const EYE_DARK := Color("15161a")

const LEG_SWING := 0.9
const ARM_SWING := 0.75
const STRIDE_RATE := 15.0
const KEY_SPIN_IDLE := 1.5
const KEY_SPIN_RUN := 14.0
const GROW_RATE := 10.0
const BARREL_OFFSET := Vector3(0.0, -0.42, 0.0)
const BARREL_ARM_POSE := -PI / 2.0

static var _meshes: Dictionary = {}

var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _key: Node3D
var _springs: Node3D
var _barrel: MeshInstance3D
var _has_blaster := false
var _stride := 0.0
var _target_scale := 1.0
var _coiled_scale := 1.0


## coiled_scale is how much larger the coiled form is than the small one.
func _init(coiled_scale: float) -> void:
	_coiled_scale = coiled_scale
	_bake_meshes()
	MeshKit.part(self, _meshes["overalls"], "tock_overalls", Vector3(0.0, 0.53, 0.0))
	MeshKit.part(self, _meshes["plate"], "tock_brass", Vector3(0.0, 0.6, 0.23), false)
	MeshKit.part(self, _meshes["head"], "tock_head", Vector3(0.0, 0.92, 0.0))
	MeshKit.part(self, _meshes["cap"], "tock_cap")
	MeshKit.part(self, _meshes["eyes"], "tock_eyes", Vector3.ZERO, false)
	_left_leg = _build_limb(Vector3(-0.12, 0.34, 0.0), _meshes["leg"], "tock_legs")
	_right_leg = _build_limb(Vector3(0.12, 0.34, 0.0), _meshes["leg"], "tock_legs")
	_left_arm = _build_limb(Vector3(-0.3, 0.68, 0.0), _meshes["arm"], "tock_brass")
	_right_arm = _build_limb(Vector3(0.3, 0.68, 0.0), _meshes["arm"], "tock_brass")
	_key = MeshKit.windup_key(self, "tock_brass", 0.8, false)
	_key.position = Vector3(0.0, 0.55, -0.42)
	_key.rotation.y = PI
	_build_springs()
	# Hangs off the arm's end; the held-out pose in animate() points it forward. One draw, no shadow.
	_barrel = MeshKit.part(_right_arm, _meshes["barrel"], "steel_trim", BARREL_OFFSET, false)
	_barrel.visible = false


## Shows the barrel and holds the arm out while the Bolt Blaster is carried.
func set_blaster(has_blaster: bool) -> void:
	_has_blaster = has_blaster
	_barrel.visible = has_blaster


## Switches between forms; the size change is animated.
func set_coiled(coiled: bool) -> void:
	_target_scale = _coiled_scale if coiled else 1.0
	_springs.visible = coiled


## Immediately returns to the standing pose at small size, for respawning.
func reset_pose() -> void:
	_target_scale = 1.0
	scale = Vector3.ONE
	visible = true
	_springs.visible = false
	set_blaster(false)


## speed_ratio is 0 at rest and 1 at full run.
func animate(delta: float, speed_ratio: float, grounded: bool, velocity_y: float) -> void:
	_key.rotation.z += delta * lerpf(KEY_SPIN_IDLE, KEY_SPIN_RUN, speed_ratio)
	scale = scale.lerp(Vector3.ONE * _target_scale, clampf(GROW_RATE * delta, 0.0, 1.0))
	if grounded:
		_stride += delta * STRIDE_RATE * speed_ratio
		var swing := sin(_stride) * minf(speed_ratio * 1.5, 1.0)
		_left_leg.rotation.x = swing * LEG_SWING
		_right_leg.rotation.x = -swing * LEG_SWING
		_left_arm.rotation.x = -swing * ARM_SWING
		_right_arm.rotation.x = swing * ARM_SWING
	else:
		var air_pose := -1.1 if velocity_y > 0.0 else -0.5
		_left_leg.rotation.x = -0.6
		_right_leg.rotation.x = 0.4
		_left_arm.rotation.x = air_pose
		_right_arm.rotation.x = air_pose
	if _has_blaster:
		_right_arm.rotation.x = BARREL_ARM_POSE


## Builds the shared meshes once. Parts with the same material are merged, so Tock costs
## at most 12 draw calls: five body parts, four limbs, the key, the coiled form's springs
## and the blaster's barrel.
static func _bake_meshes() -> void:
	if not _meshes.is_empty():
		return
	_meshes["overalls"] = MeshKit.capsule(0.25, 0.62)
	_meshes["plate"] = MeshKit.box(Vector3(0.28, 0.2, 0.06))
	_meshes["head"] = MeshKit.sphere(0.23)
	_meshes["leg"] = _limb_mesh(0.1, 0.3)
	_meshes["arm"] = _limb_mesh(0.075, 0.32)

	var barrel := MeshBatch.new()
	barrel.add_mesh(MeshKit.cylinder(0.1, 0.1, 0.42, 10))
	barrel.add_mesh(MeshKit.cylinder(0.16, 0.16, 0.09, 6), Transform3D(Basis.IDENTITY, Vector3.DOWN * 0.17))
	barrel.add_mesh(MeshKit.cylinder(0.16, 0.16, 0.07, 6), Transform3D(Basis.IDENTITY, Vector3.UP * 0.17))
	_meshes["barrel"] = barrel.commit()

	var cap_dome := SphereMesh.new()
	cap_dome.radius = 0.25
	cap_dome.height = 0.25
	cap_dome.is_hemisphere = true
	cap_dome.radial_segments = 16
	cap_dome.rings = 6
	var cap := MeshBatch.new()
	cap.add_mesh(cap_dome, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.98, 0.0)))
	cap.add_box(Vector3(0.0, 0.98, 0.22), Vector3(0.3, 0.04, 0.2))
	_meshes["cap"] = cap.commit()

	var eyes := MeshBatch.new()
	var button := MeshKit.sphere(0.035, 8)
	var white := MeshKit.sphere(0.055, 8)
	var pupil := MeshKit.sphere(0.03, 8)
	for side: float in [-1.0, 1.0]:
		eyes.add_mesh(button, Transform3D(Basis.IDENTITY, Vector3(side * 0.07, 0.6, 0.27)), EYE_DARK)
		eyes.add_mesh(white, Transform3D(Basis.IDENTITY, Vector3(side * 0.09, 0.9, 0.19)), EYE_WHITE)
		eyes.add_mesh(pupil, Transform3D(Basis.IDENTITY, Vector3(side * 0.09, 0.9, 0.235)), EYE_DARK)
	_meshes["eyes"] = eyes.commit()

	var springs := MeshBatch.new()
	var ring := MeshKit.torus(0.24, 0.31)
	for i in 3:
		springs.add_mesh(ring, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.34 + i * 0.13, 0.0)))
	_meshes["springs"] = springs.commit()


static func _limb_mesh(radius: float, length: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	batch.add_mesh(MeshKit.capsule(radius, length), Transform3D(Basis.IDENTITY, Vector3(0.0, -length * 0.5, 0.0)))
	return batch.commit()


func _build_limb(pivot_position: Vector3, mesh: Mesh, row: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_position
	add_child(pivot)
	MeshKit.part(pivot, mesh, row)
	return pivot


func _build_springs() -> void:
	_springs = Node3D.new()
	_springs.visible = false
	add_child(_springs)
	MeshKit.part(_springs, _meshes["springs"], "coil_metal", Vector3.ZERO, false)
