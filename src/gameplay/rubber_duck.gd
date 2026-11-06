class_name RubberDuck
extends EnemyBase
## Rubber-duck sniper: stationary, squeaks and swells as a warning, then fires a slow straight
## bubble at where Tock was. Implements design/expansion-spec.md section 4.
##
##   IDLE -> SQUEAK when Tock is within range with a clear line of sight
##   SQUEAK -> DEFLATE after squeak, firing a bubble; at the shot cap, -> COOLDOWN with no shot
##   DEFLATE -> COOLDOWN -> IDLE, on timers

enum State { IDLE, SQUEAK, DEFLATE, COOLDOWN }

const TRANSITIONS := {
	State.IDLE: [State.SQUEAK],
	State.SQUEAK: [State.DEFLATE, State.COOLDOWN],
	State.DEFLATE: [State.COOLDOWN],
	State.COOLDOWN: [State.IDLE],
}
const LEMON := Color("f2e85c")
const BILL := Color("e8622a")
const BOB_RATE := 2.6
const BOB_HEIGHT := 0.06
const HOP_BACK := 0.35
const HOP_HEIGHT := 0.25
const EYE_HEIGHT := 1.0
const MUZZLE_FORWARD := 0.75
const TORSO_RATIO := 0.5

static var _body_mesh: ArrayMesh
static var _eyes_mesh: ArrayMesh

var state: State = State.IDLE

var _range := 0.0
var _squeak := 0.0
var _aim_lock := 0.0
var _deflate := 0.0
var _cooldown := 0.0
var _turn_rate := 0.0
var _los_interval := 0.0
var _inflate_scale := 1.0
var _score_stomp := 0
var _score_bolt := 0
var _state_left := 0.0
var _los_left := 0.0
var _bob_time := 0.0
var _yaw := 0.0
var _aim_at := Vector3.ZERO
var _model: Node3D
var _query: PhysicsRayQueryParameters3D


## Call before adding to the tree. y is floor height.
func setup(at: Vector3, tuning: Tuning) -> void:
	_range = tuning.num("duck", "range")
	_squeak = tuning.num("duck", "squeak")
	_aim_lock = tuning.num("duck", "aim_lock")
	_deflate = tuning.num("duck", "deflate")
	_cooldown = tuning.num("duck", "cooldown")
	_turn_rate = tuning.num("duck", "turn_rate")
	_los_interval = tuning.num("duck", "los_interval")
	_inflate_scale = tuning.num("duck", "inflate_scale")
	_score_stomp = int(tuning.num("score", "duck_stomp"))
	_score_bolt = int(tuning.num("score", "duck_bolt"))
	var width := tuning.num("duck", "hitbox_width")
	_setup_base(tuning, at, Vector3(width, tuning.num("duck", "hitbox_height"), width))
	_query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Player.LAYER_WORLD)
	_build_model()


func _enemy_tick(delta: float) -> void:
	match state:
		State.IDLE:
			_bob_time += delta
			_model.position.y = sin(_bob_time * BOB_RATE) * BOB_HEIGHT
			_los_left -= delta
			if _los_left <= 0.0:
				_los_left = _los_interval
				if _can_see_tock():
					_begin_squeak()
		State.SQUEAK:
			_tick_squeak(delta)
		State.DEFLATE:
			_state_left -= delta
			var ratio := clampf(1.0 - _state_left / _deflate, 0.0, 1.0)
			_model.scale = Vector3.ONE * lerpf(_inflate_scale, 1.0, ratio)
			var back := Vector3(sin(_yaw), 0.0, cos(_yaw)) * -HOP_BACK * ratio
			_model.position = back + Vector3.UP * sin(ratio * PI) * HOP_HEIGHT
			if _state_left <= 0.0:
				_enter(State.COOLDOWN, _cooldown)
		State.COOLDOWN:
			_state_left -= delta
			_model.position = _model.position.move_toward(Vector3.ZERO, delta)
			if _state_left <= 0.0:
				_model.position = Vector3.ZERO
				_los_left = 0.0
				_enter(State.IDLE, 0.0)


