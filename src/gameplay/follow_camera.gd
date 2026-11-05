class_name FollowCamera
extends Camera3D
## Third-person camera with mouse and stick orbit. It pulls in when scenery blocks its view.

const WALL_PADDING := 0.3
const MIN_DISTANCE := 1.5

## While true, the camera slowly circles the player for the title screen.
var title_orbit := false
var yaw := 0.0
var pitch := 0.0

var _target: Player
var _focus := Vector3.ZERO
var _distance := 0.0
var _height_offset := 0.0
var _pitch_min := 0.0
var _pitch_max := 0.0
var _mouse_sensitivity := 0.0
var _stick_speed := 0.0
var _follow_rate := 0.0
var _title_orbit_speed := 0.0


## Call before adding to the tree.
func setup(tuning: Tuning, target: Player) -> void:
	_target = target
	_distance = tuning.num("camera", "distance")
	_height_offset = tuning.num("camera", "height_offset")
	pitch = deg_to_rad(tuning.num("camera", "pitch_degrees"))
	_pitch_min = deg_to_rad(tuning.num("camera", "pitch_min_degrees"))
	_pitch_max = deg_to_rad(tuning.num("camera", "pitch_max_degrees"))
	_mouse_sensitivity = tuning.num("camera", "mouse_sensitivity")
	_stick_speed = tuning.num("camera", "stick_speed")
	_follow_rate = tuning.num("camera", "follow_rate")
	_title_orbit_speed = tuning.num("camera", "title_orbit_speed")
	fov = 65.0
	far = 500.0


## Jumps straight to the target, for respawning.
func snap_to_target() -> void:
	_focus = _focus_goal()


func _ready() -> void:
	snap_to_target()
	make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := (event as InputEventMouseMotion).relative
		yaw -= motion.x * _mouse_sensitivity
		pitch = clampf(pitch + motion.y * _mouse_sensitivity, _pitch_min, _pitch_max)


func _physics_process(delta: float) -> void:
	if title_orbit:
		yaw += delta * _title_orbit_speed
	else:
		yaw -= Input.get_axis("camera_left", "camera_right") * _stick_speed * delta
		pitch = clampf(
			pitch + Input.get_axis("camera_up", "camera_down") * _stick_speed * delta,
			_pitch_min,
			_pitch_max
		)
	_target.camera_yaw = yaw
	_focus = _focus.lerp(_focus_goal(), clampf(_follow_rate * delta, 0.0, 1.0))
	var direction := Vector3(0.0, sin(pitch), cos(pitch)).rotated(Vector3.UP, yaw)
	global_position = _focus + direction * _clear_distance(direction)
	look_at(_focus)


func _focus_goal() -> Vector3:
	return _target.global_position + Vector3.UP * _height_offset


func _clear_distance(direction: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		_focus, _focus + direction * _distance, Player.LAYER_WORLD
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return _distance
	return maxf(_focus.distance_to(hit["position"] as Vector3) - WALL_PADDING, MIN_DISTANCE)
