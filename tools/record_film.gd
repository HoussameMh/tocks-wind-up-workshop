extends SceneTree
## Records the shots of the intro and outro films from the real game: the real level, Tock and Baron
## Rust, directed shot by shot, saved as numbered JPEGs for video/intro and video/outro to cut together.
## Usage: godot --path . --resolution 640x360 --fixed-fps 30 --audio-driver Dummy
##   -s res://tools/record_film.gd -- <output dir> <shot> [<shot> ...]
## The shot "sfx" instead saves the game's sound effects as WAV files to <output dir>/sfx.
## Needs a real window: it does not work with --headless.

const FPS := 30.0
const SIZE := Vector2i(1920, 1080)
const JPEG_QUALITY := 0.96
const SHADOW_ATLAS := 8192

var _out := ""
var _view: SubViewport
var _main: Main
var _cam: Camera3D
var _shot := ""
var _frame := 0
var _cmd := Player.Command.new()
var _lights: Array[Light3D] = []
var _light_energy: Array[float] = []
var _ambient_energy := 0.0
var _cam_pos := Vector3.ZERO
var _spin := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	if args[1] == "sfx":
		_export_sfx()
		quit(0)
		return
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS, true)
	_view = SubViewport.new()
	_view.size = SIZE
	_view.msaa_3d = Viewport.MSAA_8X
	_view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.own_world_3d = true
	root.add_child(_view)
	_main = (load(TestKit.MAIN_SCENE) as PackedScene).instantiate()
	_main.films_enabled = false
	_view.add_child(_main)
	await _wait(5)
	_main.start_game()
	_main.set_physics_process(false)
	_main.hud.visible = false
	_ambient_energy = Look.environment().ambient_light_energy
	for shot: String in args.slice(1):
		_shot = shot
		_frame = 0
		DirAccess.make_dir_recursive_absolute("%s/%s" % [_out, shot])
		print("recording ", shot)
		await call("shot_" + shot)
		print("  %d frames" % _frame)
	quit(0)


func _export_sfx() -> void:
	DirAccess.make_dir_recursive_absolute(_out + "/sfx")
	var sfx := Sfx.new()
	for sound_name: String in Sfx.SOUNDS:
		var stream: AudioStreamWAV = sfx._synthesize(Sfx.SOUNDS[sound_name])
		stream.save_to_wav("%s/sfx/%s.wav" % [_out, sound_name])
	sfx.free()


# Stage

## Loads a level with the film camera. Tock stands still and cannot be hurt until a shot says so.
func _stage(index: int, keep_enemies := false, actor_controls := false) -> void:
	Look.environment().ambient_light_energy = _ambient_energy
	_main.load_level(index)
	_main.run_state.enter_level(9999.0)
	_main.hud.visible = false
	_main.camera.set_physics_process(false)
	var level := _main.level
	if level.goal_reached.is_connected(_main._on_goal_reached):
		level.goal_reached.disconnect(_main._on_goal_reached)
	if not keep_enemies:
		level.remove_enemies()
	_cam = Camera3D.new()
	_cam.far = 500.0
	level.add_child(_cam)
	_cam.make_current()
	var player := _main.player
	player.controls_enabled = actor_controls
	player.set_physics_process(actor_controls)
	_cmd = Player.Command.new()
	player.bot_control = func() -> Player.Command: return _cmd
	_lights.clear()
	_light_energy.clear()
	for node in level.find_children("*", "Light3D", true, false):
		_lights.append(node)
		_light_energy.append((node as Light3D).light_energy)
	await _wait(3)


## Clears the level's cogs, which would block the camera in close shots.
func _hide_cogs() -> void:
	for node in _main.level.get_children():
		if node is Pickup:
			(node as Pickup).hide()


## Dims the whole room: 1 is as lit in the game.
func _dim(amount: float) -> void:
	for i in _lights.size():
		_lights[i].light_energy = _light_energy[i] * amount
	Look.environment().ambient_light_energy = _ambient_energy * amount


## Renders a shot. update receives the time in seconds, once per frame.
func _play(seconds: float, update: Callable) -> void:
	for i in roundi(seconds * FPS):
		update.call(float(i) / FPS)
		await RenderingServer.frame_post_draw
		var image := _view.get_texture().get_image()
		image.save_jpg("%s/%s/%05d.jpg" % [_out, _shot, _frame], JPEG_QUALITY)
		_frame += 1
		await process_frame


