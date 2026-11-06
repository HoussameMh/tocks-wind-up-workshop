class_name Level
extends Node3D
## Builds a course from a level data file (documented in assets/data/data_reference.md)
## and forwards what happens in it as signals.

signal cog_collected
signal life_collected
signal power_collected
signal enemy_stomped
signal crate_broken
signal block_thudded
signal reward_revealed
signal spring_used
signal checkpoint_reached(respawn_at: Vector3)
signal goal_reached
## An enemy or enemy shot earned points, with the sound that goes with them.
signal enemy_scored(points: int, sound: String)
## An enemy wants a sound played, such as a telegraph.
signal enemy_sound(sound: String)
signal blaster_collected

const DEFAULT_PATH := "res://assets/data/level_workshop_01.json"
const REWARD_RISE_SECONDS := 0.2
const REWARD_DROP_SECONDS := 0.5
const REWARD_HOVER := 0.9

## The name shown on the level banner.
var level_name := ""
## This level's clock, per life.
var time_seconds := 0.0
## The level's joke for its clear screen, and for a Game Over on it.
var quip_clear := ""
var quip_over := ""
## The level's own camera framing, empty for the default.
var camera_framing: Dictionary = {}
var spawn_point := Vector3.ZERO
var total_cogs := 0
var beetles: Array[GearBeetle] = []
var blocks: Array[SurpriseBlock] = []
var moving_platforms: Array[CourseObjects.MovingPlatform] = []
var checkpoints: Array[CourseObjects.Checkpoint] = []
## Every plane, duck and teeth. Beetles of both kinds stay in beetles.
var enemies: Array[EnemyBase] = []
## The shared pool of erasers and bubbles.
var shots: EnemyShotPool
## The final boss, on the level that has one.
var boss: BaronRust

var _tuning: Tuning
var _player: Player
var _palette: Dictionary = {}
var _boss_data: Dictionary = {}
## What each toy box let out and nobody has collected yet, as block -> Pickup.
var _released: Dictionary = {}


## Builds everything from parsed level data. Call before adding to the tree.
func build(data: Dictionary, tuning: Tuning) -> void:
	_tuning = tuning
	var palette: Dictionary = data["palette"]
	_palette = palette
	level_name = data["name"]
	quip_clear = data.get("quip_clear", "")
	quip_over = data.get("quip_over", "")
	camera_framing = data.get("camera", {})
	time_seconds = float(data.get("time_seconds", tuning.num("run", "level_seconds")))
	spawn_point = _vec(data["spawn"])
	_build_environment(data.get("lamp_z", []))
	shots = EnemyShotPool.new()
	shots.setup(tuning)
	shots.scored.connect(enemy_scored.emit)
	shots.sound_requested.connect(enemy_sound.emit)
	add_child(shots)
	for entry: Dictionary in data["platforms"]:
		_add_platform(_vec(entry["center"]), _vec(entry["size"]))
	CourseDressing.build(self, data, palette)
	for entry: Dictionary in data["moving_platforms"]:
		var platform := CourseObjects.MovingPlatform.new()
		platform.setup(
			_vec(entry["a"]), _vec(entry["b"]), _vec(entry["size"]), entry["speed"], palette[entry["color"]], entry.get("visual", "")
		)
		moving_platforms.append(platform)
		add_child(platform)
	for entry: Dictionary in data.get("paint_spills", []):
		add_paint_spill(entry)
	for entry: Dictionary in data["blocks"]:
		add_block(entry)
	for entry: Dictionary in data["beetles"]:
		add_beetle(entry)
	for entry: Dictionary in data.get("planes", []):
		add_plane(entry)
	for entry: Dictionary in data.get("ducks", []):
		add_duck(entry)
	for entry: Dictionary in data.get("teeth", []):
		add_teeth(entry)
	for entry: Dictionary in data["cog_lines"]:
		_add_cog_line(_vec(entry["from"]), _vec(entry["to"]), int(entry["count"]))
	for entry: Array in data["cogs"]:
		_add_cog(_vec(entry))
	for entry: Dictionary in data["springs"]:
		_add_spring(entry)
	for entry: Dictionary in data["checkpoints"]:
		var checkpoint := CourseObjects.Checkpoint.new()
		checkpoint.setup(_vec(entry["pos"]), _vec(entry["respawn"]))
		checkpoint.reached.connect(checkpoint_reached.emit)
		checkpoints.append(checkpoint)
		add_child(checkpoint)
	# The boss level has no key until the Baron is scrap.
	if data.has("goal"):
		add_goal(_vec(data["goal"]["pos"]), _vec(data["goal"]["area_size"]))
	for entry: Dictionary in data.get("arena_walls", []):
		_add_arena_wall(_vec(entry["center"]), _vec(entry["size"]))
	_boss_data = data.get("boss", {})
	WorkshopScenery.build(self, data["decor"])


