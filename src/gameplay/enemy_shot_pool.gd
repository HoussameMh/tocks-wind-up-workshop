class_name EnemyShotPool
extends Node3D
## Every eraser and bubble in the level, sharing one cap (design/expansion-spec.md section 1).
## Shots are preallocated and unshadowed, at one draw each. When acquire returns null the enemy
## skips its shot and enters cooldown. Contact is simple math rather than an Area3D, so
## acquiring and retiring a shot never touches physics state mid-tick.

signal scored(points: int, sound: String)
signal sound_requested(sound: String)


## One pooled eraser or bubble.
class Shot:
	extends MeshInstance3D

	enum Kind { ERASER, BUBBLE }
	enum Phase { FREE, HELD, FALLING, FLYING }

	const ERASER_SIZE := Vector3(0.9, 0.5, 0.5)

	var kind: Kind = Kind.ERASER
	var phase: Phase = Phase.FREE
	var velocity := Vector3.ZERO
	var radius := 0.0
	var travelled := 0.0

	var _pool: EnemyShotPool

	func _init(pool: EnemyShotPool) -> void:
		_pool = pool
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visible = false

	## True while falling, so a plane knows to keep its landing blob in place.
	func is_falling() -> bool:
		return phase == Phase.FALLING

	## Lets go of a held eraser.
	func drop() -> void:
		phase = Phase.FALLING
		velocity = Vector3.ZERO
		_pool.sound_requested.emit("eraser_fall")

	## Returns a held shot to the pool, for when its owner is knocked out first.
	func cancel() -> void:
		_pool.retire(self)

	## Bolt contract for bubbles, which are hit but never aimed at.
	func bolt_hit() -> void:
		_pool.sound_requested.emit("bubble_pop")
		_pool.retire(self)

	## Bolt contract for bubbles.
	func bolt_bounds() -> AABB:
		return AABB(global_position - Vector3.ONE * radius, Vector3.ONE * radius * 2.0)


static var _eraser_mesh: ArrayMesh
static var _bubble_mesh: SphereMesh

var _shots: Array[Shot] = []
var _player: Player
var _query: PhysicsRayQueryParameters3D
var _eraser_gravity := 0.0
var _bubble_speed := 0.0
var _bubble_range := 0.0
var _bubble_radius := 0.0
var _stomp_margin := 0.0
var _score_bubble_stomp := 0


## Call before adding to the tree.
func setup(tuning: Tuning) -> void:
	_eraser_gravity = tuning.num("plane", "eraser_gravity")
	_bubble_speed = tuning.num("duck", "bubble_speed")
	_bubble_range = tuning.num("duck", "bubble_range")
	_bubble_radius = tuning.num("duck", "bubble_radius")
	_stomp_margin = tuning.num("enemy", "stomp_margin")
	_score_bubble_stomp = int(tuning.num("score", "bubble_stomp"))
	_query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ONE, Player.LAYER_WORLD)
	var cull := tuning.num("limits", "enemy_cull_distance")
	for _i in int(tuning.num("limits", "max_enemy_shots")):
		var shot := Shot.new(self)
		shot.visibility_range_end = cull
		add_child(shot)
		_shots.append(shot)


## Tells the pool who shots can hit.
func bind_player(player: Player) -> void:
	_player = player


## Number of shots in use, held ones included.
func alive_count() -> int:
	var count := 0
	for shot in _shots:
		if shot.phase != Shot.Phase.FREE:
			count += 1
	return count


## Takes an eraser to hold under a plane. Returns null at the shared cap.
func acquire_eraser() -> Shot:
	var shot := _take()
	if shot == null:
		return null
	shot.kind = Shot.Kind.ERASER
	shot.phase = Shot.Phase.HELD
	shot.mesh = _get_eraser_mesh()
	shot.material_override = Look.material("enemy_paint")
	shot.visible = true
	return shot


## Fires a bubble straight at a point. Returns null at the shared cap.
func fire_bubble(from: Vector3, at: Vector3) -> Shot:
	var shot := _take()
	if shot == null:
		return null
	shot.kind = Shot.Kind.BUBBLE
	shot.phase = Shot.Phase.FLYING
	shot.radius = _bubble_radius
	shot.travelled = 0.0
	shot.velocity = (at - from).normalized() * _bubble_speed
	shot.mesh = _get_bubble_mesh()
	shot.material_override = Look.material("enemy_bubble")
	shot.scale = Vector3.ONE * _bubble_radius
	shot.position = from
	shot.visible = true
	shot.add_to_group(BoltBlaster.POPPABLE_GROUP)
	return shot


