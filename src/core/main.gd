class_name Main
extends Node
## Owns the game's systems, passes them to each other, and runs the top-level flow.

## Turns Tock three-quarters to the title camera, looking in towards the menu, in world degrees.
const TITLE_TOCK_YAW_DEGREES := -147.0
## Colorfulness of the world behind the Game Over screen, and how long it takes to get there.
const GAME_OVER_SATURATION := 0.35
const GAME_OVER_FADE_SECONDS := 0.4
## The ordered list of level files.
const CAMPAIGN_PATH := "res://assets/data/level_campaign.json"
## Played on launch, and after the last level's key. Made in video/.
const INTRO_FILM := "res://assets/video/tocks_workshop_intro.ogv"
const OUTRO_FILM := "res://assets/video/tocks_workshop_outro.ogv"

## Set false before adding to the tree to run without the films: tests and tools do. They are off by
## default with no display, where there is nobody to watch.
var films_enabled := DisplayServer.get_name() != "headless"
var film: FilmPlayer
## Where progress is saved. Empty keeps it in memory, the default with no display, so tests and
## tools never touch a player's save. Set before adding to the tree.
var progress_path := "" if DisplayServer.get_name() == "headless" else Progress.DEFAULT_PATH
var progress: Progress
var effects: Effects
## Which entry of the campaign is being played, from 0.
var level_index := 0
var tuning: Tuning
var flow: GameFlow
var run_state: RunState
var level: Level
var player: Player
var camera: FollowCamera
var hud: Hud
var screens: Screens
var sfx: Sfx
var ui_settings: UiSettings
var input_device: InputDeviceTracker

var _respawn_point := Vector3.ZERO
var _level_data: Dictionary = {}
var _campaign: Array = []
var _campaign_data: Dictionary = {}
var _ambience: TitleAmbience
var _saturation_tween: Tween
## The controller was removed and the player has not yet seen the pause menu that explains it.
var _gamepad_lost := false
## The level this run began on: "Restart run" and "New run" after a Game Over go back to it.
var _run_start_index := 0
## Golden gears collected on this attempt at the current level, not yet banked.
var _gears_this_level: Array[int] = []
var _last_clear: Progress.ClearResult
var _new_best_run := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.install()
	tuning = Tuning.load_from(Tuning.DEFAULT_PATH)
	_campaign_data = Tuning.load_json(CAMPAIGN_PATH)
	_campaign = _campaign_data["levels"]
	_level_data = Tuning.load_json(_campaign[0])
	var default_quality := GraphicsQuality.default_for(RenderingServer.get_video_adapter_name(), OS.has_feature("web"))
	ui_settings = UiSettings.load_from(UiSettings.DEFAULT_PATH, default_quality)
	ui_settings.changed.connect(_apply_settings)
	progress = Progress.load_from(progress_path, _campaign.size())
	run_state = RunState.new(tuning)
	run_state.extra_life_gained.connect(func() -> void: sfx.play("life"))
	flow = GameFlow.new()
	flow.state_changed.connect(_on_state_changed)

	sfx = Sfx.new()
	add_child(sfx)
	input_device = InputDeviceTracker.new()
	add_child(input_device)
	input_device.device_changed.connect(func(_kind: InputDeviceTracker.Kind) -> void: _update_mouse_mode())
	input_device.active_gamepad_lost.connect(_on_gamepad_lost)
	hud = Hud.new()
	add_child(hud)
	hud.bind(run_state)
	hud.bind_input(ui_settings, input_device)
	run_state.reset()
	hud.visible = false

	screens = Screens.new()
	add_child(screens)
	screens.bind(ui_settings, input_device)
	screens.start_requested.connect(_on_start_requested)
	screens.level_requested.connect(start_game)
	screens.next_requested.connect(next_level)
	screens.retry_requested.connect(retry_level)
	screens.resume_requested.connect(func() -> void: flow.fire(GameFlow.Trigger.RESUME))
	screens.title_requested.connect(_return_to_title)
	screens.quit_requested.connect(func() -> void: get_tree().quit())
	screens.reduced_motion_toggle_requested.connect(ui_settings.toggle_reduced_motion)
	screens.graphics_toggle_requested.connect(ui_settings.toggle_graphics_quality)
	screens.fullscreen_toggle_requested.connect(ui_settings.toggle_fullscreen)
	effects = Effects.new()
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects)

	# Added last, so it hears input first and nothing behind a film reacts.
	film = FilmPlayer.new()
	add_child(film)

	_build_world()
	_enter_title_view()
	_apply_graphics()
	_apply_fullscreen()
	_refresh_title_data()
	var show_title := func() -> void: screens.show_for(flow.state, "")
	if _films_wanted():
		_play_film(INTRO_FILM, show_title)
	else:
		show_title.call()


