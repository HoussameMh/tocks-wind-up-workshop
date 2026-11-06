class_name BaronRust
extends Node3D
## The final boss: a vain old bench vise with a moustache, a monocle and a very small hat.
## Implements design/expansion-spec.md section 6. Numbers live in BossRules and the "boss" tuning.
##
## Flow, with no other moves allowed (TRANSITIONS):
##   ATTACK -> DROOP when the phase's attack list is done
##   DROOP -> EXPOSED -> RAISE -> ATTACK, repeating the phase, on timers or a spent window
##   EXPOSED or RAISE -> BREAK when a phase's health runs out; BREAK -> ATTACK starts the next
##   any fighting state -> GRACE when Tock respawns; GRACE -> ATTACK
##   EXPOSED -> DEFEAT at no health; DEFEAT -> DONE when the key has risen

signal scored(points: int, sound: String)
signal sound_requested(sound: String)
signal hp_changed(hp: int, max_hp: int)
## Health is gone; the clock should stop and the bonus be paid.
signal defeated
## The Baron has something to say.
signal taunted(line: String)

enum State { ATTACK, DROOP, EXPOSED, RAISE, BREAK, GRACE, DEFEAT, DONE }
enum Attack { SLAM, LOB, DENTURE, SWEEP }
enum Step { TELL, ACTIVE, RECOVER }

const TRANSITIONS := {
	State.ATTACK: [State.DROOP, State.GRACE],
	State.DROOP: [State.EXPOSED, State.GRACE],
	State.EXPOSED: [State.RAISE, State.BREAK, State.DEFEAT, State.GRACE],
	State.RAISE: [State.ATTACK, State.GRACE],
	State.BREAK: [State.ATTACK, State.GRACE],
	State.GRACE: [State.ATTACK, State.GRACE],
	State.DEFEAT: [State.DONE],
	State.DONE: [],
}
## The attacks of each phase, in order, before the Baron droops.
const SEQUENCES: Array = [
	[Attack.SLAM, Attack.SLAM, Attack.SLAM],
	[Attack.LOB, Attack.DENTURE, Attack.SLAM],
	[Attack.SWEEP, Attack.LOB, Attack.SLAM, Attack.SWEEP],
]
const LOB_THROWS := 3
const DENTURE_LANDINGS: Array[Vector3] = [Vector3(-6.0, 0.0, -14.0), Vector3(6.0, 0.0, -14.0)]
const WEAK_SPOT := Vector3(0.0, 2.4, -24.5)
const RING_ORIGIN := Vector3(0.0, 0.0, -25.0)
const HEAD_HIGH := Vector3(0.0, 10.4, -28.6)
const HAND_FROM := Vector3(0.0, 9.0, -27.5)
const ARENA := Rect2(-12.6, -25.8, 25.2, 25.6)
const SHAKE := 0.14
const SHAKE_RATE := 42.0
const HEAD_MOVE_RATE := 9.0
const FIST_REST_Y := 7.2
const FIST_RAISED_Y := 11.2
const HAT_LAUNCH := 7.0
const SPIN_RATE := 9.0
const MOUSTACHE_SAG := 0.33
const MOUSTACHE_Y := -0.42
const MOUSTACHE_Z := 1.28
## Far enough forward on his chest that the neck clears the lip of the bench when he droops.
const NECK_ANCHOR := Vector3(0.0, 9.6, -27.4)
const NECK_RINGS := 12
## How far his body drops onto the bench, from where it stands.
const COLLAPSE_DROP := -2.2
const HEAD_HEAP := Vector3(2.2, 7.3, -27.8)
const HAT_CROOKED := 0.35

## The weak spot, as a bolt sees it. In the target group only while exposed.
class WeakSpot:
	extends Node3D

	var boss: BaronRust

	func aim_point() -> Vector3:
		return global_position

	func bolt_bounds() -> AABB:
		var size := boss.weak_spot_size()
		return AABB(global_position - size * 0.5, size)

	func aim_score_scale() -> float:
		return 0.5

	func bolt_hit() -> void:
		boss.take_bolt()


var state: State = State.ATTACK
var rules: BossRules
var hazards: BossHazards
## Dentures currently loose in the arena.
var teeth: Array[ChatteringTeeth] = []

