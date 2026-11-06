class_name ChatteringTeeth
extends EnemyBase
## Chattering teeth: winds up loudly, hops at Tock three times, then runs down. They hop on floors
## only and laugh at a ledge rather than follow. Implements design/expansion-spec.md section 4.
##
##   DORMANT -> WIND when Tock is within trigger
##   WIND -> HOP -> LAND, then back to HOP until hops are done
##   LAND -> TIRED after the last hop
##   TIRED -> WIND if Tock is within keep_chasing, else DORMANT

enum State { DORMANT, WIND, HOP, LAND, TIRED }

const TRANSITIONS := {
	State.DORMANT: [State.WIND],
	State.WIND: [State.HOP],
	State.HOP: [State.LAND],
	State.LAND: [State.HOP, State.TIRED],
	State.TIRED: [State.WIND, State.DORMANT],
}
const GUM := Color("e8788c")
const TOOTH := Color("fbf7ec")
const FOOT := Color("c95f74")
const EMBER := Color("ff5a10")
const JAW_OPEN := -0.65
const JAW_CHATTER_RATE := 34.0
const JAW_CHATTER := 0.22
const KEY_WIND_RATE := 16.0
const KEY_RUN_DOWN_RATE := 1.5
const FLOOR_RAY_ABOVE := 1.0
const FLOOR_RAY_BELOW := 1.0
const WALL_RAY_HEIGHT := 0.4

static var _lower_mesh: ArrayMesh
static var _upper_mesh: ArrayMesh

var state: State = State.DORMANT
## True for a hop that stayed put because there was no floor ahead.
var at_ledge := false

var _trigger := 0.0
var _keep_chasing := 0.0
var _wind := 0.0
var _hop_seconds := 0.0
var _hop_distance := 0.0
var _hop_height := 0.0
var _land := 0.0
var _tired := 0.0
var _hops := 0
var _score_stomp := 0
var _score_bolt := 0
var _state_left := 0.0
var _hops_done := 0
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _yaw := 0.0
var _turn_rate := 0.0
var _blob_lift := 0.0
var _chatter_time := 0.0
var _model: Node3D
var _upper: Node3D
var _key: Node3D
var _blob: MeshInstance3D
var _query: PhysicsRayQueryParameters3D


## Call before adding to the tree. y is floor height.
func setup(at: Vector3, tuning: Tuning) -> void:
	_trigger = tuning.num("teeth", "trigger")
	_keep_chasing = tuning.num("teeth", "keep_chasing")
	_wind = tuning.num("teeth", "wind")
	_hop_seconds = tuning.num("teeth", "hop_seconds")
	_hop_distance = tuning.num("teeth", "hop_distance")
	_hop_height = tuning.num("teeth", "hop_height")
	_land = tuning.num("teeth", "land")
	_tired = tuning.num("teeth", "tired")
	_hops = int(tuning.num("teeth", "hops"))
	_score_stomp = int(tuning.num("score", "teeth_stomp"))
	_score_bolt = int(tuning.num("score", "teeth_bolt"))
	# The duck's turn rate is the only "turn to Tock" value in the spec's tuning block.
	_turn_rate = tuning.num("duck", "turn_rate")
	var width := tuning.num("teeth", "hitbox_width")
	_setup_base(tuning, at, Vector3(width, tuning.num("teeth", "hitbox_height"), width))
	_query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Player.LAYER_WORLD)
	_build_model()


func _enemy_tick(delta: float) -> void:
	match state:
		State.DORMANT:
			_upper.rotation.x = 0.0
			if _tock_within(_trigger):
				_begin_wind()
		State.WIND:
			_state_left -= delta
			_key.rotation.z += KEY_WIND_RATE * delta
			_chatter(delta)
			if _tock_in_play():
				_turn_toward(tock.global_position, delta)
			if _state_left <= 0.0:
				_hops_done = 0
				_begin_hop()
		State.HOP:
			_tick_hop(delta)
		State.LAND:
			_state_left -= delta
			_chatter(delta)
			if _state_left <= 0.0:
				_hops_done += 1
				if _hops_done < _hops:
					_begin_hop()
				else:
					_enter(State.TIRED, _tired)
		State.TIRED:
			_state_left -= delta
			_upper.rotation.x = JAW_OPEN
			_key.rotation.z += KEY_RUN_DOWN_RATE * delta * clampf(_state_left / _tired, 0.0, 1.0)
			if _state_left <= 0.0:
				if _tock_within(_keep_chasing):
					_begin_wind()
				else:
					_enter(State.DORMANT, 0.0)


func _on_stomped(player: Player) -> void:
	_defeat()
	player.bounce()
	scored.emit(_score_stomp, "stomp")
	_blob.hide()
	# Bites itself shut, flat.
	_upper.rotation.x = 0.0
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3(1.25, 0.2, 1.25), 0.1)
	tween.tween_interval(0.3)
	tween.tween_callback(queue_free)


func _on_bolted() -> void:
	_defeat()
	scored.emit(_score_bolt, "bolt_hit")
	_blob.hide()
	# Top and bottom jaws fly apart.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_upper, "position:y", _upper.position.y + 2.2, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_upper, "rotation:x", JAW_OPEN * 4.0, 0.45)
	tween.tween_property(_model, "position:y", -0.1, 0.45)
	tween.tween_property(_model, "rotation:z", 0.5, 0.45)
	tween.chain().tween_callback(queue_free)