## Returns one shot to the pool.
func retire(shot: Shot) -> void:
	shot.phase = Shot.Phase.FREE
	shot.visible = false
	shot.scale = Vector3.ONE
	shot.rotation = Vector3.ZERO
	if shot.is_in_group(BoltBlaster.POPPABLE_GROUP):
		shot.remove_from_group(BoltBlaster.POPPABLE_GROUP)


## Removes every shot.
func clear_all() -> void:
	for shot in _shots:
		if shot.phase != Shot.Phase.FREE:
			retire(shot)


func _physics_process(delta: float) -> void:
	for shot in _shots:
		match shot.phase:
			Shot.Phase.FALLING:
				_step_eraser(shot, delta)
			Shot.Phase.FLYING:
				_step_bubble(shot, delta)


func _take() -> Shot:
	for shot in _shots:
		if shot.phase == Shot.Phase.FREE:
			return shot
	return null


func _step_eraser(shot: Shot, delta: float) -> void:
	shot.velocity.y -= _eraser_gravity * delta
	var from := shot.position
	var to := from + shot.velocity * delta
	# On landing it boings and is gone, harmless.
	if _ray_hits_world(from, to + Vector3.DOWN * Shot.ERASER_SIZE.y * 0.5):
		sound_requested.emit("eraser_boing")
		retire(shot)
		return
	shot.position = to
	if _can_hurt() and AABB(to - Shot.ERASER_SIZE * 0.5, Shot.ERASER_SIZE).intersects(_player.contact_bounds()):
		_player.take_hit()
		sound_requested.emit("eraser_boing")
		retire(shot)


func _step_bubble(shot: Shot, delta: float) -> void:
	var from := shot.position
	var to := from + shot.velocity * delta
	if _ray_hits_world(from, to):
		sound_requested.emit("bubble_pop")
		retire(shot)
		return
	shot.position = to
	shot.travelled += _bubble_speed * delta
	if shot.travelled >= _bubble_range:
		sound_requested.emit("bubble_pop")
		retire(shot)
		return
	if _can_hurt() and _bubble_touches_player(to, shot.radius):
		_resolve_bubble_contact(shot)


func _resolve_bubble_contact(shot: Shot) -> void:
	var base_y := shot.position.y - shot.radius
	if StompRules.is_stomp(_player.global_position.y, _player.fall_velocity_y, base_y, _stomp_margin):
		_player.bounce()
		scored.emit(_score_bubble_stomp, "bubble_pop")
	else:
		_player.take_hit()
		sound_requested.emit("bubble_pop")
	retire(shot)


## False during invulnerability, so a shot passes through a blinking Tock instead of vanishing.
func _can_hurt() -> bool:
	return _player != null and _player.alive and _player.controls_enabled and not _player.is_invulnerable()


func _bubble_touches_player(center: Vector3, radius: float) -> bool:
	var bounds := _player.contact_bounds()
	var nearest := center.clamp(bounds.position, bounds.end)
	return nearest.distance_squared_to(center) <= radius * radius


func _ray_hits_world(from: Vector3, to: Vector3) -> bool:
	_query.from = from
	_query.to = to
	return not get_world_3d().direct_space_state.intersect_ray(_query).is_empty()


static func _get_eraser_mesh() -> ArrayMesh:
	if _eraser_mesh != null:
		return _eraser_mesh
	var size := Shot.ERASER_SIZE
	var batch := MeshBatch.new()
	batch.add_box(Vector3(-size.x * 0.2, 0.0, 0.0), Vector3(size.x * 0.6, size.y, size.z), 0.0, Vector2.ZERO, Color("e87d94"))
	batch.add_box(Vector3(size.x * 0.3, 0.0, 0.0), Vector3(size.x * 0.4, size.y, size.z), 0.0, Vector2.ZERO, Color("6f9ad8"))
	_eraser_mesh = batch.commit()
	return _eraser_mesh


static func _get_bubble_mesh() -> SphereMesh:
	if _bubble_mesh == null:
		_bubble_mesh = MeshKit.sphere(1.0, 14)
	return _bubble_mesh