var _level: Level
var _tock: Player
var _tuning: Tuning
var _taunts: Dictionary = {}
var _has_drooped := false
var _moustache_left: Node3D
var _moustache_right: Node3D
var _weak_spot: WeakSpot
var _state_left := 0.0
var _phase := 0
var _sequence_index := 0
var _attack: Attack = Attack.SLAM
var _step: Step = Step.TELL
var _step_left := 0.0
var _throws_left := 0
var _reduced_motion := false
var _key_pos := Vector3.ZERO
var _key_area := Vector3.ZERO
var _denture_markers: Array[MeshInstance3D] = []
var _dentures_in_flight := false
var _shake_time := 0.0
var _droop_goal := 0.0
var _droop := 0.0
var _windows := [0.0, 0.0, 0.0]
var _slam_tells := [0.0, 0.0, 0.0]
var _droop_seconds := 0.0
var _raise_seconds := 0.0
var _break_seconds := 0.0
var _grace_seconds := 0.0
var _defeat_seconds := 0.0
var _recover_slam := 0.0
var _lob_windup := 0.0
var _lob_gap := 0.0
var _lob_flight := 0.0
var _lob_lead_p3 := 0.0
var _denture_tell := 0.0
var _denture_flight := 0.0
var _denture_recover := 0.0
var _sweep_tell := 0.0
var _stomp_damage := 0
var _bolt_damage := 0
var _stomp_margin := 0.0
var _base_y := 0.0
var _spot_size := Vector3.ONE
var _score_stomp := 0
var _score_bolt := 0
var _score_defeat := 0
var _head: Node3D
var _hat: Node3D
var _neck: Node3D
var _torso: Node3D
var _handle: Node3D
var _left_fist: Node3D
var _right_fist: Node3D
var _fist_raise := 0.0


## Call before adding to the tree. taunts holds the lines from the level file.
func setup(tuning: Tuning, level: Level, tock: Player, key_pos: Vector3, key_area: Vector3, taunts: Dictionary) -> void:
	_taunts = taunts
	_tuning = tuning
	_level = level
	_tock = tock
	_key_pos = key_pos
	_key_area = key_area
	rules = BossRules.new(int(tuning.num("boss", "hp")), int(tuning.num("boss", "window_cap")))
	_windows = [tuning.num("boss", "window_p1"), tuning.num("boss", "window_p2"), tuning.num("boss", "window_p3")]
	_slam_tells = [tuning.num("boss", "slam_p1"), tuning.num("boss", "slam_p2"), tuning.num("boss", "slam_p3")]
	_droop_seconds = tuning.num("boss", "droop")
	_raise_seconds = tuning.num("boss", "raise")
	_break_seconds = tuning.num("boss", "phase_break")
	_grace_seconds = tuning.num("boss", "retry_grace")
	_defeat_seconds = tuning.num("boss", "defeat_seconds")
	_recover_slam = tuning.num("boss", "slam_recover")
	_lob_windup = tuning.num("boss", "lob_windup")
	_lob_gap = tuning.num("boss", "lob_gap")
	_lob_flight = tuning.num("boss", "lob_flight")
	_lob_lead_p3 = tuning.num("boss", "lob_lead_p3")
	_denture_tell = tuning.num("boss", "denture_tell")
	_denture_flight = tuning.num("boss", "denture_flight")
	_denture_recover = tuning.num("boss", "denture_recover")
	_sweep_tell = tuning.num("boss", "sweep_tell")
	_stomp_damage = int(tuning.num("boss", "stomp_damage"))
	_bolt_damage = int(tuning.num("boss", "bolt_damage"))
	_stomp_margin = tuning.num("enemy", "stomp_margin")
	_base_y = tuning.num("boss", "weak_spot_base_y")
	var spot_width := tuning.num("boss", "weak_spot_width")
	_spot_size = Vector3(spot_width, tuning.num("boss", "weak_spot_height"), spot_width)
	_score_stomp = int(tuning.num("score", "boss_stomp"))
	_score_bolt = int(tuning.num("score", "boss_bolt"))
	_score_defeat = int(tuning.num("score", "boss_defeat"))
	hazards = BossHazards.new()
	hazards.setup(tuning, tock, ARENA, RING_ORIGIN)
	hazards.sound_requested.connect(sound_requested.emit)
	add_child(hazards)
	_weak_spot = WeakSpot.new()
	_weak_spot.boss = self
	_weak_spot.position = WEAK_SPOT
	add_child(_weak_spot)
	for _i in DENTURE_LANDINGS.size():
		_denture_markers.append(BossHazards.make_marker(self))
	_build_model()
	_begin_phase_attacks()