func _wait(count: int) -> void:
	for _i in count:
		await process_frame


func _look(from: Vector3, at: Vector3, fov: float, side_shift := 0.0) -> void:
	_cam.global_position = from
	_cam.look_at(at)
	_cam.fov = fov
	_cam.h_offset = side_shift


## Eases through keys of [time, value], where value is a float or a Vector3.
func _k(t: float, keys: Array) -> Variant:
	if t <= keys[0][0]:
		return keys[0][1]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t <= b[0]:
			var ratio := smoothstep(a[0], b[0], t)
			return lerp(a[1], b[1], ratio)
	return keys[-1][1]


# Tock

func _model() -> TockModel:
	return _main.player._model


## Poses Tock by hand. tilt leans him forward, squash is his height, and arms lifts both arms.
func _pose(at: Vector3, yaw: float, tilt := 0.0, squash := 1.0, arms := 0.0, key_rate := 1.5) -> void:
	var player := _main.player
	var model := _model()
	player.global_position = at
	model.rotation = Vector3(tilt, yaw, 0.0)
	var wide := 1.0 / sqrt(maxf(squash, 0.1))
	model.scale = Vector3(wide, squash, wide)
	model._left_arm.rotation.x = -arms
	model._right_arm.rotation.x = -arms * 0.86
	model._key.rotation.z += key_rate / FPS
	player._update_shadow()
	model.visible = true


func _walk_cycle(speed: float) -> void:
	var model := _model()
	_spin += speed * 15.0 / FPS
	var swing := sin(_spin) * minf(speed * 1.5, 1.0)
	model._left_leg.rotation.x = swing * 0.9
	model._right_leg.rotation.x = -swing * 0.9
	model._left_arm.rotation.x = -swing * 0.75
	model._right_arm.rotation.x = swing * 0.75


func _stand_legs() -> void:
	_model()._left_leg.rotation.x = 0.0
	_model()._right_leg.rotation.x = 0.0


## The Baron's little top hat, for when it lands on Tock.
func _make_hat(parent: Node3D) -> Node3D:
	var hat := Node3D.new()
	parent.add_child(hat)
	var batch := MeshBatch.new()
	batch.add_mesh(MeshKit.cylinder(0.72, 0.72, 0.1, 16))
	batch.add_mesh(MeshKit.cylinder(0.46, 0.46, 0.75, 16), Transform3D(Basis.IDENTITY, Vector3.UP * 0.42))
	MeshKit.part(hat, batch.commit(), "boss_dark", Vector3.ZERO, false)
	hat.scale = Vector3.ONE * 0.36
	return hat


# Baron Rust

func _baron() -> BaronRust:
	var boss: BaronRust = _main.level.boss
	boss.set_physics_process(false)
	boss.hazards.set_physics_process(false)
	return boss


func _baron_pose(boss: BaronRust, head: Vector3, moustache: float, fists: float, turn := Vector3.ZERO) -> void:
	boss._head.position = head
	boss._head.rotation = turn
	boss._moustache_left.rotation.z = moustache
	boss._moustache_right.rotation.z = -moustache
	var fist_y := lerpf(BaronRust.FIST_REST_Y, BaronRust.FIST_RAISED_Y, fists)
	boss._left_fist.position.y = fist_y
	boss._right_fist.position.y = lerpf(BaronRust.FIST_REST_Y, BaronRust.FIST_RAISED_Y, fists * 0.86)
	boss._stretch_neck()


func _baron_heap(boss: BaronRust) -> void:
	boss._torso.position.y = BaronRust.COLLAPSE_DROP
	boss._neck.hide()
	boss._hat.hide()
	boss._head.position = BaronRust.HEAD_HEAP
	boss._moustache_left.rotation.z = 0.66
	boss._moustache_right.rotation.z = -0.66
	boss._left_fist.position.y = 6.9
	boss._right_fist.position.y = 6.9


## A real Golden Key with its halo and light, which nothing is listening to.
func _gold_key(at: Vector3) -> Node3D:
	var key := CourseObjects.GoalKey.new()
	key.setup(at, Vector3.ONE * 0.01)
	_main.level.add_child(key)
	return key


# Toys: the game's own enemies, idle because Tock is not in play.

