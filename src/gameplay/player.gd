class_name Player
extends CharacterBody3D
## Tock's movement and interaction with the world. Implements the MVP movement in
## design/game-brief.md. Other systems listen to its signals; it knows nothing of UI.

signal jumped
signal hurt
signal died
signal form_changed(coiled: bool)


## One tick of intent, from input or from a test bot.
class Command:
	extends RefCounted
	var move := Vector3.ZERO
	var jump_pressed := false
	var jump_held := false
	var run := false


const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_HIDDEN := 4
const SHADOW_RAY_LENGTH := 40.0
const SHADOW_LIFT := 0.03
const BLINK_RATE := 16.0
const HEAD_BUMP_NORMAL_Y := -0.5
const FACING_COURSE_YAW := PI

## Set by tests to replace player input. Must return a Command.
var bot_control := Callable()
## Input and damage are ignored while false.
var controls_enabled := false
## Set by the camera; movement is relative to this.
var camera_yaw := 0.0
## Vertical speed just before the latest physics move, used to detect stomps.
var fall_velocity_y := 0.0
var alive := true

var _power: PowerState
var _assist: JumpAssist
var _model: TockModel
var _capsule: CapsuleShape3D
var _collider: CollisionShape3D
var _shadow: MeshInstance3D
var _command := Command.new()
var _can_cut_jump := false

var _walk_speed := 0.0
var _run_speed := 0.0
var _ground_acceleration := 0.0
var _ground_deceleration := 0.0
var _air_acceleration := 0.0
var _turn_rate := 0.0
var _gravity_rise := 0.0
var _gravity_fall := 0.0
var _max_fall_speed := 0.0
var _jump_height_small := 0.0
var _jump_height_coiled := 0.0
var _jump_cut_multiplier := 0.0
var _stomp_bounce := 0.0
var _stomp_bounce_held := 0.0
var _hurt_bounce := 0.0
var _height_small := 0.0
var _height_coiled := 0.0
var _kill_height := 0.0


## Reads tuning and builds the body. Call before adding to the tree.
func setup(tuning: Tuning) -> void:
	_walk_speed = tuning.num("player", "walk_speed")
	_run_speed = tuning.num("player", "run_speed")
	_ground_acceleration = tuning.num("player", "ground_acceleration")
	_ground_deceleration = tuning.num("player", "ground_deceleration")
	_air_acceleration = tuning.num("player", "air_acceleration")
	_turn_rate = tuning.num("player", "turn_rate")
	_gravity_rise = tuning.num("player", "gravity_rise")
	_gravity_fall = tuning.num("player", "gravity_fall")
	_max_fall_speed = tuning.num("player", "max_fall_speed")
	_jump_height_small = tuning.num("player", "jump_height_small")
	_jump_height_coiled = tuning.num("player", "jump_height_coiled")
	_jump_cut_multiplier = tuning.num("player", "jump_cut_multiplier")
	_stomp_bounce = tuning.num("player", "stomp_bounce_speed")
	_stomp_bounce_held = tuning.num("player", "stomp_bounce_speed_held")
	_hurt_bounce = tuning.num("player", "hurt_bounce_speed")
	_height_small = tuning.num("player", "capsule_height_small")
	_height_coiled = tuning.num("player", "capsule_height_coiled")
	_kill_height = tuning.num("player", "kill_height")

	_power = PowerState.new(tuning.num("player", "invulnerable_seconds"))
	_assist = JumpAssist.new(
		tuning.num("player", "coyote_seconds"), tuning.num("player", "jump_buffer_seconds")
	)

	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD
	floor_snap_length = 0.2

	_capsule = CapsuleShape3D.new()
	_capsule.radius = tuning.num("player", "capsule_radius")
	_collider = CollisionShape3D.new()
	_collider.shape = _capsule
	add_child(_collider)
	_apply_collider_height(_height_small)

	_model = TockModel.new(_height_coiled / _height_small)
	_model.rotation.y = FACING_COURSE_YAW
	add_child(_model)

	_shadow = MeshInstance3D.new()
	_shadow.mesh = MeshKit.cylinder(0.45, 0.45, 0.01, 18)
	var shadow_material := MeshKit.color_material(Color(0.0, 0.0, 0.0, 0.45))
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = shadow_material
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)


func is_coiled() -> bool:
	return _power.form == PowerState.Form.COILED