## Adds a Golden Key, touching which ends the level.
func add_goal(at: Vector3, area_size: Vector3) -> CourseObjects.GoalKey:
	var goal := CourseObjects.GoalKey.new()
	goal.setup(at, area_size)
	goal.reached.connect(goal_reached.emit)
	add_child(goal)
	return goal


## Adds a toy box or crate from a level entry.
func add_block(entry: Dictionary) -> SurpriseBlock:
	var block := SurpriseBlock.new()
	block.setup(entry["kind"], bool(entry.get("hidden", false)), _vec(entry["pos"]))
	block.rearms = bool(entry.get("rearm", false))
	block.reward_released.connect(_on_reward_released.bind(block))
	block.crate_broken.connect(crate_broken.emit)
	block.thudded.connect(block_thudded.emit)
	blocks.append(block)
	add_child(block)
	if entry["kind"] == "cog":
		total_cogs += 1
	return block


## Adds a slick paint spill from a level entry.
func add_paint_spill(entry: Dictionary) -> CourseObjects.PaintSpill:
	var spill := CourseObjects.PaintSpill.new()
	var size: Array = entry["size"]
	spill.setup(_vec(entry["center"]), Vector2(size[0], size[1]), _tuning.num("paint", "sloop_speed"))
	spill.slooped.connect(enemy_sound.emit.bind("paint_sloop"))
	add_child(spill)
	return spill


## Makes every rearm box fresh and removes whatever it let out that was never collected.
func rearm_boxes() -> void:
	for block in blocks:
		if not is_instance_valid(block) or not block.rearms or not block.used:
			continue
		var pickup: Variant = _released.get(block)
		if is_instance_valid(pickup):
			(pickup as Pickup).queue_free()
		_released.erase(block)
		block.rearm()


## Rewards let out of boxes and still waiting to be collected.
func released_reward_count() -> int:
	var count := 0
	for pickup: Variant in _released.values():
		if is_instance_valid(pickup) and not (pickup as Node).is_queued_for_deletion():
			count += 1
	return count


## Removes every enemy; used to test the course geometry on its own.
func remove_enemies() -> void:
	for beetle in beetles:
		beetle.queue_free()
	beetles.clear()
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	shots.clear_all()


## Tells every enemy and shot who to look for. Call once Tock exists.
func bind_player(player: Player) -> void:
	_player = player
	shots.bind_player(player)
	for beetle in beetles:
		beetle.tock = player
	for enemy in enemies:
		enemy.tock = player
	if not _boss_data.is_empty():
		_add_boss(player)


## A new life began: boxes re-arm and the Baron, if there is one, resets his phase.
func on_player_respawned() -> void:
	rearm_boxes()
	if boss != null:
		boss.on_tock_respawned()


## The life ended: nothing keeps flying at an empty arena.
func on_player_died() -> void:
	clear_shots()
	if boss != null:
		boss.on_tock_died()


## Removes erasers and bubbles in flight, for when a life ends.
func clear_shots() -> void:
	shots.clear_all()


## Adds a beetle from a level entry; armored if the entry says so.
func add_beetle(entry: Dictionary) -> GearBeetle:
	var beetle: GearBeetle = ArmoredBeetle.new() if entry.get("armored", false) else GearBeetle.new()
	beetle.setup(_vec(entry["a"]), _vec(entry["b"]), entry["speed"], _tuning)
	beetle.stomped.connect(enemy_stomped.emit)
	_connect_enemy(beetle)
	beetle.tree_exiting.connect(func() -> void: beetles.erase(beetle))
	beetles.append(beetle)
	add_child(beetle)
	return beetle


## Adds a paper-plane bomber from a level entry.
func add_plane(entry: Dictionary) -> PaperPlane:
	var plane := PaperPlane.new()
	plane.setup(_vec(entry["a"]), _vec(entry["b"]), entry["speed"], _tuning)
	_add_enemy(plane)
	return plane


