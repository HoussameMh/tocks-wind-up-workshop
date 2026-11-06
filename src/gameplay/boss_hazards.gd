class_name BossHazards
extends Node3D
## Everything Baron Rust throws at Tock: bench-slam rings, lobbed wrenches and the rust sweep.
## Preallocated, unshadowed and checked by simple math rather than physics, so a hazard can appear
## or vanish mid-tick. Implements the attack table in design/expansion-spec.md section 6.
##
## Usage:
##   hazards.setup(tuning, tock, arena_rect)
##   hazards.start_ring(1.0)   # from BaronRust
##   hazards.clear_all()

signal sound_requested(sound: String)

const RING_SEGMENTS := 48
const RING_MAX := 2
const LOB_MAX := 3
const LOB_ARC_HEIGHT := 5.0
const SWEEP_RISE_FROM := -1.0
const STOMP_MARGIN := 0.35
const MARKER_LIFT := 0.04
const MARKER_ALPHA := 0.55
const MARKER_COLOR := Color("ff7a1a")


## One bench-slam shockwave: a low wall growing from the Baron, clipped to the arena.
class Ring:
	extends MeshInstance3D

	var active := false
	var radius := 0.0
	var _immediate := ImmediateMesh.new()

	func _init() -> void:
		mesh = _immediate
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visible = false

	## Rebuilds the band for the current radius, as one draw. Any part past the arena's edge flattens
	## to nothing on the floor, so the ring leaves through a wall instead of sticking to it.
	func redraw(origin: Vector3, half_width: float, height: float, low: Vector2, high: Vector2, material: Material) -> void:
		_immediate.clear_surfaces()
		_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
		var center := Vector2(origin.x, origin.z)
		for i in RING_SEGMENTS + 1:
			var angle := TAU * i / RING_SEGMENTS
			var along := Vector2(sin(angle), cos(angle))
			var inner_at := center + along * maxf(radius - half_width, 0.0)
			var inner := inner_at.clamp(low, high)
			var outer := (center + along * (radius + half_width)).clamp(low, high)
			var top := height if inner_at == inner else 0.0
			_immediate.surface_add_vertex(Vector3(inner.x, top, inner.y))
			_immediate.surface_add_vertex(Vector3(outer.x, top, outer.y))
		# Down the outer wall, joined to the top with a repeated vertex rather than a second draw.
		for i in RING_SEGMENTS + 1:
			var angle := TAU * i / RING_SEGMENTS
			var along := Vector2(sin(angle), cos(angle))
			var outer_at := center + along * (radius + half_width)
			var outer := outer_at.clamp(low, high)
			var top := height if outer_at == outer else 0.0
			var upper := Vector3(outer.x, top, outer.y)
			if i == 0:
				_immediate.surface_add_vertex(upper)
			_immediate.surface_add_vertex(upper)
			_immediate.surface_add_vertex(Vector3(outer.x, 0.0, outer.y))
		_immediate.surface_end()


## One thrown wrench, with the marker that shows where it will land.
class Lob:
	extends RefCounted

	var active := false
	var landed := false
	var from := Vector3.ZERO
	var target := Vector3.ZERO
	var elapsed := 0.0
	var wrench: MeshInstance3D
	var marker: MeshInstance3D


static var _marker_mesh: ArrayMesh
static var _wrench_mesh: ArrayMesh

## Spent slam rings and thrown wrenches cost no draws, so tests can read what is live.
var sweep_active := false
var sweep_x := 0.0

var _tock: Player
var _rings: Array[Ring] = []
var _lobs: Array[Lob] = []
var _sweep: MeshInstance3D
var _sweep_direction := 1.0
var _sweep_side := -1.0
var _sweep_telling := 0.0
var _ring_material: Material
var _low := Vector2.ZERO
var _high := Vector2.ZERO
var _center_z := 0.0
var _length_z := 0.0
var _ring_origin := Vector3.ZERO
var _ring_speed := 0.0
var _ring_radius := 0.0
var _ring_height := 0.0
var _ring_half_width := 0.0
var _lob_flight := 0.0
var _lob_radius := 0.0
var _lob_linger := 0.0
var _sweep_speed := 0.0
var _sweep_top := 0.0
var _sweep_half := 0.0
var _sweep_tell := 0.0


