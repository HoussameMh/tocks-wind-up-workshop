class_name ArmoredBeetle
extends GearBeetle
## A gear beetle wearing a saucepan lid. Implements design/expansion-spec.md section 4.
##
## States: ARMORED -> (stomp) PANIC -> (panic_seconds) NORMAL -> (stomp) squash. A stomp in PANIC
## also squashes. Any bolt ends it from any state. No attack, so no telegraph beyond its patrol.
##
## For stomp_immunity seconds after the lid comes off, contact does nothing at all. The spec names
## only stomps, but Tock is still inside the hit box and rising on his bounce, which would
## otherwise read as a side hit and hurt him on the very stomp that earned the bounce.

enum State { ARMORED, PANIC, NORMAL }

const TRANSITIONS := {
	State.ARMORED: [State.PANIC],
	State.PANIC: [State.NORMAL],
	State.NORMAL: [],
}
const LID_ROLL_DISTANCE := 5.0
const LID_ROLL_SECONDS := 0.9
const PANIC_WOBBLE_RATE := 26.0
const PANIC_WOBBLE := 0.22

static var _lid_mesh: ArrayMesh

var state: State = State.ARMORED

var _panic_seconds := 0.0
var _panic_speed_scale := 1.0
var _stomp_immunity := 0.0
var _score_stomp_1 := 0
var _score_stomp_2 := 0
var _score_bolt_armored := 0
var _panic_left := 0.0
var _immune_left := 0.0
var _lid: MeshInstance3D


## Call before adding to the tree. y in a and b is floor height.
func setup(a: Vector3, b: Vector3, patrol_speed: float, tuning: Tuning) -> void:
	_panic_seconds = tuning.num("armored", "panic_seconds")
	_panic_speed_scale = tuning.num("armored", "panic_speed_scale")
	_stomp_immunity = tuning.num("armored", "stomp_immunity")
	_score_stomp_1 = int(tuning.num("score", "armor_stomp_1"))
	_score_stomp_2 = int(tuning.num("score", "armor_stomp_2"))
	_score_bolt_armored = int(tuning.num("score", "bolt_armored"))
	super.setup(a, b, patrol_speed, tuning)
	_gear.visible = false
	_lid = MeshKit.part(_body, _get_lid_mesh(), "beetle_gear", Vector3(0.0, 0.74, 0.0), false)
	_cull_all_parts()


## True while the lid is still on.
func has_lid() -> bool:
	return state == State.ARMORED


func _enemy_tick(delta: float) -> void:
	super._enemy_tick(delta)
	_immune_left = maxf(_immune_left - delta, 0.0)
	if state == State.PANIC:
		_panic_left -= delta
		_body.rotation.z = sin(_panic_left * PANIC_WOBBLE_RATE) * PANIC_WOBBLE
		if _panic_left <= 0.0:
			_body.rotation.z = 0.0
			_speed_scale = 1.0
			_change_state(State.NORMAL)


func _resolve_contact(player: Player) -> void:
	if _immune_left > 0.0:
		return
	super._resolve_contact(player)


func _on_stomped(player: Player) -> void:
	if state == State.ARMORED:
		player.bounce()
		_change_state(State.PANIC)
		_immune_left = _stomp_immunity
		_panic_left = _panic_seconds
		_speed_scale = _panic_speed_scale
		_throw_lid()
		scored.emit(_score_stomp_1, "armor_clang")
		return
	_squash(player)
	scored.emit(_score_stomp_2, "stomp")


func _on_bolted() -> void:
	var points := _score_bolt_armored if has_lid() else _bolt_score
	_defeat()
	scored.emit(points, "bolt_hit")
	_play_knockout()


func _change_state(next: State) -> void:
	if _table_allows(TRANSITIONS, state, next):
		state = next


## The lid clangs off and rolls away on its rim while the beetle sprints around in embarrassment.
func _throw_lid() -> void:
	_gear.visible = true
	var start := _lid.global_position
	_lid.top_level = true
	_lid.global_position = start
	var away := Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_lid, "global_position", start + away * LID_ROLL_DISTANCE + Vector3.DOWN * 0.3, LID_ROLL_SECONDS)
	tween.tween_property(_lid, "rotation:z", PI / 2.0, 0.15)
	tween.tween_property(_lid, "rotation:x", TAU * 3.0, LID_ROLL_SECONDS)
	tween.chain().tween_callback(_lid.hide)


static func _get_lid_mesh() -> ArrayMesh:
	if _lid_mesh != null:
		return _lid_mesh
	var dome := SphereMesh.new()
	dome.radius = 0.68
	dome.height = 0.34
	dome.is_hemisphere = true
	dome.radial_segments = 16
	dome.rings = 5
	var batch := MeshBatch.new()
	batch.add_mesh(dome)
	batch.add_mesh(MeshKit.cylinder(0.72, 0.72, 0.05, 16), Transform3D(Basis.IDENTITY, Vector3.UP * 0.02))
	batch.add_mesh(MeshKit.cylinder(0.05, 0.05, 0.1, 8), Transform3D(Basis.IDENTITY, Vector3.UP * 0.38))
	batch.add_mesh(MeshKit.sphere(0.11, 10), Transform3D(Basis.IDENTITY, Vector3.UP * 0.47))
	_lid_mesh = batch.commit()
	return _lid_mesh