func _add_toys(z: float) -> Dictionary:
	var level := _main.level
	var duck := level.add_duck({"pos": [-4.6, 0.0, z + 3.0]})
	var teeth := level.add_teeth({"pos": [4.6, 0.0, z + 3.4]})
	var plane := level.add_plane({"a": [-11.0, 0.0, z], "b": [11.0, 0.0, z], "speed": 5.0})
	var line: Array[GearBeetle] = []
	for i in 4:
		var beetle := level.add_beetle({"a": [-6.5, 0.0, z + 5.2], "b": [6.5, 0.0, z + 5.2], "speed": 2.4, "armored": i == 2})
		beetle._travel = 0.08 + i * 0.11
		line.append(beetle)
	for enemy: EnemyBase in [duck, teeth, plane] + line:
		enemy.tock = null
	return {"duck": duck, "teeth": teeth, "plane": plane, "beetles": line}


# Intro

const SPOT_BENCH := Vector3(0.0, 0.0, -3.0)
const TITLE_YAW := 1.01


func _bench_camera(yaw: float, distance := 3.8, height := 0.78) -> void:
	var offset := Vector3(0.0, height, distance).rotated(Vector3.UP, yaw)
	_look(SPOT_BENCH + offset, SPOT_BENCH + Vector3.UP * 0.72, 38.0, -0.62)


func shot_dusk() -> void:
	await _stage(0, true)
	_hide_cogs()
	var hop := [[2.3, 0.0], [2.65, 0.32], [3.0, 0.0]]
	var squash := [[2.1, 1.0], [2.3, 0.86], [2.45, 1.08], [2.9, 1.0], [3.02, 0.88], [3.3, 1.0]]
	await _play(4.4, func(t: float) -> void:
		_bench_camera(TITLE_YAW - 0.12 + t * 0.03)
		var up: float = _k(t, hop)
		var arms: float = _k(t, [[2.25, 0.0], [2.6, 1.3], [3.05, 0.0]])
		_stand_legs()
		_pose(SPOT_BENCH + Vector3.UP * up, TITLE_YAW - 0.45, 0.0, _k(t, squash), arms)
	)


func shot_key() -> void:
	await _stage(0)
	_hide_cogs()
	_add_toys(-154.0)
	await _play(4.6, func(t: float) -> void:
		var from: Vector3 = _k(t, [[0.0, Vector3(1.5, 0.5, -140.8)], [4.6, Vector3(0.9, 0.8, -143.7)]])
		_look(from, Vector3(0.0, 2.15, -154.0), 46.0)
		_stand_legs()
		_pose(Vector3(0.0, 0.0, -146.0), PI, -0.12, 1.0 + sin(t * 3.0) * 0.012, 0.0, 3.0)
	)


func shot_baron() -> void:
	await _stage(4)
	var boss := _baron()
	_main.player.visible = false
	var head := [
		[0.0, Vector3(0.0, 9.85, -28.0)], [1.5, Vector3(0.0, 9.85, -28.0)], [1.8, Vector3(0.0, 9.6, -27.8)],
		[2.2, Vector3(0.0, 10.8, -28.7)], [2.55, BaronRust.HEAD_HIGH],
	]
	await _play(5.2, func(t: float) -> void:
		var snore := sin(t * 2.2) * 0.07 * (1.0 - smoothstep(1.4, 1.8, t))
		var whisker: float = _k(t, [[1.7, 0.42], [2.15, -0.28], [2.45, -0.08]])
		var fists: float = _k(t, [[3.2, 0.0], [3.6, 1.0]])
		var at: Vector3 = _k(t, head)
		var turn := Vector3(0.0, _k(t, [[3.9, 0.0], [4.3, -0.42]]), sin(t * 18.0) * 0.012 * fists)
		_baron_pose(boss, at + Vector3.UP * snore, whisker, fists, turn)
		var from: Vector3 = _k(t, [[0.0, Vector3(0.8, 8.2, -18.2)], [5.2, Vector3(0.3, 8.9, -20.0)]])
		_look(from, Vector3(0.0, 9.8, -28.6), 38.0)
	)


