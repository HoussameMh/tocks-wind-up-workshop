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

const DEFAULT_PATH := "res://assets/data/level_workshop_01.json"
const REWARD_RISE_SECONDS := 0.2
const REWARD_DROP_SECONDS := 0.5
const REWARD_HOVER := 0.9

var spawn_point := Vector3.ZERO
var total_cogs := 0
var beetles: Array[GearBeetle] = []
var blocks: Array[SurpriseBlock] = []
var moving_platforms: Array[CourseObjects.MovingPlatform] = []
var checkpoints: Array[CourseObjects.Checkpoint] = []

var _palette: Dictionary = {}
var _tuning: Tuning


## Builds everything from parsed level data. Call before adding to the tree.
func build(data: Dictionary, tuning: Tuning) -> void:
	_tuning = tuning
	for key: String in (data["palette"] as Dictionary):
		_palette[key] = Color.html(data["palette"][key])
	spawn_point = _vec(data["spawn"])
	_build_environment()
	for entry: Dictionary in data["platforms"]:
		_add_platform(_vec(entry["center"]), _vec(entry["size"]), _color(entry["color"]))
	for entry: Dictionary in data["moving_platforms"]:
		var platform := CourseObjects.MovingPlatform.new()
		platform.setup(_vec(entry["a"]), _vec(entry["b"]), _vec(entry["size"]), entry["speed"], _color(entry["color"]))
		moving_platforms.append(platform)
		add_child(platform)
	for entry: Dictionary in data["blocks"]:
		_add_block(entry)
	for entry: Dictionary in data["beetles"]:
		_add_beetle(entry)
	for entry: Dictionary in data["cog_lines"]:
		_add_cog_line(_vec(entry["from"]), _vec(entry["to"]), int(entry["count"]))
	for entry: Array in data["cogs"]:
		_add_cog(_vec(entry))
	for entry: Dictionary in data["springs"]:
		var spring := CourseObjects.SpringPad.new()
		spring.setup(_vec(entry["pos"]), _tuning.num("world", "spring_launch_speed"))
		spring.used.connect(spring_used.emit)
		add_child(spring)
	for entry: Dictionary in data["checkpoints"]:
		var checkpoint := CourseObjects.Checkpoint.new()
		checkpoint.setup(_vec(entry["pos"]), _vec(entry["respawn"]))
		checkpoint.reached.connect(checkpoint_reached.emit)
		checkpoints.append(checkpoint)
		add_child(checkpoint)
	var goal := CourseObjects.GoalKey.new()
	goal.setup(_vec(data["goal"]["pos"]), _vec(data["goal"]["area_size"]))
	goal.reached.connect(goal_reached.emit)
	add_child(goal)
	for entry: Dictionary in data["decor"]:
		_add_decor(entry)


## Removes every enemy; used to test the course geometry on its own.
func remove_enemies() -> void:
	for beetle in beetles:
		beetle.queue_free()
	beetles.clear()


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("8ec9ee")
	sky_material.sky_horizon_color = Color("fbe6c4")
	sky_material.ground_bottom_color = Color("6b4a2e")
	sky_material.ground_horizon_color = Color("fbe6c4")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff1dc")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	sun.light_color = Color("fff4e0")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


func _add_platform(center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = Player.LAYER_WORLD
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var visual := MeshInstance3D.new()
	visual.mesh = MeshKit.box(size)
	visual.material_override = MeshKit.plank_material(color)
	body.add_child(visual)
	add_child(body)


func _add_block(entry: Dictionary) -> void:
	var block := SurpriseBlock.new()
	block.setup(entry["kind"], bool(entry.get("hidden", false)), _vec(entry["pos"]))
	block.reward_released.connect(_on_reward_released)
	block.crate_broken.connect(crate_broken.emit)
	block.thudded.connect(block_thudded.emit)
	blocks.append(block)
	add_child(block)
	if entry["kind"] == "cog":
		total_cogs += 1


func _add_beetle(entry: Dictionary) -> void:
	var beetle := GearBeetle.new()
	beetle.setup(_vec(entry["a"]), _vec(entry["b"]), entry["speed"], _tuning)
	beetle.stomped.connect(enemy_stomped.emit)
	beetle.tree_exiting.connect(func() -> void: beetles.erase(beetle))
	beetles.append(beetle)
	add_child(beetle)


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


func _on_reward_released(kind: String, at: Vector3) -> void:
	if kind == "cog":
		cog_collected.emit()
		_pop_cog(at)
		return
	reward_revealed.emit()
	var pickup := _add_pickup(kind, at)
	var rise := at + Vector3.UP * _tuning.num("world", "block_reward_rise")
	var landing := Vector3(at.x, _floor_below(at) + REWARD_HOVER, at.z)
	var tween := pickup.create_tween()
	tween.tween_property(pickup, "position", rise, REWARD_RISE_SECONDS)
	tween.tween_property(pickup, "position", landing, REWARD_DROP_SECONDS)


func _pop_cog(at: Vector3) -> void:
	var cog := MeshInstance3D.new()
	cog.mesh = MeshKit.cog_mesh()
	cog.material_override = MeshKit.color_material(Pickup.BRASS, 0.15, 0.4)
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


func _add_decor(entry: Dictionary) -> void:
	var color := _color(entry["color"])
	var root := Node3D.new()
	root.position = _vec(entry["pos"])
	if entry.has("rot"):
		root.rotation_degrees = _vec(entry["rot"])
	add_child(root)
	match String(entry["type"]):
		"box":
			var visual := MeshInstance3D.new()
			visual.mesh = MeshKit.box(_vec(entry["size"]))
			visual.material_override = MeshKit.plank_material(color)
			root.add_child(visual)
		"cylinder":
			MeshKit.part(root, MeshKit.cylinder(entry["radius"], entry["radius"], entry["height"], 24), color)
		"pencil":
			_build_pencil(root, entry["length"], entry["radius"], color)


func _build_pencil(root: Node3D, length: float, radius: float, color: Color) -> void:
	var tip_length := radius * 2.5
	MeshKit.part(root, MeshKit.cylinder(radius, radius, length, 6), color)
	MeshKit.part(root, MeshKit.cylinder(radius, radius * 0.25, tip_length, 6), Color("e8c79a"), Vector3(0.0, -length * 0.5 - tip_length * 0.5, 0.0))
	MeshKit.part(root, MeshKit.cylinder(radius * 1.02, radius * 1.02, radius, 12), Color("e87aa4"), Vector3(0.0, length * 0.5 + radius * 0.5, 0.0))


func _color(key: String) -> Color:
	return _palette.get(key, Color.MAGENTA)


func _vec(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