func _ready() -> void:
	hp_changed.emit(rules.hp, rules.max_hp)


## Size of the weak spot's box, for bolts.
func weak_spot_size() -> Vector3:
	return _spot_size


## True while the head can be damaged.
func is_exposed() -> bool:
	return state == State.EXPOSED


## The phase in progress, from 0.
func phase() -> int:
	return _phase


## Turns the rattling off, for players who asked for less motion. Timing is unchanged.
func set_reduced_motion(reduced: bool) -> void:
	_reduced_motion = reduced


## A bolt reached the exposed head.
func take_bolt() -> void:
	if state == State.EXPOSED:
		_deal(_bolt_damage, _score_bolt)


## Removes the live hazards the moment Tock dies, so nothing lands on an empty arena.
func on_tock_died() -> void:
	if state == State.DEFEAT or state == State.DONE:
		return
	_clear_arena()


## Tock is back: same phase, health at the phase's start, a moment for the Baron to laugh.
func on_tock_respawned() -> void:
	if state == State.DEFEAT or state == State.DONE:
		return
	_clear_arena()
	rules.restart_phase(_phase)
	hp_changed.emit(rules.hp, rules.max_hp)
	_enter(State.GRACE, _grace_seconds)
	sound_requested.emit("boss_grumble")
	_taunt("retry")


func _physics_process(delta: float) -> void:
	_animate(delta)
	if state == State.DONE:
		return
	if state != State.DEFEAT and not (_tock.alive and _tock.controls_enabled):
		return
	match state:
		State.ATTACK:
			_tick_attack(delta)
		State.DROOP:
			_tick_timer(delta, _open_window)
		State.EXPOSED:
			_check_stomp()
			if state == State.EXPOSED:
				_tick_timer(delta, _close_window)
		State.RAISE:
			_tick_timer(delta, _begin_phase_attacks)
		State.BREAK:
			_tick_timer(delta, _begin_phase_attacks)
		State.GRACE:
			_tick_timer(delta, _begin_phase_attacks)
		State.DEFEAT:
			_tick_timer(delta, _finish_defeat)


func _tick_timer(delta: float, on_done: Callable) -> void:
	_state_left -= delta
	if _state_left <= 0.0:
		on_done.call()


func _enter(next: State, seconds: float) -> void:
	if next in TRANSITIONS[state]:
		state = next
		_state_left = seconds
	else:
		push_error("BaronRust: no transition from %d to %d" % [state, next])


func _begin_phase_attacks() -> void:
	var previous_phase := _phase
	_phase = rules.phase()
	_sequence_index = 0
	if state != State.ATTACK:
		_enter(State.ATTACK, 0.0)
	_droop_goal = 0.0
	if _phase != previous_phase:
		_taunt("phase_%d" % (_phase + 1))
	_begin_attack()


func _taunt(key: String) -> void:
	if _taunts.has(key):
		taunted.emit(_taunts[key])


func _begin_attack() -> void:
	_attack = SEQUENCES[_phase][_sequence_index]
	_step = Step.TELL
	_fist_raise = 0.0
	match _attack:
		Attack.SLAM:
			_step_left = _slam_tells[_phase]
			_fist_raise = 1.0
			sound_requested.emit("boss_grumble")
		Attack.LOB:
			_step_left = _lob_windup
			_throws_left = LOB_THROWS
			_fist_raise = 1.0
		Attack.DENTURE:
			# Skipped when both sets are still chattering about.
			_prune_teeth()
			if teeth.size() >= DENTURE_LANDINGS.size():
				_next_attack()
				return
			_step_left = _denture_tell
			sound_requested.emit("teeth_chatter")
		Attack.SWEEP:
			_step_left = _sweep_tell
			hazards.start_sweep()
			sound_requested.emit("boss_ratchet")


func _tick_attack(delta: float) -> void:
	_step_left -= delta
	match _attack:
		Attack.SLAM:
			_tick_slam()
		Attack.LOB:
			_tick_lob()
		Attack.DENTURE:
			_tick_denture()
		Attack.SWEEP:
			_tick_sweep()


func _tick_slam() -> void:
	if _step_left > 0.0:
		return
	if _step == Step.TELL:
		_step = Step.RECOVER
		_step_left = _recover_slam
		_fist_raise = 0.0
		hazards.start_ring()
		sound_requested.emit("boss_slam")
	else:
		_next_attack()