func shot_snatch() -> void:
	await _stage(4)
	var boss := _baron()
	var key := _gold_key(Vector3(0.0, 2.6, -13.0))
	var key_home := key.position
	var plinth := MeshKit.part(_main.level, MeshKit.box(Vector3(4.0, 1.0, 4.0)), "checkpoint_base", Vector3(0.0, 0.5, -13.0))
	plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for block in _main.level.blocks:
		block.hide()
	_hide_cogs()
	var carried := Vector3(0.0, -1.25, 1.55)
	var rear := Vector3(0.0, 11.7, -29.6)
	var strike := key_home - carried
	await _play(4.8, func(t: float) -> void:
		var at: Vector3
		if t < 0.9:
			at = _k(t, [[0.0, BaronRust.HEAD_HIGH], [0.9, rear]])
		elif t < 1.22:
			var ratio := (t - 0.9) / 0.32
			at = rear.lerp(strike, ratio * ratio)
		elif t < 1.5:
			at = strike
		else:
			at = _k(t, [[1.5, strike], [2.25, BaronRust.HEAD_HIGH + Vector3.UP * 0.5], [2.6, BaronRust.HEAD_HIGH]])
		var pleased := smoothstep(2.6, 2.9, t)
		var turn := Vector3(0.0, 0.0, sin(t * 7.0) * 0.14 * pleased)
		var whisker: float = _k(t, [[1.22, 0.0], [1.4, -0.3], [2.8, -0.42]])
		_baron_pose(boss, at, whisker, _k(t, [[0.4, 0.2], [0.9, 1.0], [1.22, 0.1]]), turn)
		if t >= 1.22:
			key.position = boss._head.position + carried
		_look(Vector3(13.5, 3.1, -7.6), Vector3(1.6, 3.9, -17.0), 58.0)
		var startle: float = _k(t, [[1.22, 0.0], [1.42, 1.0], [2.2, 0.75]])
		var spot := Vector3(5.2, 0.0, -9.6) + Vector3(startle * 0.8, sin(minf(startle, 1.0) * PI) * 0.5, startle * 0.3)
		_stand_legs()
		_pose(spot, -2.1, -0.18 * startle, 1.0 + 0.08 * startle, startle * 2.5, 1.5)
	)


func shot_winddown() -> void:
	await _stage(0)
	_hide_cogs()
	for block in _main.level.blocks:
		block.hide()
	var level := _main.level
	var beetle := level.add_beetle({"a": [-3.0, 0.0, -2.0], "b": [-3.0, 0.0, -20.0], "speed": 2.2})
	beetle.tock = null
	var duck := level.add_duck({"pos": [-3.6, 0.0, -3.0]})
	duck.tock = null
	var z := -5.4
	await _play(8.2, func(t: float) -> void:
		var run_down: float = _k(t, [[0.0, 0.45], [3.1, 0.0]])
		z -= 7.0 * run_down / FPS
		beetle.speed = 2.2 * run_down
		if run_down < 0.01:
			beetle.set_physics_process(false)
			duck.set_physics_process(false)
		_dim(_k(t, [[0.0, 1.0], [3.4, 0.42], [5.3, 0.42], [6.2, 0.62]]))
		var tilt: float = _k(t, [[2.6, 0.0], [3.6, 0.3], [5.45, 0.3], [5.85, -0.08], [6.15, 0.0], [7.35, 0.0], [7.8, 0.34]])
		var squash: float = _k(t, [[5.4, 1.0], [5.6, 0.8], [5.85, 1.14], [6.15, 1.0], [7.35, 1.0], [7.8, 0.86]])
		var yaw: float = _k(t, [[6.2, PI], [6.6, PI + 1.9], [6.95, PI + 1.9], [7.3, PI]])
		var clicked := Vector3.ZERO
		var key_rate := 7.0 * run_down
		if t >= 5.2 and t < 5.3:
			key_rate = 11.0
		elif t >= 5.3:
			key_rate = 2.0
		var from := Vector3(_k(t, [[0.0, 2.5], [8.2, 1.9]]), 0.82, z - _k(t, [[0.0, 3.1], [8.2, 2.3]]))
		_look(from, Vector3(-0.1, 0.7, z) + clicked, 36.0)
		_walk_cycle(run_down)
		if run_down > 0.005:
			_pose(Vector3(0.0, 0.0, z), yaw, tilt, squash, 0.0, key_rate)
			_walk_cycle(run_down)
		else:
			_stand_legs()
			_pose(Vector3(0.0, 0.0, z), yaw, tilt, squash, _k(t, [[5.45, 0.0], [5.85, 1.0], [6.2, 0.0], [7.35, 0.0], [7.8, -0.6]]), key_rate)
	)
	_dim(1.0)