func _exit_tree() -> void:
	# The environment is shared and outlives this node.
	_reset_game_over_look()


func _physics_process(delta: float) -> void:
	if flow.state == GameFlow.State.PLAYING and run_state.tick(delta):
		player.die()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_F11 and event.is_pressed() and not event.is_echo():
		if _fullscreen_allowed():
			ui_settings.toggle_fullscreen()
		return
	if not event.is_action_pressed("pause"):
		return
	if flow.state == GameFlow.State.PLAYING:
		flow.fire(GameFlow.Trigger.PAUSE)
	elif flow.state == GameFlow.State.PAUSED:
		flow.fire(GameFlow.Trigger.RESUME)


## A film is a lot of motion to force on a player who asked for less, so reduced motion skips it.
func _films_wanted() -> bool:
	return films_enabled and not ui_settings.reduced_motion


## Plays a film over a stopped world, with no 3D drawn behind it, then carries on.
func _play_film(path: String, then: Callable) -> void:
	get_tree().paused = true
	get_viewport().disable_3d = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	film.play(path, func() -> void:
		get_tree().paused = false
		get_viewport().disable_3d = false
		_update_mouse_mode()
		then.call()
	)


## Starts a fresh run, from the title, pause or end screens. index picks the first level, for
## the level select; the run then carries on through the campaign as normal.
func start_game(index := 0) -> void:
	_run_start_index = clampi(index, 0, campaign_size() - 1)
	_new_best_run = false
	_last_clear = null
	load_level(_run_start_index)
	run_state.reset()
	run_state.enter_level(level.time_seconds)
	if flow.fire(GameFlow.Trigger.START):
		hud.new_run()
		hud.show_hint()
		_announce_level()


## Moves on from a cleared level, carrying Tock's form. Run totals carry in RunState.
func next_level() -> void:
	if flow.state != GameFlow.State.LEVEL_CLEAR:
		return
	var carried := player.form()
	load_level(mini(level_index + 1, campaign_size() - 1))
	player.restore_form(carried)
	run_state.enter_level(level.time_seconds)
	flow.fire(GameFlow.Trigger.NEXT)
	_announce_level()


## After a Game Over: replays this level from how it began, per design/expansion-spec.md section 2.
func retry_level() -> void:
	if flow.state != GameFlow.State.GAME_OVER:
		return
	load_level(level_index)
	run_state.rewind_to_level_entry()
	flow.fire(GameFlow.Trigger.RETRY)
	_announce_level()


## Builds a campaign level and makes it current. Run values and flow are the caller's to change.
func load_level(index: int) -> void:
	level_index = index
	_level_data = Tuning.load_json(_campaign[index])
	_build_world()
	# Level one's file is kept exactly as it shipped, so its jokes live in the campaign file.
	if index == 0:
		level.quip_clear = _campaign_data["first_level_quip_clear"]
		level.quip_over = _campaign_data["first_level_quip_over"]
	_gears_this_level.clear()
	level.add_golden_gears(golden_gear_positions(index), progress.gears_found(index))
	_update_gear_plaque()


