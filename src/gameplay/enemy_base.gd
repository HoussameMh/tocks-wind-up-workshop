class_name EnemyBase
extends Area3D
## What every enemy shares, per design/expansion-spec.md section 4: contact checked each physics
## tick while touching, StompRules against the enemy's base y, the bolt target contract, and score
## reported by signal. A subclass supplies _enemy_tick, _on_stomped and _on_bolted.
## The root never rotates, so the hit box stays world-aligned; only the model turns.

signal scored(points: int, sound: String)
signal sound_requested(sound: String)

## True from the moment of a knockout, while the comic exit plays.
var defeated := false
## Who to look for. Null until Level.bind_player; enemies stay idle without it.
var tock: Player
## The shared eraser and bubble pool, given by Level.
var shots: EnemyShotPool
## Contact does nothing for this many seconds, such as while landing on Tock.
var contact_immune_left := 0.0

var _stomp_margin := 0.0
var _touching: Player
var _hit_size := Vector3.ONE
var _cull_distance := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if defeated:
		return
	contact_immune_left = maxf(contact_immune_left - delta, 0.0)
	_enemy_tick(delta)
	if _touching != null and not defeated and contact_immune_left <= 0.0:
		_resolve_contact(_touching)


## Takes this enemy out of play at once, with no exit and no score. It cannot touch Tock even in the
## tick before it is freed.
func remove_now() -> void:
	_defeat()
	queue_free()


## Bolt contract: where a bolt flies to.
func aim_point() -> Vector3:
	return global_position + Vector3.UP * _hit_size.y * 0.5


## Bolt contract: the world-space box a bolt can strike.
func bolt_bounds() -> AABB:
	var half := Vector3(_hit_size.x * 0.5, 0.0, _hit_size.z * 0.5)
	return AABB(global_position - half, _hit_size)


## Bolt contract: one bolt knocks out any enemy.
func bolt_hit() -> void:
	if not defeated:
		_on_bolted()


## Call from a subclass's setup, before adding to the tree. y in at is floor height or rail height.
func _setup_base(tuning: Tuning, at: Vector3, hit_size: Vector3) -> void:
	position = at
	_hit_size = hit_size
	_stomp_margin = tuning.num("enemy", "stomp_margin")
	_cull_distance = tuning.num("limits", "enemy_cull_distance")
	collision_layer = 0
	collision_mask = Player.LAYER_PLAYER
	add_to_group(BoltBlaster.TARGET_GROUP)
	var shape := BoxShape3D.new()
	shape.size = hit_size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = hit_size.y * 0.5
	add_child(collider)


func _enemy_tick(_delta: float) -> void:
	pass


func _on_stomped(_player: Player) -> void:
	pass


func _on_bolted() -> void:
	pass


## True while Tock can be attacked, so nothing shoots at a dead Tock or from behind a menu.
func _tock_in_play() -> bool:
	return tock != null and tock.alive and tock.controls_enabled


## Uses the higher of Tock's feet now and just before contact, because the overlap is reported late.
## Without this a plane's stomp window (box 0.5 high, margin 0.35) is thinner than one tick of a
## fast fall, and a legal stomp counts as a hit.
func _resolve_contact(player: Player) -> void:
	var feet := maxf(player.global_position.y, player.recent_feet_y())
	if StompRules.is_stomp(feet, player.fall_velocity_y, global_position.y, _stomp_margin):
		_on_stomped(player)
	else:
		player.take_hit()


## Ends all gameplay on this enemy. The subclass plays its exit and frees itself.
func _defeat() -> void:
	defeated = true
	_touching = null
	remove_from_group(BoltBlaster.TARGET_GROUP)
	set_deferred("monitoring", false)


## Moves between states of a subclass's transition table; refuses and logs anything unlisted.
func _table_allows(table: Dictionary, from_state: int, to_state: int) -> bool:
	if to_state in table[from_state]:
		return true
	push_error("%s: no transition from %d to %d" % [get_script().get_global_name(), from_state, to_state])
	return false


## Applies the 45 m rule: new enemies stop drawing entirely beyond the cull distance.
func _cull_all_parts() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visibility_range_end = _cull_distance


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_touching = body


func _on_body_exited(body: Node3D) -> void:
	if body == _touching:
		_touching = null