## Runs Tock for real. plan sets the command each frame and may move the camera.
func _bot_run(seconds: float, plan: Callable) -> void:
	await _play(seconds, func(t: float) -> void:
		_main.player._power.invulnerable_left = 99.0
		plan.call(t)
		_model().visible = true
	)


func _chase(offset: Vector3, look_ahead: Vector3, fov: float, first := false) -> void:
	var feet := _main.player.global_position
	var goal := feet + offset
	_cam_pos = goal if first else _cam_pos.lerp(goal, 0.3)
	_look(_cam_pos, feet + look_ahead, fov)


func shot_run_bench() -> void:
	await _stage(0, false, true)
	var beetle := _main.level.add_beetle({"a": [0.0, 0.0, -13.0], "b": [0.0, 0.0, -13.0], "speed": 0.0})
	beetle.tock = _main.player
	_main.player.global_position = Vector3(0.0, 0.2, 2.0)
	_cmd.move = Vector3.FORWARD
	_cmd.run = true
	_cmd.jump_held = true
	var first := {"yes": true}
	await _bot_run(2.2, func(t: float) -> void:
		_cmd.jump_pressed = _main.player.global_position.z < -3.0 and _main.player.is_on_floor() and t < 1.0
		_chase(Vector3(-1.7, 0.95, 3.7), Vector3(0.0, 0.5, -5.0), 52.0, first["yes"])
		first["yes"] = false
	)


func shot_run_pencil() -> void:
	await _stage(1, false, true)
	_main.player.global_position = Vector3(0.0, 0.2, -24.0)
	_cmd.move = Vector3.FORWARD
	_cmd.run = true
	_cmd.jump_held = true
	var first := {"yes": true}
	await _bot_run(2.5, func(_t: float) -> void:
		var feet := _main.player.global_position
		var edge := (feet.z < -29.2 and feet.z > -30.0) or feet.z < -47.2
		_cmd.jump_pressed = edge and _main.player.is_on_floor()
		if feet.z < -46.0:
			_cmd.move = Vector3(-0.2, 0.0, -1.0).normalized()
		_chase(Vector3(5.6, 2.1, 1.4), Vector3(0.0, 0.3, -2.2), 50.0, first["yes"])
		first["yes"] = false
	)


func shot_run_paint() -> void:
	await _stage(2, true, true)
	for beetle in _main.level.beetles.duplicate():
		beetle.queue_free()
	_hide_cogs()
	_main.player.global_position = Vector3(0.0, 0.2, -71.5)
	_cmd.move = Vector3.FORWARD
	_cmd.run = true
	var first := {"yes": true}
	await _bot_run(2.5, func(_t: float) -> void:
		if _main.player.global_position.z < -79.5:
			_cmd.move = Vector3.RIGHT * 0.5
			_cmd.run = false
		_chase(Vector3(1.8, 1.0, -6.4), Vector3(0.0, 0.5, 0.0), 44.0, first["yes"])
		first["yes"] = false
	)


func shot_run_wrench() -> void:
	await _stage(3, false, true)
	var first_plate: Node3D = _main.level.moving_platforms[3]
	var second_plate: Node3D = _main.level.moving_platforms[4]
	first_plate._progress = 0.2
	second_plate._progress = 0.2
	first_plate._physics_process(0.0)
	second_plate._physics_process(0.0)
	await _wait(2)
	_main.player.global_position = first_plate.global_position + Vector3(0.0, 0.35, -1.8)
	await _wait(2)
	var first := {"yes": true}
	await _bot_run(2.6, func(t: float) -> void:
		var to_plate := second_plate.global_position - _main.player.global_position
		to_plate.y = 0.0
		_cmd.move = Vector3.ZERO if t < 0.5 else to_plate.normalized()
		_cmd.jump_pressed = t >= 0.5 and t < 0.56
		_cmd.jump_held = t < 1.2
		_chase(Vector3(3.9, 1.9, 2.3), Vector3(0.0, 0.3, -2.4), 54.0, first["yes"])
		first["yes"] = false
	)