## The golden gear positions of a campaign level, as [x, y, z] lists. Empty for none.
func golden_gear_positions(index: int) -> Array:
	var all: Array = _campaign_data.get("golden_gears", [])
	return all[index] if index >= 0 and index < all.size() else []


## Number of levels in the campaign.
func campaign_size() -> int:
	return _campaign.size()


func _announce_level() -> void:
	hud.show_level_banner(level_index + 1, campaign_size(), level.level_name)


func _return_to_title() -> void:
	if flow.fire(GameFlow.Trigger.QUIT):
		load_level(0)
		run_state.reset()
		_enter_title_view()


## Stages the world behind the title menu. The level rebuild at the next start undoes all of it.
func _enter_title_view() -> void:
	camera.title_shot = true
	player.rotation.y = deg_to_rad(TITLE_TOCK_YAW_DEGREES)
	_ambience = TitleAmbience.new()
	_ambience.setup(level, player.global_position)
	level.add_child(_ambience)
	_apply_motion_setting()


func _apply_settings() -> void:
	_apply_motion_setting()
	_apply_graphics()
	_apply_fullscreen()


func _apply_graphics() -> void:
	effects.set_scale_factor(GraphicsQuality.apply(get_viewport(), ui_settings.graphics_quality))


## The browser owns fullscreen, and a headless run has no window.
func _fullscreen_allowed() -> bool:
	return not OS.has_feature("web") and DisplayServer.get_name() != "headless"


func _apply_fullscreen() -> void:
	if not _fullscreen_allowed():
		return
	var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if ui_settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != wanted:
		DisplayServer.window_set_mode(wanted)


## Fills in what the title shows from saved progress: the level select and the best run.
func _refresh_title_data() -> void:
	var choices: Array[Dictionary] = []
	for index in progress.unlocked_count():
		choices.append({
			"name": Tuning.load_json(_campaign[index])["name"],
			"gears": progress.gears_found(index).size(),
			"gears_total": golden_gear_positions(index).size(),
			"best_time": progress.best_time(index),
		})
	screens.level_choices = choices
	screens.title_note = ""
	if progress.best_run_score > 0:
		screens.title_note = tr("Best run %d. Golden gears %d of %d.") % [progress.best_run_score, progress.total_gears_found(), _total_golden_gears()]


func _total_golden_gears() -> int:
	var total := 0
	for index in campaign_size():
		total += golden_gear_positions(index).size()
	return total


func _update_gear_plaque() -> void:
	var found := progress.gears_found(level_index)
	for gear in _gears_this_level:
		if not found.has(gear):
			found.append(gear)
	hud.set_golden_gears(found.size(), level.golden_gear_total)


func _apply_motion_setting() -> void:
	var motion := not ui_settings.reduced_motion
	effects.enabled = motion
	camera.sway_enabled = motion
	if is_instance_valid(_ambience):
		_ambience.set_motion_enabled(motion)
	if level.boss != null:
		level.boss.set_reduced_motion(not motion)