func is_invulnerable() -> bool:
	return _power.is_invulnerable()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_power.tick(delta)
	_read_command()
	var on_floor := is_on_floor()
	_assist.tick(delta, on_floor)
	if _command.jump_pressed:
		_assist.press()
	_update_horizontal(delta, on_floor)
	_update_vertical(delta, on_floor)
	fall_velocity_y = velocity.y
	collision_mask = LAYER_WORLD | (LAYER_HIDDEN if velocity.y > 0.0 else 0)
	move_and_slide()
	_bump_blocks()
	_update_visuals(delta)
	if global_position.y < _kill_height:
		die()


## Gives the Coil Spring power.
func apply_power_up() -> void:
	if _power.apply_pickup():
		_apply_form()


## Bounces after a stomp; higher if jump is held.
func bounce() -> void:
	velocity.y = _stomp_bounce_held if _command.jump_held else _stomp_bounce
	_can_cut_jump = false
	_assist.cancel_coyote()


## Launches upward from a spring pad.
func launch(speed: float) -> void:
	velocity.y = speed
	_can_cut_jump = false
	_assist.cancel_coyote()


## Damages Tock: shrink if coiled, otherwise lose the life.
func take_hit() -> void:
	if not alive or not controls_enabled:
		return
	match _power.apply_hit():
		PowerState.HitResult.SHRUNK:
			velocity.y = _hurt_bounce
			_apply_form()
			hurt.emit()
		PowerState.HitResult.FATAL:
			die()


## Ends the current life.
func die() -> void:
	if not alive:
		return
	alive = false
	velocity = Vector3.ZERO
	_shadow.visible = false
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.25)
	died.emit()


## Returns to life at a position, in small form.
func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	fall_velocity_y = 0.0
	alive = true
	_power.reset()
	_apply_collider_height(_height_small)
	_model.reset_pose()
	_model.rotation.y = FACING_COURSE_YAW
	form_changed.emit(false)


func _read_command() -> void:
	if not controls_enabled:
		_command.move = Vector3.ZERO
		_command.jump_pressed = false
		_command.jump_held = false
		_command.run = false
		return
	if bot_control.is_valid():
		_command = bot_control.call()
		return
	var stick := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_command.move = Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, camera_yaw)
	_command.jump_pressed = Input.is_action_just_pressed("jump")
	_command.jump_held = Input.is_action_pressed("jump")
	_command.run = Input.is_action_pressed("run")


func _update_horizontal(delta: float, on_floor: bool) -> void:
	var top_speed := _run_speed if _command.run else _walk_speed
	var target := _command.move.limit_length(1.0) * top_speed
	var rate := _air_acceleration
	if on_floor:
		rate = _ground_acceleration if target.length_squared() > 0.0 else _ground_deceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _update_vertical(delta: float, on_floor: bool) -> void:
	if _assist.consume_jump():
		var height := _jump_height_coiled if is_coiled() else _jump_height_small
		velocity.y = JumpAssist.launch_speed(height, _gravity_rise)
		_can_cut_jump = true
		jumped.emit()
		return
	if _can_cut_jump and velocity.y > 0.0 and not _command.jump_held:
		velocity.y *= _jump_cut_multiplier
		_can_cut_jump = false
	if on_floor and velocity.y <= 0.0:
		_can_cut_jump = false
		return
	var gravity := _gravity_rise if velocity.y > 0.0 else _gravity_fall
	velocity.y = maxf(velocity.y - gravity * delta, -_max_fall_speed)


func _bump_blocks() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y < HEAD_BUMP_NORMAL_Y and collision.get_collider() is SurpriseBlock:
			(collision.get_collider() as SurpriseBlock).bump(is_coiled())


func _update_visuals(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if _command.move.length_squared() > 0.01:
		var yaw := atan2(_command.move.x, _command.move.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, yaw, clampf(_turn_rate * delta, 0.0, 1.0))
	_model.animate(delta, clampf(horizontal.length() / _run_speed, 0.0, 1.0), is_on_floor(), velocity.y)
	_model.visible = not is_invulnerable() or sin(Time.get_ticks_msec() * 0.001 * BLINK_RATE * TAU) > 0.0
	_update_shadow()


func _update_shadow() -> void:
	var from := global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(
		from, from + Vector3.DOWN * SHADOW_RAY_LENGTH, LAYER_WORLD
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_shadow.visible = not hit.is_empty()
	if _shadow.visible:
		_shadow.global_position = (hit["position"] as Vector3) + Vector3.UP * SHADOW_LIFT


func _apply_form() -> void:
	var coiled := is_coiled()
	_apply_collider_height(_height_coiled if coiled else _height_small)
	_model.set_coiled(coiled)
	form_changed.emit(coiled)


func _apply_collider_height(height: float) -> void:
	_capsule.height = height
	_collider.position = Vector3(0.0, height * 0.5, 0.0)