## Adds a rubber-duck sniper from a level entry.
func add_duck(entry: Dictionary) -> RubberDuck:
	var duck := RubberDuck.new()
	duck.setup(_vec(entry["pos"]), _tuning)
	_add_enemy(duck)
	return duck


## Adds chattering teeth from a level entry.
func add_teeth(entry: Dictionary) -> ChatteringTeeth:
	var teeth := ChatteringTeeth.new()
	teeth.setup(_vec(entry["pos"]), _tuning)
	_add_enemy(teeth)
	return teeth


func _build_environment(lamp_z: Array) -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.environment = Look.environment()
	add_child(world_environment)
	Look.build_lights(self, lamp_z)


func _add_boss(player: Player) -> void:
	boss = BaronRust.new()
	boss.setup(_tuning, self, player, _vec(_boss_data["key_pos"]), _vec(_boss_data["key_area"]), _boss_data["taunts"])
	boss.scored.connect(enemy_scored.emit)
	boss.sound_requested.connect(enemy_sound.emit)
	add_child(boss)


## Stops Tock only, on its own layer, so the camera's ray and Tock's bolts pass through.
func _add_arena_wall(center: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.position = center
	wall.collision_layer = Player.LAYER_ARENA_WALL
	wall.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	wall.add_child(collider)
	add_child(wall)


func _add_spring(entry: Dictionary) -> void:
	var spring := CourseObjects.SpringPad.new()
	var speed: float = entry.get("speed", _tuning.num("world", "spring_launch_speed"))
	var visual: String = entry.get("visual", "")
	spring.setup(_vec(entry["pos"]), speed, visual)
	if visual == CourseObjects.SpringPad.VISUAL_BAND:
		spring.used.connect(enemy_sound.emit.bind("band_boing"))
	else:
		spring.used.connect(spring_used.emit)
	add_child(spring)


func _add_platform(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = Player.LAYER_WORLD
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _add_enemy(enemy: EnemyBase) -> void:
	_connect_enemy(enemy)
	enemy.tree_exiting.connect(func() -> void: enemies.erase(enemy))
	enemies.append(enemy)
	add_child(enemy)


func _connect_enemy(enemy: EnemyBase) -> void:
	enemy.shots = shots
	enemy.tock = _player
	enemy.scored.connect(enemy_scored.emit)
	enemy.sound_requested.connect(enemy_sound.emit)


func _add_cog_line(from: Vector3, to: Vector3, count: int) -> void:
	for i in count:
		var ratio := float(i) / float(maxi(count - 1, 1))
		_add_cog(from.lerp(to, ratio))


func _add_cog(at: Vector3) -> void:
	total_cogs += 1
	_add_pickup("cog", at)


func _add_pickup(kind: String, at: Vector3) -> Pickup:
	var pickup := Pickup.new()
	pickup.setup(kind, at)
	pickup.collected.connect(_on_pickup_collected)
	add_child(pickup)
	return pickup


func _on_pickup_collected(kind: String, player: Player) -> void:
	match kind:
		"cog":
			cog_collected.emit()
		"life":
			life_collected.emit()
		"coil":
			player.apply_power_up()
			power_collected.emit()
		"bolt":
			player.apply_blaster_power()
			blaster_collected.emit()


func _on_reward_released(kind: String, at: Vector3, block: SurpriseBlock) -> void:
	if kind == "cog":
		cog_collected.emit()
		_pop_cog(at)
		return
	reward_revealed.emit()
	var pickup := _add_pickup(kind, at)
	_released[block] = pickup
	var rise := at + Vector3.UP * _tuning.num("world", "block_reward_rise")
	var landing := Vector3(at.x, _floor_below(at) + REWARD_HOVER, at.z)
	var tween := pickup.create_tween()
	tween.tween_property(pickup, "position", rise, REWARD_RISE_SECONDS)
	tween.tween_property(pickup, "position", landing, REWARD_DROP_SECONDS)


func _pop_cog(at: Vector3) -> void:
	var cog := MeshInstance3D.new()
	cog.mesh = MeshKit.cog_mesh()
	cog.material_override = Look.material("cog")
	cog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cog.position = at
	add_child(cog)
	var tween := cog.create_tween()
	tween.tween_property(cog, "position", at + Vector3.UP * 1.8, 0.25)
	tween.parallel().tween_property(cog, "rotation:y", TAU, 0.25)
	tween.tween_callback(cog.queue_free)


func _floor_below(at: Vector3) -> float:
	var from := at + Vector3.DOWN * 0.6
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, Player.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else at.y - 2.0


func _vec(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