func _build_world() -> void:
	if level != null:
		remove_child(level)
		level.queue_free()
	_ambience = null
	level = Level.new()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.build(_level_data, tuning)
	add_child(level)
	_respawn_point = level.spawn_point

	player = Player.new()
	player.setup(tuning)
	player.position = level.spawn_point
	level.add_child(player)
	level.bind_player(player)
	camera = FollowCamera.new()
	camera.setup(tuning, player)
	level.add_child(camera)
	camera.apply_framing(level.camera_framing)

	player.jumped.connect(func() -> void: sfx.play("jump"))
	player.hurt.connect(func() -> void: sfx.play("hurt"))
	player.died.connect(_on_player_died)
	player.died.connect(level.on_player_died)
	player.power_spare.connect(run_state.add_spare_power)
	player.blaster.fired.connect(func() -> void: sfx.play("bolt_fire"))
	player.blaster.clinked.connect(func() -> void: sfx.play("bolt_clink"))
	level.blaster_collected.connect(func() -> void: sfx.play("blaster_get"))
	level.enemy_scored.connect(_on_enemy_scored)
	level.enemy_sound.connect(sfx.play)
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
	level.golden_gear_collected.connect(_on_golden_gear_collected)
	effects.follow(player)
	player.form_changed.connect(hud.set_form)
	hud.set_form(player.form())
	if level.boss != null:
		level.boss.hp_changed.connect(hud.set_boss_health)
		level.boss.defeated.connect(run_state.bank_time_bonus)
		level.boss.taunted.connect(func(line: String) -> void: hud.show_caption(tr(line)))
		hud.set_boss_health(level.boss.rules.hp, level.boss.rules.max_hp)
		_apply_motion_setting()
	else:
		hud.hide_boss_health()
	player.controls_enabled = flow.state == GameFlow.State.PLAYING
	camera.stick_enabled = _camera_follows_sticks(flow.state)


func _on_state_changed(state: GameFlow.State, _previous: GameFlow.State) -> void:
	var playing := state == GameFlow.State.PLAYING
	if state == GameFlow.State.TITLE:
		_refresh_title_data()
	get_tree().paused = state == GameFlow.State.PAUSED
	player.controls_enabled = playing
	camera.stick_enabled = _camera_follows_sticks(state)
	camera.title_shot = state == GameFlow.State.TITLE
	hud.visible = state != GameFlow.State.TITLE
	hud.set_menu_open(not _camera_follows_sticks(state))
	_update_mouse_mode()
	_update_game_over_look(state)
	screens.show_for(state, _summary(state), _result_score(state))
	# Still set in play only for the moment between a respawn and the pause that follows it.
	if state != GameFlow.State.LIFE_LOST and state != GameFlow.State.PLAYING:
		_gamepad_lost = false


func _camera_follows_sticks(state: GameFlow.State) -> bool:
	return state == GameFlow.State.PLAYING or state == GameFlow.State.LIFE_LOST


## Captured in play. In menus it hides while a controller is in use, and any mouse use brings it back.
func _update_mouse_mode() -> void:
	if _camera_follows_sticks(flow.state):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif input_device.kind == InputDeviceTracker.Kind.GAMEPAD:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _update_game_over_look(state: GameFlow.State) -> void:
	_reset_game_over_look()
	if state != GameFlow.State.GAME_OVER:
		return
	var environment := Look.environment()
	environment.adjustment_enabled = true
	if ui_settings.reduced_motion:
		environment.adjustment_saturation = GAME_OVER_SATURATION
		return
	_saturation_tween = create_tween()
	_saturation_tween.tween_property(environment, "adjustment_saturation", GAME_OVER_SATURATION, GAME_OVER_FADE_SECONDS)


func _reset_game_over_look() -> void:
	if _saturation_tween != null:
		_saturation_tween.kill()
		_saturation_tween = null
	var environment := Look.environment()
	environment.adjustment_enabled = false
	environment.adjustment_saturation = 1.0


func _summary(state: GameFlow.State) -> String:
	if state == GameFlow.State.LEVEL_CLEAR:
		var cleared := tr("%s: cogs %d of %d") % [level.level_name, run_state.level_cogs, level.total_cogs]
		return "%s\n%s\n%s" % [cleared, _clear_record_line(), tr(level.quip_clear)]
	if state == GameFlow.State.GAME_OVER:
		var stopped := tr("Stopped at level %d of %d") % [level_index + 1, campaign_size()]
		return "%s\n%s" % [stopped, tr(level.quip_over)]
	if state == GameFlow.State.VICTORY:
		var totals := tr("Cogs %d, lives %d, rewinds %d") % [run_state.cogs, run_state.lives, run_state.rewinds]
		var lines: Array[String] = [totals, _clear_record_line()]
		if _new_best_run:
			lines.append(tr("New best run!"))
		lines.append(tr(level.quip_clear))
		return "\n".join(lines)
	if state == GameFlow.State.PAUSED and _gamepad_lost:
		return tr("Controller disconnected. Plug it back in, or carry on with the keyboard.")
	return ""