func shot_run_blaster() -> void:
	await _stage(2, false, true)
	_hide_cogs()
	var duck := _main.level.add_duck({"pos": [-3.2, 0.0, -91.0]})
	duck.tock = null
	_main.player.global_position = Vector3(0.0, 0.2, -82.5)
	_main.player.apply_blaster_power()
	_cmd.move = Vector3(-0.27, 0.0, -0.96) * 0.2
	var first := {"yes": true}
	await _bot_run(2.2, func(t: float) -> void:
		_cmd.fire_pressed = t >= 0.45 and t < 1.2
		_chase(Vector3(3.6, 1.15, 0.6), Vector3(-1.6, 0.8, -4.2), 48.0, first["yes"])
		first["yes"] = false
	)


func shot_run_boss() -> void:
	await _stage(4, false, true)
	var boss: BaronRust = _main.level.boss
	boss._fist_raise = 1.0
	_main.player.global_position = Vector3(0.0, 0.2, -6.0)
	_cmd.move = Vector3.FORWARD
	_cmd.run = true
	_cmd.jump_held = true
	boss.hazards.start_ring()
	var first := {"yes": true}
	await _bot_run(1.7, func(_t: float) -> void:
		var feet := _main.player.global_position
		var ring: float = boss.hazards.ring_radius()
		var gap := Vector2(feet.x, feet.z + 25.0).length() - ring
		_cmd.jump_pressed = ring >= 0.0 and gap > 0.0 and gap < 2.6 and _main.player.is_on_floor()
		_chase(Vector3(1.1, 1.0, 3.7), Vector3(0.0, 3.0, -8.0), 66.0, first["yes"])
		first["yes"] = false
	)


func shot_title() -> void:
	await _stage(0, true)
	_hide_cogs()
	await _play(4.6, func(t: float) -> void:
		_bench_camera(TITLE_YAW + sin(t * 0.3) * 0.03)
		var come: float = _k(t, [[0.0, 1.0], [0.55, 0.0]])
		var at := SPOT_BENCH + Vector3(-1.6 * come, sin(come * PI) * 0.9, -1.8 * come)
		_stand_legs()
		_pose(at, TITLE_YAW - 0.45, 0.0, _k(t, [[0.5, 1.0], [0.62, 0.84], [0.9, 1.0]]), _k(t, [[0.0, 1.8], [0.62, 0.0]]))
	)


# Outro

func shot_heap() -> void:
	await _stage(4)
	var boss: BaronRust = _main.level.boss
	boss.hazards.set_physics_process(false)
	boss.state = BaronRust.State.EXPOSED
	boss._droop = 0.0
	boss._droop_goal = 0.0
	_main.player.global_position = Vector3(5.0, 0.0, -9.0)
	boss._begin_defeat()
	await _play(4.2, func(t: float) -> void:
		if t > 1.15:
			boss._hat.hide()
		boss._moustache_left.rotation.z = _k(t, [[0.0, 0.2], [2.5, 0.3], [3.3, 0.66]])
		boss._moustache_right.rotation.z = -boss._moustache_left.rotation.z
		var from: Vector3 = _k(t, [[0.0, Vector3(0.6, 8.8, -17.6)], [4.2, Vector3(1.0, 8.3, -19.2)]])
		var aim: Vector3 = _k(t, [[2.4, Vector3(0.8, 9.1, -28.2)], [3.4, Vector3(1.2, 7.9, -28.0)]])
		_look(from, aim, 40.0)
	)


func shot_hat() -> void:
	await _stage(4)
	var boss := _baron()
	_baron_heap(boss)
	var hat := _make_hat(_model())
	var spot := Vector3(0.0, 0.0, -11.0)
	await _play(3.6, func(t: float) -> void:
		_look(Vector3(1.25, 0.82, -7.7), spot + Vector3.UP * 0.86, 36.0)
		var drop: float = clampf(t / 1.2, 0.0, 1.0)
		hat.position = Vector3(0.0, lerpf(5.2, 1.16, drop * drop), 0.02)
		hat.rotation.z = lerpf(2.6, 0.0, drop) + _k(t, [[1.2, 0.0], [1.5, 0.3], [1.9, 0.2]])
		var squash: float = _k(t, [[1.16, 1.0], [1.26, 0.72], [1.6, 1.08], [1.9, 1.0]])
		var look: float = _k(t, [[2.3, 0.0], [2.65, 0.6], [3.0, 0.6], [3.3, -0.1]])
		_stand_legs()
		_pose(spot, 0.34 + look, _k(t, [[0.0, -0.22], [1.2, -0.22], [1.45, 0.08], [1.9, 0.0]]), squash, _k(t, [[1.2, 0.0], [1.42, 2.2], [1.95, 0.0]]), _k(t, [[1.2, 1.5], [1.3, 14.0], [2.2, 1.5]]))
	)


