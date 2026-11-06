class_name FollowCamera
extends Camera3D
## Third-person camera with mouse and stick orbit. It pulls in when scenery blocks its view.
## Also holds the locked macro shot behind the title screen (art-bible section 6).

const WALL_PADDING := 0.3
const MIN_DISTANCE := 1.5
const PLAY_FOV := 65.0

const TITLE_FOV := 38.0
const TITLE_DISTANCE := 4.0
const TITLE_HEIGHT := 0.7
const TITLE_PITCH_DEGREES := 6.0
## Direction of the shot around Tock. Looks across the bench at the pegboard wall and a lamp.
const TITLE_YAW_DEGREES := 58.0
const TITLE_SWAY_DEGREES := 7.0
const TITLE_SWAY_SECONDS := 16.0
## Sideways shift of the view that puts Tock in the right third of the frame.
const TITLE_SIDE_SHIFT := -0.82

## While true, the camera holds the title shot. Tock is not controllable then.
var title_shot := false:
	set(value):
		title_shot = value
		fov = TITLE_FOV if value else PLAY_FOV
		h_offset = TITLE_SIDE_SHIFT if value else 0.0
## While false, the title shot holds still. Turned off by the reduced motion setting.
var sway_enabled := true
## While false, the sticks do not turn the camera, so they can drive a menu instead.
var stick_enabled := false
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
var _title_clock := 0.0


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
	fov = PLAY_FOV
	far = 500.0


## Applies a level's own framing from its optional "camera" entry: pitch_degrees, focus_height and
## distance, each optional. The boss level uses it to keep the Baron in the frame.
func apply_framing(framing: Dictionary) -> void:
	if framing.has("pitch_degrees"):
		pitch = deg_to_rad(framing["pitch_degrees"])
	_height_offset = framing.get("focus_height", _height_offset)
	_distance = framing.get("distance", _distance)
	snap_to_target()


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
	if title_shot:
		_hold_title_shot(delta)
		return
	if stick_enabled:
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


func _hold_title_shot(delta: float) -> void:
	var sway := 0.0
	if sway_enabled:
		_title_clock = fposmod(_title_clock + delta, TITLE_SWAY_SECONDS)
		sway = sin(TAU * _title_clock / TITLE_SWAY_SECONDS) * TITLE_SWAY_DEGREES
	var shot_pitch := deg_to_rad(TITLE_PITCH_DEGREES)
	var direction := Vector3(0.0, sin(shot_pitch), cos(shot_pitch)).rotated(
		Vector3.UP, deg_to_rad(TITLE_YAW_DEGREES + sway)
	)
	var focus := _target.global_position + Vector3.UP * TITLE_HEIGHT
	global_position = focus + direction * TITLE_DISTANCE
	look_at(focus)


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