## Call before adding to the tree. arena is the walkable floor as x and z, from low to high.
func setup(tuning: Tuning, tock: Player, arena: Rect2, ring_origin: Vector3) -> void:
	_tock = tock
	_low = arena.position
	_high = arena.end
	_center_z = arena.get_center().y
	_length_z = arena.size.y
	_ring_origin = ring_origin
	_ring_speed = tuning.num("boss", "ring_speed")
	_ring_radius = tuning.num("boss", "ring_radius")
	_ring_height = tuning.num("boss", "ring_height")
	_ring_half_width = tuning.num("boss", "ring_half_width")
	_lob_flight = tuning.num("boss", "lob_flight")
	_lob_radius = tuning.num("boss", "lob_radius")
	_lob_linger = tuning.num("boss", "lob_linger")
	_sweep_speed = tuning.num("boss", "sweep_speed")
	_sweep_top = tuning.num("boss", "sweep_top")
	_sweep_half = tuning.num("boss", "sweep_width") * 0.5
	_sweep_tell = tuning.num("boss", "sweep_tell")
	_ring_material = Look.material("boss_hazard")
	for _i in RING_MAX:
		var ring := Ring.new()
		add_child(ring)
		_rings.append(ring)
	for _i in LOB_MAX:
		var lob := Lob.new()
		lob.wrench = MeshKit.part(self, _get_wrench_mesh(), "steel_trim", Vector3.ZERO, false)
		lob.wrench.top_level = true
		lob.wrench.visible = false
		lob.marker = make_marker(self)
		_lobs.append(lob)
	var bar := MeshBatch.new()
	bar.add_box(Vector3.ZERO, Vector3(_sweep_half * 2.0, _sweep_top - SWEEP_RISE_FROM, _length_z))
	_sweep = MeshKit.part(self, bar.commit(), "boss_rust", Vector3.ZERO, false)
	_sweep.top_level = true
	_sweep.visible = false


## Builds a flat warning disc, one unit in radius. Hidden until placed.
static func make_marker(parent: Node3D) -> MeshInstance3D:
	if _marker_mesh == null:
		var batch := MeshBatch.new()
		batch.add_soft_disc(Vector3.ZERO, Vector2.ONE, MARKER_ALPHA, MARKER_COLOR, 20)
		_marker_mesh = batch.commit()
	var marker := MeshKit.part(parent, _marker_mesh, "boss_marker", Vector3.ZERO, false)
	marker.top_level = true
	marker.visible = false
	return marker


## Sends a shockwave out from the Baron's bench. Ignored if the arena already holds the maximum.
func start_ring() -> void:
	for ring in _rings:
		if not ring.active:
			ring.active = true
			ring.radius = 0.0
			ring.visible = true
			return


## Throws a wrench at a floor point. Ignored if every wrench is in the air.
func throw_lob(from: Vector3, target: Vector3) -> void:
	for lob in _lobs:
		if not lob.active:
			lob.active = true
			lob.landed = false
			lob.from = from
			lob.target = target
			lob.elapsed = 0.0
			lob.wrench.global_position = from
			lob.wrench.visible = true
			lob.marker.global_position = target + Vector3.UP * MARKER_LIFT
			lob.marker.scale = Vector3.ONE * _lob_radius
			lob.marker.visible = true
			sound_requested.emit("boss_lob")
			return


## Raises the bar at the next rail, alternating sides. Over the tell it rises; then it crosses.
func start_sweep() -> void:
	_sweep_side = -_sweep_side
	_sweep_direction = -_sweep_side
	sweep_x = _high.x if _sweep_side > 0.0 else _low.x
	_sweep_telling = _sweep_tell
	sweep_active = true
	_place_sweep(0.0)
	_sweep.visible = true


## Shockwaves still travelling.
func rings_alive() -> int:
	var count := 0
	for ring in _rings:
		if ring.active:
			count += 1
	return count


## Radius of the first live shockwave, or -1. For tests and bots.
func ring_radius() -> float:
	for ring in _rings:
		if ring.active:
			return ring.radius
	return -1.0


## Wrenches in the air or just landed.
func lobs_alive() -> int:
	var count := 0
	for lob in _lobs:
		if lob.active:
			count += 1
	return count