func shot_rewind() -> void:
	await _stage(4)
	var boss := _baron()
	_baron_heap(boss)
	var hat := _make_hat(_model())
	hat.position = Vector3(0.0, 1.16, 0.02)
	hat.rotation.z = 0.2
	var key := _gold_key(Vector3(0.0, 2.6, -13.0))
	await _play(4.6, func(t: float) -> void:
		_look(Vector3(-5.6, 1.15, -11.4), Vector3(0.0, 1.95, -11.9), 46.0)
		var walking := 1.0 - smoothstep(1.2, 1.4, t)
		var z: float = _k(t, [[0.0, -7.2], [1.4, -12.3]])
		var up: float = _k(t, [[1.55, 0.0], [1.95, 1.0], [2.4, 0.0]])
		key.rotation.y += (_k(t, [[1.9, 0.0], [2.3, 0.55], [4.6, 0.3]]) as float)
		_walk_cycle(0.7 * walking)
		if walking < 0.05:
			_stand_legs()
		var arms: float = _k(t, [[1.5, 0.0], [1.9, 3.0], [2.5, 3.0], [3.0, 1.6]])
		_pose(Vector3(0.0, up, z), PI, 0.0, _k(t, [[1.4, 1.0], [1.55, 0.84], [1.8, 1.1], [2.4, 1.0], [2.5, 0.88], [2.75, 1.0]]), arms, _k(t, [[1.9, 2.0], [2.2, 24.0]]))
		if walking > 0.05:
			_walk_cycle(0.0)
	)


func shot_wake() -> void:
	await _stage(0)
	_hide_cogs()
	var toys := _add_toys(-154.0)
	var hat := _make_hat(_model())
	hat.position = Vector3(0.0, 1.16, 0.02)
	hat.rotation.z = 0.2
	var teeth: ChatteringTeeth = toys["teeth"]
	var duck: RubberDuck = toys["duck"]
	teeth.set_physics_process(false)
	duck.set_physics_process(false)
	var teeth_base := teeth.position
	var duck_base := duck.position
	await _play(6.2, func(t: float) -> void:
		_dim(_k(t, [[0.0, 0.42], [1.3, 1.0]]))
		_look(Vector3(1.9, 1.05, -141.6), Vector3(0.0, 1.5, -150.2), 50.0)
		var awake := smoothstep(0.8, 1.6, t)
		teeth._upper.rotation.x = -0.25 - absf(sin(t * 18.0)) * 0.5 * awake
		teeth._key.rotation.z += 0.5 * awake
		teeth.position = teeth_base + Vector3.UP * absf(sin(t * 6.0)) * 0.7 * awake
		duck.position = duck_base + Vector3.UP * absf(sin(t * 4.6 + 1.0)) * 0.5 * awake
		duck._model.rotation.z = sin(t * 4.6) * 0.2 * awake
		var bounce := absf(sin(t * 5.2)) * 0.62 * awake
		var land := 1.0 + (0.12 * sin(t * 10.4)) * awake
		var legs := sin(t * 5.2) * 0.5 * awake
		_model()._left_leg.rotation.x = legs
		_model()._right_leg.rotation.x = -legs
		_pose(Vector3(0.0, bounce, -146.0), sin(t * 2.6) * 0.45, 0.0, land, 0.0, 2.0 + 10.0 * awake)
		_model()._left_arm.rotation.x = -2.5 * awake + sin(t * 10.4) * 0.5
		_model()._right_arm.rotation.x = -2.5 * awake - sin(t * 10.4) * 0.5
	)
	_dim(1.0)