func _on_stomped(player: Player) -> void:
	_defeat()
	player.bounce()
	scored.emit(_score_stomp, "duck_raspberry")
	# Deflates and flaps around like a let-go balloon.
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3(1.2, 0.35, 1.2), 0.1)
	for i in 5:
		var side := 1.0 if i % 2 == 0 else -1.0
		var hop := Vector3(side * 0.9, 0.4 + i * 0.3, (i - 2) * 0.5)
		tween.tween_property(_model, "position", hop, 0.12)
		tween.parallel().tween_property(_model, "rotation:y", _yaw + side * 1.6, 0.12)
	tween.parallel().tween_property(_model, "scale", Vector3.ONE * 0.15, 0.12)
	tween.tween_callback(queue_free)


func _on_bolted() -> void:
	_defeat()
	scored.emit(_score_bolt, "bolt_hit")
	sound_requested.emit("duck_squeak")
	# Squeaks all the way up and away.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "position:y", 9.0, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_model, "rotation:y", _yaw + TAU * 2.0, 0.9)
	tween.tween_property(_model, "scale", Vector3.ONE * _inflate_scale, 0.2)
	tween.chain().tween_callback(queue_free)


func _tick_squeak(delta: float) -> void:
	_state_left -= delta
	var ratio := clampf(1.0 - _state_left / _squeak, 0.0, 1.0)
	_model.scale = Vector3.ONE * lerpf(1.0, _inflate_scale, ratio)
	if _state_left > _aim_lock and _tock_in_play():
		_aim_at = _tock_torso()
		_turn_toward(_aim_at, delta)
	if _state_left > 0.0:
		return
	var shot := shots.fire_bubble(_muzzle(), _aim_at) if shots != null else null
	if shot == null:
		_model.scale = Vector3.ONE
		_enter(State.COOLDOWN, _cooldown)
		return
	sound_requested.emit("duck_raspberry")
	_enter(State.DEFLATE, _deflate)


func _begin_squeak() -> void:
	_aim_at = _tock_torso()
	_model.position = Vector3.ZERO
	_enter(State.SQUEAK, _squeak)
	sound_requested.emit("duck_squeak")


func _enter(next: State, seconds: float) -> void:
	if _table_allows(TRANSITIONS, state, next):
		state = next
		_state_left = seconds


func _can_see_tock() -> bool:
	if not _tock_in_play():
		return false
	var torso := _tock_torso()
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	if eye.distance_to(torso) > _range:
		return false
	_query.from = eye
	_query.to = torso
	return get_world_3d().direct_space_state.intersect_ray(_query).is_empty()


func _tock_torso() -> Vector3:
	var bounds := tock.contact_bounds()
	return bounds.position + bounds.size * Vector3(0.5, TORSO_RATIO, 0.5)


func _muzzle() -> Vector3:
	return global_position + Vector3.UP * EYE_HEIGHT + Vector3(sin(_yaw), 0.0, cos(_yaw)) * MUZZLE_FORWARD


func _turn_toward(point: Vector3, delta: float) -> void:
	var flat := point - global_position
	if flat.x == 0.0 and flat.z == 0.0:
		return
	_yaw = rotate_toward(_yaw, atan2(flat.x, flat.z), _turn_rate * delta)
	_model.rotation.y = _yaw


func _build_model() -> void:
	var blob := MeshKit.blob(self, Look.num("readability", "blob", "beetle_radius"))
	blob.position.y = Look.num("readability", "blob", "lift")
	_model = Node3D.new()
	add_child(_model)
	_bake_meshes()
	MeshKit.part(_model, _body_mesh, "enemy_paint")
	MeshKit.part(_model, _eyes_mesh, "beetle_eyes", Vector3.ZERO, false)
	_cull_all_parts()


static func _bake_meshes() -> void:
	if _body_mesh != null:
		return
	var body := MeshBatch.new()
	body.add_mesh(MeshKit.sphere(0.55), Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.85, 1.15)), Vector3(0.0, 0.48, 0.0)), LEMON)
	body.add_mesh(MeshKit.sphere(0.34), Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.24)), LEMON)
	body.add_mesh(MeshKit.sphere(0.17, 10), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.78, -0.62)), LEMON)
	body.add_box(Vector3(0.0, 0.97, 0.62), Vector3(0.36, 0.09, 0.26), 0.0, Vector2.ZERO, BILL)
	_body_mesh = body.commit()
	var eyes := MeshBatch.new()
	for side: float in [-1.0, 1.0]:
		eyes.add_mesh(MeshKit.sphere(0.075, 8), Transform3D(Basis.IDENTITY, Vector3(side * 0.16, 1.1, 0.5)))
	_eyes_mesh = eyes.commit()
