class_name PaperPlane
extends EnemyBase
## Paper-plane bomber: flies a rail high above the floor, drops an eraser on a clear warning, then
## swoops low enough to stomp. Implements design/expansion-spec.md section 4.
##
## The rail motion (ping-pong with a U-turn at each end) runs on its own in every state.
## The attack states below only change height and pose:
##   CRUISE -> WINDUP when Tock is within trigger_radius and cooldown is done
##   WINDUP -> SWOOP_DOWN after windup; the eraser drops at this moment
##   SWOOP_DOWN -> SWOOP_HOLD -> SWOOP_UP -> CRUISE, on timers

enum State { CRUISE, WINDUP, SWOOP_DOWN, SWOOP_HOLD, SWOOP_UP }

const TRANSITIONS := {
	State.CRUISE: [State.WINDUP],
	State.WINDUP: [State.SWOOP_DOWN],
	State.SWOOP_DOWN: [State.SWOOP_HOLD],
	State.SWOOP_HOLD: [State.SWOOP_UP],
	State.SWOOP_UP: [State.CRUISE],
}
const PAPER := Color("f4f1e8")
const PAPER_SHADE := Color("cfcabb")
const EMBER := Color("ff5a10")
const NOSE_DIP := 0.45
const ERASER_DROP_BELOW := 0.3
const BLOB_CRUISE_SCALE := 0.6
const BLOB_WINDUP_SCALE := 1.4
const FLOOR_RAY_LENGTH := 40.0
const BLOB_RAY_INTERVAL := 0.2
const TURN_LEAN := 0.5

static var _mesh: ArrayMesh

var state: State = State.CRUISE
## Rail speed; tests may set this to 0 to hold it in place.
var speed := 0.0

var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _rail_length := 0.0
var _travelled := 0.0
var _rail_sign := 1.0
var _turn_left := 0.0
var _cruise_height := 0.0
var _swoop_height := 0.0
var _height := 0.0
var _state_left := 0.0
var _cooldown_left := 0.0
var _blob_ray_left := 0.0
var _trigger_radius := 0.0
var _windup := 0.0
var _cooldown := 0.0
var _turn_seconds := 0.0
var _swoop_down := 0.0
var _swoop_hold := 0.0
var _swoop_up := 0.0
var _score_stomp := 0
var _score_bolt := 0
var _yaw := 0.0
var _eraser: EnemyShotPool.Shot
var _model: Node3D
var _blob: MeshInstance3D
var _blob_radius := 0.0
var _blob_lift := 0.0
var _query: PhysicsRayQueryParameters3D


## Call before adding to the tree. y of a is the highest floor under the rail.
func setup(a: Vector3, b: Vector3, rail_speed: float, tuning: Tuning) -> void:
	_a = a
	_b = Vector3(b.x, a.y, b.z)
	speed = rail_speed
	_rail_length = _a.distance_to(_b)
	_cruise_height = tuning.num("plane", "altitude")
	_swoop_height = tuning.num("plane", "swoop_altitude")
	_height = _cruise_height
	_trigger_radius = tuning.num("plane", "trigger_radius")
	_windup = tuning.num("plane", "windup")
	_cooldown = tuning.num("plane", "cooldown")
	_turn_seconds = tuning.num("plane", "turn_seconds")
	_swoop_down = tuning.num("plane", "swoop_down")
	_swoop_hold = tuning.num("plane", "swoop_hold")
	_swoop_up = tuning.num("plane", "swoop_up")
	_score_stomp = int(tuning.num("score", "plane_stomp"))
	_score_bolt = int(tuning.num("score", "plane_bolt"))
	var span := tuning.num("plane", "hitbox_width")
	var length := tuning.num("plane", "hitbox_depth")
	# The wings lie across the rail, and the root never turns, so the box is fixed to the rail.
	var along_x := absf(_b.x - _a.x) > absf(_b.z - _a.z)
	var hit_size := Vector3(
		length if along_x else span,
		tuning.num("plane", "hitbox_height"),
		span if along_x else length
	)
	_setup_base(tuning, _a + Vector3.UP * _cruise_height, hit_size)
	_query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Player.LAYER_WORLD)
	_build_model(hit_size.y)
	_yaw = atan2(_b.x - _a.x, _b.z - _a.z)
	_model.rotation.y = _yaw


