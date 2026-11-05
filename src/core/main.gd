class_name Main
extends Node
## Owns the game's systems, passes them to each other, and runs the top-level flow.

var tuning: Tuning
var flow: GameFlow
var run_state: RunState
var level: Level
var player: Player
var camera: FollowCamera
var hud: Hud
var screens: Screens
var sfx: Sfx

var _respawn_point := Vector3.ZERO
var _level_data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.install()
	tuning = Tuning.load_from(Tuning.DEFAULT_PATH)
	_level_data = Tuning.load_json(Level.DEFAULT_PATH)
	run_state = RunState.new(tuning)
	run_state.extra_life_gained.connect(func() -> void: sfx.play("life"))
	flow = GameFlow.new()
	flow.state_changed.connect(_on_state_changed)

	sfx = Sfx.new()
	add_child(sfx)
	hud = Hud.new()
	add_child(hud)
	hud.bind(run_state)
	run_state.reset()
	hud.visible = false

	screens = Screens.new()
	add_child(screens)
	screens.start_requested.connect(start_game)
	screens.resume_requested.connect(func() -> void: flow.fire(GameFlow.Trigger.RESUME))
	screens.title_requested.connect(_return_to_title)
	screens.quit_requested.connect(func() -> void: get_tree().quit())

	_build_world()
	camera.title_orbit = true
	screens.show_for(flow.state, "")


func _physics_process(delta: float) -> void:
	if flow.state == GameFlow.State.PLAYING and run_state.tick(delta):
		player.die()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if flow.state == GameFlow.State.PLAYING:
		flow.fire(GameFlow.Trigger.PAUSE)
	elif flow.state == GameFlow.State.PAUSED:
		flow.fire(GameFlow.Trigger.RESUME)


## Starts a fresh run from the title, pause or end screens.
func start_game() -> void:
	_build_world()
	run_state.reset()
	if flow.fire(GameFlow.Trigger.START):
		hud.show_hint()


func _return_to_title() -> void:
	if flow.fire(GameFlow.Trigger.QUIT):
		_build_world()
		camera.title_orbit = true


func _build_world() -> void:
	if level != null:
		remove_child(level)
		level.queue_free()
	level = Level.new()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.build(_level_data, tuning)
	add_child(level)
	_respawn_point = level.spawn_point

	player = Player.new()
	player.setup(tuning)
	player.position = level.spawn_point
	level.add_child(player)
	camera = FollowCamera.new()
	camera.setup(tuning, player)
	level.add_child(camera)

	player.jumped.connect(func() -> void: sfx.play("jump"))
	player.hurt.connect(func() -> void: sfx.play("hurt"))
	player.died.connect(_on_player_died)
	level.cog_collected.connect(_on_cog_collected)
	level.life_collected.connect(run_state.add_life)
	level.power_collected.connect(func() -> void: sfx.play("power"))
	level.enemy_stomped.connect(_on_enemy_stomped)
	level.crate_broken.connect(_on_crate_broken)
	level.block_thudded.connect(func() -> void: sfx.play("thud"))
	level.reward_revealed.connect(func() -> void: sfx.play("reveal"))
	level.spring_used.connect(func() -> void: sfx.play("spring"))
	level.checkpoint_reached.connect(_on_checkpoint_reached)
	level.goal_reached.connect(_on_goal_reached)
	player.controls_enabled = flow.state == GameFlow.State.PLAYING


func _on_state_changed(state: GameFlow.State, _previous: GameFlow.State) -> void:
	var playing := state == GameFlow.State.PLAYING
	get_tree().paused = state == GameFlow.State.PAUSED
	player.controls_enabled = playing
	camera.title_orbit = state == GameFlow.State.TITLE
	hud.visible = state != GameFlow.State.TITLE
	var hide_mouse := playing or state == GameFlow.State.LIFE_LOST
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if hide_mouse else Input.MOUSE_MODE_VISIBLE
	screens.show_for(state, _summary(state))


func _summary(state: GameFlow.State) -> String:
	if state == GameFlow.State.LEVEL_CLEAR:
		return tr("Cogs %d of %d     Score %d") % [run_state.cogs, level.total_cogs, run_state.score]
	if state == GameFlow.State.GAME_OVER:
		return tr("Score %d") % run_state.score
	return ""


func _on_cog_collected() -> void:
	sfx.play("cog")
	run_state.add_cog()


func _on_enemy_stomped() -> void:
	sfx.play("stomp")
	run_state.add_stomp()


func _on_crate_broken() -> void:
	sfx.play("crate")
	run_state.add_crate()


func _on_checkpoint_reached(respawn_at: Vector3) -> void:
	_respawn_point = respawn_at
	sfx.play("checkpoint")


func _on_goal_reached() -> void:
	run_state.bank_time_bonus()
	if flow.fire(GameFlow.Trigger.CLEAR):
		sfx.play("clear")


func _on_player_died() -> void:
	if not flow.fire(GameFlow.Trigger.DIE):
		return
	sfx.play("die")
	var lives_remain := run_state.lose_life()
	await get_tree().create_timer(tuning.num("run", "respawn_delay_seconds")).timeout
	if flow.state != GameFlow.State.LIFE_LOST:
		return
	if not lives_remain:
		flow.fire(GameFlow.Trigger.OUT_OF_LIVES)
		return
	run_state.restart_timer()
	player.respawn(_respawn_point)
	camera.snap_to_target()
	flow.fire(GameFlow.Trigger.RESPAWN)