func _tick_lob() -> void:
	if _step_left > 0.0:
		return
	if _throws_left > 0:
		_throw_wrench()
		_throws_left -= 1
		# Three throws a gap apart, then the last wrench's flight before the next attack.
		_step_left = _lob_gap if _throws_left > 0 else _lob_gap + _lob_flight
		_fist_raise = 0.0
		return
	_next_attack()


func _throw_wrench() -> void:
	var target := _tock.global_position
	target.y = 0.0
	if _phase == SEQUENCES.size() - 1:
		target += Vector3(_tock.velocity.x, 0.0, _tock.velocity.z) * _lob_lead_p3
		target.x = clampf(target.x, ARENA.position.x, ARENA.end.x)
		target.z = clampf(target.z, ARENA.position.y, ARENA.end.y)
	hazards.throw_lob(HAND_FROM, target)


func _tick_denture() -> void:
	if _step_left > 0.0:
		return
	if _step == Step.TELL:
		_step = Step.ACTIVE
		_step_left = _denture_flight
		_dentures_in_flight = true
		sound_requested.emit("boss_spit")
		for i in _denture_markers.size():
			if not _landing_occupied(i):
				_denture_markers[i].global_position = DENTURE_LANDINGS[i] + Vector3.UP * BossHazards.MARKER_LIFT
				_denture_markers[i].scale = Vector3.ONE * 1.2
				_denture_markers[i].visible = true
	elif _step == Step.ACTIVE:
		_land_dentures()
		_step = Step.RECOVER
		_step_left = _denture_recover
	else:
		_next_attack()


func _land_dentures() -> void:
	_dentures_in_flight = false
	for i in _denture_markers.size():
		if _denture_markers[i].visible:
			_denture_markers[i].visible = false
			var entry := {"pos": [DENTURE_LANDINGS[i].x, DENTURE_LANDINGS[i].y, DENTURE_LANDINGS[i].z]}
			var set_of_teeth := _level.add_teeth(entry)
			teeth.append(set_of_teeth)


func _landing_occupied(index: int) -> bool:
	if teeth.size() <= index:
		return false
	return is_instance_valid(teeth[index]) and not teeth[index].defeated


func _tick_sweep() -> void:
	if not hazards.sweep_active:
		_next_attack()


func _next_attack() -> void:
	_sequence_index += 1
	var sequence: Array = SEQUENCES[_phase]
	if _sequence_index < sequence.size():
		_begin_attack()
		return
	_enter(State.DROOP, _droop_seconds)
	_droop_goal = 1.0
	sound_requested.emit("boss_droop")
	if not _has_drooped:
		_has_drooped = true
		_taunt("droop")


func _open_window() -> void:
	_enter(State.EXPOSED, _windows[_phase])
	rules.open_window()
	_weak_spot.add_to_group(BoltBlaster.TARGET_GROUP)


func _close_window() -> void:
	_weak_spot.remove_from_group(BoltBlaster.TARGET_GROUP)
	_droop_goal = 0.0
	_enter(State.RAISE, _raise_seconds)
	sound_requested.emit("boss_grumble")


## A stomp needs Tock over the spot, falling, with his feet above the base plus the margin.
func _check_stomp() -> void:
	if not _tock.alive:
		return
	var bounds := _tock.contact_bounds()
	var spot := AABB(_weak_spot.global_position - _spot_size * 0.5, _spot_size)
	if not bounds.intersects(spot):
		return
	if StompRules.is_stomp(bounds.position.y, _tock.fall_velocity_y, _base_y, _stomp_margin):
		_tock.bounce()
		_deal(_stomp_damage, _score_stomp)


func _deal(damage: int, points: int) -> void:
	var dealt := rules.hit(damage)
	if dealt <= 0:
		return
	scored.emit(points, "boss_hit")
	hp_changed.emit(rules.hp, rules.max_hp)
	if rules.is_defeated():
		_begin_defeat()
	elif rules.at_phase_boundary():
		_begin_phase_break()
	elif rules.window_spent():
		_close_window()


func _begin_phase_break() -> void:
	_weak_spot.remove_from_group(BoltBlaster.TARGET_GROUP)
	_droop_goal = 0.0
	_clear_arena()
	_level.rearm_boxes()
	_enter(State.BREAK, _break_seconds)
	sound_requested.emit("boss_phase")