func _begin_wind() -> void:
	_enter(State.WIND, _wind)
	sound_requested.emit("teeth_wind")
	sound_requested.emit("teeth_chatter")


func _begin_hop() -> void:
	_enter(State.HOP, _hop_seconds)
	_hop_from = global_position
	_hop_to = _hop_from
	at_ledge = false
	if not _tock_in_play():
		return
	var flat := tock.global_position - _hop_from
	flat.y = 0.0
	if flat.length_squared() <= 0.0001:
		return
	_yaw = atan2(flat.x, flat.z)
	_model.rotation.y = _yaw
	var landing := _hop_from + flat.normalized() * _hop_distance
	var floor_y: Variant = _floor_at(landing)
	if floor_y == null or _wall_between(_hop_from, landing):
		# Stays and laughs at the edge instead of following.
		at_ledge = true
		sound_requested.emit("teeth_chatter")
		return
	_hop_to = Vector3(landing.x, floor_y, landing.z)


func _tick_hop(delta: float) -> void:
	_state_left -= delta
	var ratio := clampf(1.0 - _state_left / _hop_seconds, 0.0, 1.0)
	var at := _hop_from.lerp(_hop_to, ratio)
	at.y += 4.0 * _hop_height * ratio * (1.0 - ratio)
	global_position = at
	_blob.position.y = _hop_from.lerp(_hop_to, ratio).y - at.y + _blob_lift
	_upper.rotation.x = JAW_OPEN * sin(ratio * PI) * 0.5
	if at_ledge:
		_chatter(delta)
	if _state_left <= 0.0:
		global_position = _hop_to
		_blob.position.y = _blob_lift
		_enter(State.LAND, _land)


func _chatter(delta: float) -> void:
	_chatter_time += delta
	_upper.rotation.x = -JAW_CHATTER * (1.0 + sin(_chatter_time * JAW_CHATTER_RATE))


func _enter(next: State, seconds: float) -> void:
	if _table_allows(TRANSITIONS, state, next):
		state = next
		_state_left = seconds


func _tock_within(distance: float) -> bool:
	if not _tock_in_play():
		return false
	var flat := tock.global_position - global_position
	flat.y = 0.0
	return flat.length() <= distance


func _floor_at(point: Vector3) -> Variant:
	_query.from = point + Vector3.UP * FLOOR_RAY_ABOVE
	_query.to = point + Vector3.DOWN * FLOOR_RAY_BELOW
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else null


func _wall_between(from: Vector3, to: Vector3) -> bool:
	_query.from = from + Vector3.UP * WALL_RAY_HEIGHT
	_query.to = to + Vector3.UP * WALL_RAY_HEIGHT
	return not get_world_3d().direct_space_state.intersect_ray(_query).is_empty()


func _turn_toward(point: Vector3, delta: float) -> void:
	var flat := point - global_position
	if flat.x == 0.0 and flat.z == 0.0:
		return
	_yaw = rotate_toward(_yaw, atan2(flat.x, flat.z), _turn_rate * delta)
	_model.rotation.y = _yaw


func _build_model() -> void:
	_blob_lift = Look.num("readability", "blob", "lift")
	_blob = MeshKit.blob(self, Look.num("readability", "blob", "beetle_radius"))
	_blob.position.y = _blob_lift
	_model = Node3D.new()
	add_child(_model)
	_bake_meshes()
	MeshKit.part(_model, _lower_mesh, "enemy_paint", Vector3.ZERO, false)
	_upper = Node3D.new()
	_upper.position = Vector3(0.0, 0.42, -0.48)
	_model.add_child(_upper)
	MeshKit.part(_upper, _upper_mesh, "enemy_paint")
	_key = MeshKit.windup_key(_model, "beetle_gear", 1.0, false)
	_key.position = Vector3(0.0, 0.4, -0.75)
	_key.rotation.y = PI
	_cull_all_parts()


static func _bake_meshes() -> void:
	if _lower_mesh != null:
		return
	var teeth_x: Array[float] = [-0.36, -0.18, 0.0, 0.18, 0.36]
	var lower := MeshBatch.new()
	lower.add_box(Vector3(0.0, 0.25, 0.0), Vector3(1.0, 0.24, 0.96), 0.0, Vector2.ZERO, GUM)
	for x in teeth_x:
		lower.add_box(Vector3(x, 0.42, 0.4), Vector3(0.15, 0.13, 0.12), 0.0, Vector2.ZERO, TOOTH)
	for side: float in [-1.0, 1.0]:
		lower.add_box(Vector3(side * 0.3, 0.07, 0.08), Vector3(0.28, 0.14, 0.6), 0.0, Vector2.ZERO, FOOT)
	_lower_mesh = lower.commit()
	# The upper jaw hinges at the back, so its parts sit forward of the pivot.
	var upper := MeshBatch.new()
	upper.add_box(Vector3(0.0, 0.16, 0.48), Vector3(1.0, 0.24, 0.96), 0.0, Vector2.ZERO, GUM)
	for x in teeth_x:
		upper.add_box(Vector3(x, -0.0, 0.88), Vector3(0.15, 0.13, 0.12), 0.0, Vector2.ZERO, TOOTH)
	for side: float in [-1.0, 1.0]:
		upper.add_mesh(MeshKit.sphere(0.08, 8), Transform3D(Basis.IDENTITY, Vector3(side * 0.24, 0.32, 0.78)), EMBER)
	_upper_mesh = upper.commit()