func _enemy_tick(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_fly_rail(delta)
	_advance_state(delta)
	position = _a.lerp(_b, _travelled / _rail_length if _rail_length > 0.0 else 0.0) + Vector3.UP * _height
	if _eraser != null and _eraser.phase == EnemyShotPool.Shot.Phase.HELD:
		_eraser.position = global_position + Vector3.DOWN * ERASER_DROP_BELOW
		_eraser.rotation.y = _yaw
	_update_blob(delta)


func _on_stomped(player: Player) -> void:
	_cancel_held_eraser()
	_defeat()
	player.bounce()
	scored.emit(_score_stomp, "stomp")
	_blob.hide()
	# Crumples into a paper ball and drops.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "scale", Vector3.ONE * 0.28, 0.15)
	tween.tween_property(_model, "rotation", Vector3(TAU, _yaw + TAU, TAU), 0.5)
	tween.tween_property(self, "position:y", _a.y, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(queue_free)


func _on_bolted() -> void:
	_cancel_held_eraser()
	_defeat()
	scored.emit(_score_bolt, "bolt_hit")
	_blob.hide()
	# Spirals down with a hole in it.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_model, "rotation:y", _yaw + TAU * 3.0, 1.2)
	tween.tween_property(_model, "rotation:z", 1.1, 0.3)
	tween.tween_property(self, "position:y", _a.y + 0.2, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(queue_free)


func _fly_rail(delta: float) -> void:
	if _rail_length <= 0.0 or speed <= 0.0:
		return
	if _turn_left > 0.0:
		_turn_left -= delta
		var ratio := clampf(1.0 - _turn_left / _turn_seconds, 0.0, 1.0)
		var from_yaw := atan2((_a.x - _b.x) * _rail_sign, (_a.z - _b.z) * _rail_sign)
		_yaw = from_yaw + PI * ratio
		if state == State.CRUISE:
			_model.rotation = Vector3(0.0, _yaw, sin(ratio * PI) * TURN_LEAN)
		else:
			_model.rotation.y = _yaw
		return
	_travelled += speed * delta * _rail_sign
	if _travelled >= _rail_length or _travelled <= 0.0:
		_travelled = clampf(_travelled, 0.0, _rail_length)
		_rail_sign = -_rail_sign
		_turn_left = _turn_seconds


func _advance_state(delta: float) -> void:
	match state:
		State.CRUISE:
			if _cooldown_left <= 0.0 and _tock_within_trigger():
				_begin_windup()
		State.WINDUP:
			_state_left -= delta
			_model.rotation.x = NOSE_DIP * clampf(1.0 - _state_left / _windup, 0.0, 1.0)
			if _state_left <= 0.0:
				_drop_eraser()
				_enter(State.SWOOP_DOWN, _swoop_down)
		State.SWOOP_DOWN:
			_state_left -= delta
			_height = lerpf(_swoop_height, _cruise_height, smoothstep(0.0, 1.0, _state_left / _swoop_down))
			_model.rotation.x = NOSE_DIP
			if _state_left <= 0.0:
				_height = _swoop_height
				_enter(State.SWOOP_HOLD, _swoop_hold)
		State.SWOOP_HOLD:
			_state_left -= delta
			# A smug barrel roll at the bottom, once per hold.
			_model.rotation.x = 0.0
			_model.rotation.z = TAU * clampf(1.0 - _state_left / _swoop_hold, 0.0, 1.0)
			if _state_left <= 0.0:
				_model.rotation.z = 0.0
				_enter(State.SWOOP_UP, _swoop_up)
		State.SWOOP_UP:
			_state_left -= delta
			_height = lerpf(_cruise_height, _swoop_height, smoothstep(0.0, 1.0, _state_left / _swoop_up))
			_model.rotation.x = -NOSE_DIP * 0.5
			if _state_left <= 0.0:
				_height = _cruise_height
				_model.rotation.x = 0.0
				_enter(State.CRUISE, 0.0)


func _enter(next: State, seconds: float) -> void:
	if _table_allows(TRANSITIONS, state, next):
		state = next
		_state_left = seconds


func _tock_within_trigger() -> bool:
	if not _tock_in_play():
		return false
	var flat := tock.global_position - global_position
	flat.y = 0.0
	return flat.length() <= _trigger_radius


func _begin_windup() -> void:
	# At the shot cap the plane skips this attack and goes back to waiting.
	_eraser = shots.acquire_eraser() if shots != null else null
	if _eraser == null:
		_cooldown_left = _cooldown
		return
	_enter(State.WINDUP, _windup)
	sound_requested.emit("plane_fwip")


func _drop_eraser() -> void:
	if _eraser != null and _eraser.phase == EnemyShotPool.Shot.Phase.HELD:
		_eraser.drop()
	_cooldown_left = _cooldown


func _cancel_held_eraser() -> void:
	if _eraser != null and _eraser.phase == EnemyShotPool.Shot.Phase.HELD:
		_eraser.cancel()
	_eraser = null


## A small blob while cruising, a large one in the telegraph. It stays put under a falling eraser.
func _update_blob(delta: float) -> void:
	if _eraser != null and _eraser.is_falling():
		return
	if _eraser != null and state != State.WINDUP:
		_eraser = null
	var telegraph := state == State.WINDUP
	_blob.scale = Vector3.ONE * _blob_radius * (BLOB_WINDUP_SCALE if telegraph else BLOB_CRUISE_SCALE)
	_blob.global_position.x = global_position.x
	_blob.global_position.z = global_position.z
	_blob_ray_left -= delta
	if _blob_ray_left > 0.0 and not telegraph:
		return
	_blob_ray_left = BLOB_RAY_INTERVAL
	_query.from = global_position
	_query.to = global_position + Vector3.DOWN * FLOOR_RAY_LENGTH
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	_blob.visible = not hit.is_empty()
	if _blob.visible:
		_blob.global_position.y = (hit["position"] as Vector3).y + _blob_lift


func _build_model(hit_height: float) -> void:
	_blob_radius = Look.num("readability", "blob", "beetle_radius")
	_blob_lift = Look.num("readability", "blob", "lift")
	_blob = MeshKit.blob(self, _blob_radius)
	_blob.top_level = true
	_model = Node3D.new()
	_model.position.y = hit_height * 0.5
	add_child(_model)
	MeshKit.part(_model, _get_mesh(), "enemy_paper", Vector3.ZERO, false)
	_cull_all_parts()


## Two flat wedge wings meeting at the nose (+Z), a keel, and ember eyes. One draw, per the spec.
static func _get_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var flat := Basis(Vector3.RIGHT, PI / 2.0)
	var batch := MeshBatch.new()
	for side: float in [-1.0, 1.0]:
		var wing := PrismMesh.new()
		wing.size = Vector3(1.2, 1.6, 0.05)
		wing.left_to_right = 1.0 if side < 0.0 else 0.0
		var tilt := Basis(Vector3.BACK, side * 0.16) * flat
		batch.add_mesh(wing, Transform3D(tilt, Vector3(side * 0.6, 0.08, 0.0)), PAPER)
		batch.add_mesh(
			MeshKit.sphere(0.075, 8),
			Transform3D(Basis.IDENTITY, Vector3(side * 0.1, 0.09, 0.42)),
			EMBER
		)
	var keel := PrismMesh.new()
	keel.size = Vector3(1.5, 0.3, 0.06)
	keel.left_to_right = 0.7
	# Local X runs along the plane and local Y points down, so the wedge hangs under the wings.
	var keel_basis := Basis(Vector3(0.0, 0.0, 1.0), Vector3(0.0, -1.0, 0.0), Vector3(1.0, 0.0, 0.0))
	batch.add_mesh(keel, Transform3D(keel_basis, Vector3(0.0, -0.1, 0.0)), PAPER_SHADE)
	_mesh = batch.commit()
	return _mesh