func shot_even_him() -> void:
	await _stage(4)
	var boss := _baron()
	_baron_heap(boss)
	var hat := _make_hat(_model())
	hat.position = Vector3(0.0, 1.16, 0.02)
	hat.rotation.z = 0.2
	var wind := Node3D.new()
	boss._head.add_child(wind)
	wind.position = Vector3(0.0, 1.9, 0.0)
	var wind_key := MeshKit.windup_key(wind, "tock_brass", 1.9, false)
	wind_key.rotation.x = -PI / 2.0
	var spot := Vector3(-1.1, 7.2, -27.0)
	await _play(6.8, func(t: float) -> void:
		var pop: float = _k(t, [[1.3, 0.0], [1.5, 1.2], [1.65, 1.0]])
		wind.scale = Vector3.ONE * maxf(pop, 0.001)
		var going := smoothstep(1.7, 2.1, t)
		wind.rotation.y += (0.0 if t < 1.7 else 0.1 + 0.2 * going)
		var joy := smoothstep(2.2, 2.9, t)
		var head := BaronRust.HEAD_HEAP + Vector3(0.0, 0.8 * joy + absf(sin(t * 5.0)) * 0.3 * joy, 0.0)
		boss._head.position = head
		boss._head.rotation = Vector3(0.0, -0.2, sin(t * 5.0) * 0.13 * joy)
		var whisker: float = _k(t, [[2.0, 0.66], [2.55, -0.42], [2.9, -0.22]])
		boss._moustache_left.rotation.z = whisker
		boss._moustache_right.rotation.z = -whisker
		boss._left_fist.position.y = 6.9 + absf(sin(t * 5.0 + 0.7)) * 1.5 * joy
		boss._right_fist.position.y = 6.9 + absf(sin(t * 5.0)) * 1.3 * joy
		var from: Vector3 = _k(t, [[0.0, Vector3(1.2, 9.6, -17.6)], [6.8, Vector3(0.9, 9.3, -18.6)]])
		_look(from, Vector3(0.7, 9.0, -27.4), 38.0)
		_stand_legs()
		var hop := absf(sin(t * 5.0)) * 0.4 * smoothstep(3.1, 3.5, t)
		_pose(spot + Vector3.UP * hop, 1.45, 0.0, _k(t, [[1.1, 1.0], [1.28, 0.84], [1.48, 1.1], [1.75, 1.0]]), _k(t, [[0.9, 0.0], [1.3, 2.3], [1.9, 0.5], [3.1, 0.5], [3.5, 2.6]]), 3.0)
	)


## One still of Tock's face and key for the game icon. Crop the centre square.
func shot_icon() -> void:
	await _stage(0, true)
	_hide_cogs()
	await _play(2.0 / FPS, func(_t: float) -> void:
		var yaw := TITLE_YAW - 0.35
		_look(SPOT_BENCH + Vector3(0.0, 0.95, 2.05).rotated(Vector3.UP, yaw), SPOT_BENCH + Vector3.UP * 0.7, 30.0)
		_stand_legs()
		_pose(SPOT_BENCH, yaw - 0.5, 0.0, 1.0, 0.0, 0.0)
		_model()._right_arm.rotation.z = 2.35
	)


## One wide still of Tock on the bench with the course behind, for the store cover.
func shot_cover() -> void:
	await _stage(1, true)
	_hide_cogs()
	await _play(2.0 / FPS, func(_t: float) -> void:
		var yaw := 0.55
		_look(SPOT_BENCH + Vector3(0.0, 1.5, 4.6).rotated(Vector3.UP, yaw), SPOT_BENCH + Vector3(0.0, 1.3, -6.0), 44.0, -0.9)
		_stand_legs()
		_pose(SPOT_BENCH, yaw - 0.4, 0.0, 1.0, 0.0, 0.0)
		_model()._right_arm.rotation.z = 2.35
	)


func shot_endcard() -> void:
	await _stage(0, true)
	_hide_cogs()
	var hat := _make_hat(_model())
	hat.position = Vector3(0.0, 1.16, 0.02)
	hat.rotation.z = 0.2
	await _play(4.8, func(t: float) -> void:
		_bench_camera(TITLE_YAW + sin(t * 0.3) * 0.03)
		_stand_legs()
		_pose(SPOT_BENCH, TITLE_YAW - 0.45, 0.0, 1.0 + sin(t * 2.4) * 0.01, 0.0, 2.0)
		_model()._right_arm.rotation.x = 0.0
		_model()._left_arm.rotation.x = 0.0
		_model()._right_arm.rotation.z = 2.35 + sin(t * 8.0) * 0.4
	)