## Removes every hazard at once, for a phase break, a death or the end of the fight.
func clear_all() -> void:
	for ring in _rings:
		ring.active = false
		ring.visible = false
	for lob in _lobs:
		lob.active = false
		lob.wrench.visible = false
		lob.marker.visible = false
	sweep_active = false
	_sweep.visible = false


func _physics_process(delta: float) -> void:
	for ring in _rings:
		if ring.active:
			_step_ring(ring, delta)
	for lob in _lobs:
		if lob.active:
			_step_lob(lob, delta)
	if sweep_active:
		_step_sweep(delta)


func _step_ring(ring: Ring, delta: float) -> void:
	ring.radius += _ring_speed * delta
	if ring.radius >= _ring_radius:
		ring.active = false
		ring.visible = false
		return
	ring.redraw(_ring_origin, _ring_half_width, _ring_height, _low, _high, _ring_material)
	if not _tock_exposed() or _tock.global_position.y >= _ring_origin.y + _ring_height:
		return
	var flat := Vector2(_tock.global_position.x - _ring_origin.x, _tock.global_position.z - _ring_origin.z)
	if absf(flat.length() - ring.radius) <= _ring_half_width:
		_tock.take_hit()


func _step_lob(lob: Lob, delta: float) -> void:
	lob.elapsed += delta
	if lob.landed:
		if lob.elapsed >= _lob_flight + _lob_linger:
			lob.active = false
			lob.wrench.visible = false
		return
	var ratio := clampf(lob.elapsed / _lob_flight, 0.0, 1.0)
	var arc := Vector3.UP * LOB_ARC_HEIGHT * sin(ratio * PI)
	lob.wrench.global_position = lob.from.lerp(lob.target, ratio) + arc
	lob.wrench.rotation.x += delta * TAU * 2.0
	if ratio < 1.0:
		return
	lob.landed = true
	lob.marker.visible = false
	lob.wrench.rotation = Vector3.ZERO
	sound_requested.emit("wrench_clank")
	if _tock_exposed() and _tock.global_position.distance_to(lob.target) <= _lob_radius:
		_tock.take_hit()


func _step_sweep(delta: float) -> void:
	if _sweep_telling > 0.0:
		_sweep_telling -= delta
		_place_sweep(1.0 - maxf(_sweep_telling, 0.0) / _sweep_tell)
		return
	sweep_x += _sweep_speed * _sweep_direction * delta
	_place_sweep(1.0)
	if sweep_x < _low.x or sweep_x > _high.x:
		sweep_active = false
		_sweep.visible = false
		return
	if _tock_exposed():
		_check_sweep_contact()


## Landing on the bar bounces Tock unhurt; anything else that touches it hurts.
func _check_sweep_contact() -> void:
	var bounds := _tock.contact_bounds()
	var feet := bounds.position.y
	var over_x := absf(_tock.global_position.x - sweep_x) <= _sweep_half + bounds.size.x * 0.5
	if not over_x or feet >= _sweep_top:
		return
	if _tock.fall_velocity_y < 0.0 and feet >= _sweep_top - STOMP_MARGIN:
		_tock.bounce()
	else:
		_tock.take_hit()


func _place_sweep(rise: float) -> void:
	var height := _sweep_top - SWEEP_RISE_FROM
	var top := lerpf(SWEEP_RISE_FROM, _sweep_top, rise)
	_sweep.global_position = Vector3(sweep_x, top - height * 0.5, _center_z)


func _tock_exposed() -> bool:
	return _tock != null and _tock.alive and _tock.controls_enabled


static func _get_wrench_mesh() -> ArrayMesh:
	if _wrench_mesh != null:
		return _wrench_mesh
	var batch := MeshBatch.new()
	batch.add_box(Vector3.ZERO, Vector3(0.28, 0.14, 1.5))
	for end: float in [-1.0, 1.0]:
		batch.add_box(Vector3(0.0, 0.0, end * 0.8), Vector3(0.7, 0.18, 0.22))
		for side: float in [-1.0, 1.0]:
			batch.add_box(Vector3(side * 0.28, 0.0, end * 1.05), Vector3(0.16, 0.18, 0.4))
	_wrench_mesh = batch.commit()
	return _wrench_mesh