func _begin_defeat() -> void:
	_weak_spot.remove_from_group(BoltBlaster.TARGET_GROUP)
	_clear_arena()
	_enter(State.DEFEAT, _defeat_seconds)
	scored.emit(_score_defeat, "boss_down")
	defeated.emit()
	_taunt("defeat")
	# The hat goes first, then the heap, per the spec's defeat timeline.
	var tween := create_tween()
	var hat_rest := _hat.position.y
	tween.tween_property(_hat, "position:y", hat_rest + HAT_LAUNCH, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(_hat, "rotation:z", TAU * 2.0 + HAT_CROOKED, 2.4)
	tween.tween_property(_hat, "position:y", hat_rest, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	var heap := create_tween()
	heap.tween_interval(2.5)
	heap.tween_property(_torso, "position:y", COLLAPSE_DROP, 1.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	heap.parallel().tween_property(_head, "position", HEAD_HEAP, 1.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	heap.tween_callback(_neck.hide)


func _finish_defeat() -> void:
	_enter(State.DONE, 0.0)
	_level.add_goal(_key_pos, _key_area)


func _clear_arena() -> void:
	hazards.clear_all()
	_dentures_in_flight = false
	for marker in _denture_markers:
		marker.visible = false
	for set_of_teeth in teeth:
		if is_instance_valid(set_of_teeth):
			set_of_teeth.queue_free()
	teeth.clear()


func _prune_teeth() -> void:
	var alive: Array[ChatteringTeeth] = []
	for set_of_teeth in teeth:
		if is_instance_valid(set_of_teeth) and not set_of_teeth.defeated:
			alive.append(set_of_teeth)
	teeth = alive


func _animate(delta: float) -> void:
	var rate := clampf(HEAD_MOVE_RATE * delta, 0.0, 1.0)
	_droop = lerpf(_droop, _droop_goal, rate)
	var goal_y := lerpf(FIST_REST_Y, FIST_RAISED_Y, _fist_raise)
	_left_fist.position.y = lerpf(_left_fist.position.y, goal_y, rate)
	_right_fist.position.y = _left_fist.position.y
	if state == State.DEFEAT or state == State.DONE:
		_shake(delta)
		return
	_head.position = HEAD_HIGH.lerp(WEAK_SPOT, _droop)
	_stretch_neck()
	# The hat tips up like a lid while his head hangs low.
	_hat.rotation.x = -0.7 * _droop
	# Each phase takes a little more of the wind out of his moustache.
	var sag := MOUSTACHE_SAG * _phase
	_moustache_left.rotation.z = lerpf(_moustache_left.rotation.z, sag, rate)
	_moustache_right.rotation.z = -_moustache_left.rotation.z
	if state == State.BREAK:
		_handle.rotation.x += SPIN_RATE * delta
	if _phase == SEQUENCES.size() - 1:
		_shake(delta * 0.5)


func _shake(delta: float) -> void:
	if _reduced_motion or state == State.DONE:
		return
	_shake_time += delta
	_torso.position.x = sin(_shake_time * SHAKE_RATE) * SHAKE


func _stretch_neck() -> void:
	var from := _neck.position
	var to := _head.position
	var gap := to - from
	_neck.scale = Vector3(1.0, maxf(gap.length(), 0.1), 1.0)
	if gap.length_squared() > 0.001:
		var up := gap.normalized()
		var side := up.cross(Vector3.BACK)
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT
		side = side.normalized()
		_neck.basis = Basis(side, up, side.cross(up)).scaled_local(_neck.scale)


## Parts per the spec: at most 12 parts, 14 draws and 2 shadows. Colors are from visual_look.json.
func _build_model() -> void:
	var casting := MeshBatch.new()
	casting.add_box(Vector3(0.0, 6.6, -30.0), Vector3(16.0, 1.2, 7.0))
	casting.add_box(Vector3(-7.0, 9.0, -27.6), Vector3(2.0, 4.6, 1.6))
	casting.add_box(Vector3(7.0, 9.0, -27.6), Vector3(2.0, 4.6, 1.6))
	casting.add_box(Vector3(-7.0, 9.0, -32.2), Vector3(2.0, 4.6, 1.6))
	casting.add_box(Vector3(7.0, 9.0, -32.2), Vector3(2.0, 4.6, 1.6))
	MeshKit.part(self, casting.commit(), "boss_casting", Vector3.ZERO, true)
	_handle = Node3D.new()
	_handle.position = Vector3(10.2, 8.2, -30.0)
	add_child(_handle)
	var handle := MeshBatch.new()
	handle.add_bar(Vector3(-2.2, 0.0, 0.0), Vector3(1.2, 0.0, 0.0), 0.3, Color.WHITE, 8)
	handle.add_bar(Vector3(1.2, -2.2, 0.0), Vector3(1.2, 2.2, 0.0), 0.2, Color.WHITE, 8)
	MeshKit.part(_handle, handle.commit(), "steel_trim", Vector3.ZERO, false)
	_torso = Node3D.new()
	add_child(_torso)
	MeshKit.part(_torso, MeshKit.cylinder(2.3, 2.7, 3.0, 16), "boss_rust", Vector3(0.0, 8.5, -30.0), true)
	_neck = Node3D.new()
	_neck.position = NECK_ANCHOR
	add_child(_neck)
	# Thin rings, because the neck stretches in y: at full stretch they still read as a coil.
	var coil := MeshBatch.new()
	for i in NECK_RINGS:
		var ring_at := Vector3(0.0, (i + 0.5) / NECK_RINGS, 0.0)
		coil.add_mesh(MeshKit.torus(0.5, 0.6), Transform3D(Basis.IDENTITY, ring_at))
	MeshKit.part(_neck, coil.commit(), "boss_spring", Vector3.ZERO, false)
	_head = Node3D.new()
	_head.position = HEAD_HIGH
	add_child(_head)
	var skull := SphereMesh.new()
	skull.radius = 1.3
	skull.height = 2.0
	skull.radial_segments = 16
	skull.rings = 8
	var skull_part := MeshKit.part(_head, skull, "boss_rust", Vector3.ZERO, false)
	skull_part.scale = Vector3(1.2, 1.15, 1.0)
	# Two halves pivoting at the nose, so the moustache can lose heart as the fight goes on.
	_moustache_left = _build_moustache_half(-1.0)
	_moustache_right = _build_moustache_half(1.0)
	var eyes := MeshBatch.new()
	for side: float in [-1.0, 1.0]:
		eyes.add_mesh(MeshKit.sphere(0.24, 8), Transform3D(Basis.IDENTITY, Vector3(side * 0.62, 0.22, 1.2)))
	MeshKit.part(_head, eyes.commit(), "beetle_eyes", Vector3.ZERO, false)
	var monocle := MeshKit.torus(0.32, 0.44)
	var monocle_part := MeshKit.part(_head, monocle, "checkpoint_base", Vector3(0.62, 0.22, 1.32), false)
	monocle_part.rotation.x = PI / 2.0
	_hat = Node3D.new()
	_hat.position = Vector3(0.0, 1.12, 0.0)
	_head.add_child(_hat)
	var hat := MeshBatch.new()
	hat.add_mesh(MeshKit.cylinder(0.72, 0.72, 0.1, 12))
	hat.add_mesh(MeshKit.cylinder(0.46, 0.46, 0.75, 12), Transform3D(Basis.IDENTITY, Vector3.UP * 0.42))
	MeshKit.part(_hat, hat.commit(), "boss_dark", Vector3.ZERO, false)
	_left_fist = _build_arm(-1.0)
	_right_fist = _build_arm(1.0)


func _build_moustache_half(side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, MOUSTACHE_Y, MOUSTACHE_Z)
	_head.add_child(pivot)
	var half := MeshBatch.new()
	half.add_box(Vector3(side * 0.7, 0.0, 0.0), Vector3(1.4, 0.26, 0.26))
	half.add_box(Vector3(side * 1.45, 0.1, -0.04), Vector3(0.36, 0.2, 0.22))
	MeshKit.part(pivot, half.commit(), "boss_dark", Vector3.ZERO, false)
	return pivot


func _build_arm(side: float) -> Node3D:
	var fist := Node3D.new()
	fist.position = Vector3(side * 4.0, FIST_REST_Y, -27.6)
	add_child(fist)
	var parts := MeshBatch.new()
	parts.add_mesh(MeshKit.sphere(0.8, 10))
	parts.add_bar(Vector3.ZERO, Vector3(-side * 1.8, 1.4, -2.2), 0.32, Color.WHITE, 8)
	MeshKit.part(fist, parts.commit(), "steel_trim", Vector3.ZERO, false)
	return fist
