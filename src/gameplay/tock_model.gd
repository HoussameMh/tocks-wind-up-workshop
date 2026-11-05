class_name TockModel
extends Node3D
## Tock's look and procedural animation. Feet are at y = 0 and the model faces +Z.

const BRASS := Color("d8a93f")
const TEAL := Color("1f9e9a")
const CAP_RED := Color("d43f35")
const SKIN := Color("f0c98d")
const DARK := Color("26282c")

const LEG_SWING := 0.9
const ARM_SWING := 0.75
const STRIDE_RATE := 15.0
const KEY_SPIN_IDLE := 1.5
const KEY_SPIN_RUN := 14.0
const GROW_RATE := 10.0

var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _key: Node3D
var _springs: Node3D
var _stride := 0.0
var _target_scale := 1.0
var _coiled_scale := 1.0


## coiled_scale is how much larger the coiled form is than the small one.
func _init(coiled_scale: float) -> void:
	_coiled_scale = coiled_scale
	_build_body()
	_build_head()
	_left_leg = _build_limb(Vector3(-0.12, 0.34, 0.0), 0.1, 0.3, DARK)
	_right_leg = _build_limb(Vector3(0.12, 0.34, 0.0), 0.1, 0.3, DARK)
	_left_arm = _build_limb(Vector3(-0.3, 0.68, 0.0), 0.075, 0.32, BRASS)
	_right_arm = _build_limb(Vector3(0.3, 0.68, 0.0), 0.075, 0.32, BRASS)
	_key = MeshKit.windup_key(self, BRASS, 0.8)
	_key.position = Vector3(0.0, 0.55, -0.42)
	_key.rotation.y = PI
	_build_springs()


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


func _build_body() -> void:
	MeshKit.part(self, MeshKit.capsule(0.25, 0.62), TEAL, Vector3(0.0, 0.53, 0.0))
	MeshKit.part(self, MeshKit.box(Vector3(0.28, 0.2, 0.06)), BRASS, Vector3(0.0, 0.6, 0.23), 0.7, 0.35)
	MeshKit.part(self, MeshKit.sphere(0.035, 8), DARK, Vector3(-0.07, 0.6, 0.27))
	MeshKit.part(self, MeshKit.sphere(0.035, 8), DARK, Vector3(0.07, 0.6, 0.27))


func _build_head() -> void:
	MeshKit.part(self, MeshKit.sphere(0.23), SKIN, Vector3(0.0, 0.92, 0.0))
	var cap := SphereMesh.new()
	cap.radius = 0.25
	cap.height = 0.25
	cap.is_hemisphere = true
	cap.radial_segments = 16
	cap.rings = 6
	MeshKit.part(self, cap, CAP_RED, Vector3(0.0, 0.98, 0.0))
	MeshKit.part(self, MeshKit.box(Vector3(0.3, 0.04, 0.2)), CAP_RED, Vector3(0.0, 0.98, 0.22))
	for side: float in [-1.0, 1.0]:
		MeshKit.part(self, MeshKit.sphere(0.055, 8), Color.WHITE, Vector3(side * 0.09, 0.9, 0.19))
		MeshKit.part(self, MeshKit.sphere(0.03, 8), DARK, Vector3(side * 0.09, 0.9, 0.235))


func _build_limb(pivot_position: Vector3, radius: float, length: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_position
	add_child(pivot)
	MeshKit.part(pivot, MeshKit.capsule(radius, length), color, Vector3(0.0, -length * 0.5, 0.0))
	return pivot


func _build_springs() -> void:
	_springs = Node3D.new()
	_springs.visible = false
	add_child(_springs)
	for i in 3:
		MeshKit.part(
			_springs, MeshKit.torus(0.24, 0.31), Color("c7d3dd"), Vector3(0.0, 0.34 + i * 0.13, 0.0), 0.9, 0.25
		)