func _result_score(state: GameFlow.State) -> int:
	if state in [GameFlow.State.LEVEL_CLEAR, GameFlow.State.GAME_OVER, GameFlow.State.VICTORY]:
		return run_state.score
	return -1


## Pauses rather than letting the clock run down with nothing in the player's hands.
func _on_gamepad_lost() -> void:
	if not _camera_follows_sticks(flow.state) or film.is_playing():
		return
	_gamepad_lost = true
	flow.fire(GameFlow.Trigger.PAUSE)


func _on_cog_collected() -> void:
	sfx.play("cog")
	run_state.add_cog()
	effects.burst(Effects.GLINT, player.global_position + Vector3.UP * 0.6)


func _on_enemy_stomped() -> void:
	sfx.play("stomp")
	run_state.add_stomp()
	effects.burst(Effects.SPARK, player.global_position)


## A ghost gear, banked on an earlier clear, still scores but is not counted again.
func _on_golden_gear_collected(index: int, ghost: bool, at: Vector3) -> void:
	sfx.play("reveal")
	run_state.add_score(int(tuning.num("score", "golden_gear")))
	effects.burst(Effects.GLINT, at)
	if not ghost and not _gears_this_level.has(index):
		_gears_this_level.append(index)
	_update_gear_plaque()


func _on_enemy_scored(points: int, sound: String) -> void:
	sfx.play(sound)
	run_state.add_score(points)


func _on_crate_broken() -> void:
	sfx.play("crate")
	run_state.add_crate()


func _on_checkpoint_reached(respawn_at: Vector3) -> void:
	_respawn_point = respawn_at
	sfx.play("checkpoint")


## Golden gears and time for the level just cleared, such as "Golden gears 2 of 3. Time 1:23.4".
func _clear_record_line() -> String:
	if _last_clear == null:
		return ""
	var parts: Array[String] = []
	if level.golden_gear_total > 0:
		parts.append(tr("Golden gears %d of %d.") % [_last_clear.gears_found, level.golden_gear_total])
	var time := tr("Time %s.") % Screens.format_time(run_state.level_elapsed)
	if _last_clear.new_best_time:
		time += " " + tr("New best!")
	parts.append(time)
	return " ".join(parts)


func _on_start_requested() -> void:
	var from_top := flow.state == GameFlow.State.TITLE or flow.state == GameFlow.State.VICTORY
	start_game(0 if from_top else _run_start_index)


## The last level's key ends the run; any other key ends the level.
func _on_goal_reached() -> void:
	# The key's area spins, so it can sweep over a Tock who has just died.
	if flow.state != GameFlow.State.PLAYING or film.is_playing():
		return
	run_state.bank_time_bonus()
	_last_clear = progress.record_clear(level_index, run_state.level_elapsed, _gears_this_level)
	if level_index >= campaign_size() - 1:
		run_state.bank_victory_bonus()
		_new_best_run = progress.record_victory(run_state.score, _run_start_index == 0)
		if _films_wanted():
			_play_film(OUTRO_FILM, _win)
		else:
			_win()
	elif flow.fire(GameFlow.Trigger.CLEAR):
		sfx.play("clear")


func _win() -> void:
	if flow.fire(GameFlow.Trigger.WIN):
		sfx.play("win")


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
	level.on_player_respawned()
	camera.snap_to_target()
	flow.fire(GameFlow.Trigger.RESPAWN)
	if _gamepad_lost:
		flow.fire(GameFlow.Trigger.PAUSE)
