extends RefCounted
## Runs the real game scene with real physics. A bot replaces the player's input.


func _key_event(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event


func test_real_key_events_move_and_jump_tock(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	var start := main.player.global_position
	Input.parse_input_event(_key_event(KEY_W, true))
	Input.flush_buffered_events()
	await t.wait_ticks(20)
	Input.parse_input_event(_key_event(KEY_W, false))
	Input.flush_buffered_events()
	t.is_true(main.player.global_position.z < start.z - 0.5, "W moves away from the camera")
	await t.wait_ticks(20)
	var ground_y := main.player.global_position.y
	Input.parse_input_event(_key_event(KEY_SPACE, true))
	Input.flush_buffered_events()
	var rose := await t.wait_until(func() -> bool: return main.player.global_position.y > ground_y + 1.0, 30)
	Input.parse_input_event(_key_event(KEY_SPACE, false))
	Input.flush_buffered_events()
	t.is_true(rose, "Space jumps")
	await t.stop_game(main)


func test_escape_key_pauses_and_resumes(t: TestKit) -> void:
	var main: Main = await t.start_game()
	Input.parse_input_event(_key_event(KEY_ESCAPE, true))
	Input.flush_buffered_events()
	Input.parse_input_event(_key_event(KEY_ESCAPE, false))
	Input.flush_buffered_events()
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.PAUSED, "paused by Esc")
	Input.parse_input_event(_key_event(KEY_ESCAPE, true))
	Input.flush_buffered_events()
	Input.parse_input_event(_key_event(KEY_ESCAPE, false))
	Input.flush_buffered_events()
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "resumed by Esc")
	await t.stop_game(main)


func test_title_start_button_begins_a_run(t: TestKit) -> void:
	var main: Main = (load(TestKit.MAIN_SCENE) as PackedScene).instantiate()
	t.tree.root.add_child(main)
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.TITLE, "starts on title")
	var buttons := main.screens.find_children("*", "Button", true, false)
	t.is_true(buttons.size() >= 1, "title has buttons")
	(buttons[0] as Button).pressed.emit()
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "Start button starts the run")
	await t.stop_game(main)


func test_jump_reaches_configured_height(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	var start_y := main.player.global_position.y
	var command := t.drive(main, Vector3.ZERO, true)
	await t.wait_ticks(1)
	command.jump_pressed = false
	var peak := start_y
	for _i in 60:
		peak = maxf(peak, main.player.global_position.y)
		await t.wait_ticks(1)
	t.near(peak - start_y, main.tuning.num("player", "jump_height_small"), 0.25, "jump height")
	await t.stop_game(main)


func test_releasing_jump_early_gives_shorter_jump(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	var start_y := main.player.global_position.y
	var command := t.drive(main, Vector3.ZERO, true)
	await t.wait_ticks(2)
	command.jump_pressed = false
	command.jump_held = false
	var peak := start_y
	for _i in 60:
		peak = maxf(peak, main.player.global_position.y)
		await t.wait_ticks(1)
	t.is_true(peak - start_y < main.tuning.num("player", "jump_height_small") * 0.5, "short hop")
	await t.stop_game(main)


func test_walking_moves_at_walk_speed(t: TestKit) -> void:
	var main: Main = await t.start_game()
	t.drive(main, Vector3.FORWARD)
	await t.wait_ticks(40)
	var speed := Vector2(main.player.velocity.x, main.player.velocity.z).length()
	t.near(speed, main.tuning.num("player", "walk_speed"), 0.1, "walk speed")
	await t.stop_game(main)


func test_cog_pickup_adds_cog_and_score(t: TestKit) -> void:
	var main: Main = await t.start_game()
	main.player.global_position = Vector3(0.0, 0.2, -4.0)
	await t.wait_ticks(5)
	t.equal(main.run_state.cogs, 1, "cogs")
	t.equal(main.run_state.score, int(main.tuning.num("run", "score_per_cog")), "score")
	await t.stop_game(main)


func test_stomp_removes_beetle_scores_and_bounces(t: TestKit) -> void:
	var main: Main = await t.start_game()
	var beetle: GearBeetle = main.level.beetles[0]
	beetle.speed = 0.0
	var lives := main.run_state.lives
	var beetles_before := main.level.beetles.size()
	main.player.global_position = beetle.global_position + Vector3.UP * 2.5
	var hit := await t.wait_until(func() -> bool: return main.player.velocity.y > 1.0, 90)
	t.is_true(hit, "bounced upward")
	t.equal(main.run_state.score, int(main.tuning.num("run", "score_per_stomp")), "score")
	t.equal(main.run_state.lives, lives, "no life lost")
	await t.wait_ticks(40)
	t.equal(main.level.beetles.size(), beetles_before - 1, "beetle removed")
	await t.stop_game(main)


func test_small_tock_walking_into_beetle_loses_life_then_respawns(t: TestKit) -> void:
	var main: Main = await t.start_game()
	var beetle: GearBeetle = main.level.beetles[0]
	beetle.speed = 0.0
	var lives := main.run_state.lives
	main.player.global_position = beetle.global_position + Vector3(0.0, 0.2, 2.5)
	t.drive(main, Vector3.FORWARD)
	var died := await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.LIFE_LOST, 120)
	t.is_true(died, "life lost state")
	t.equal(main.run_state.lives, lives - 1, "lives")
	var back := await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.PLAYING, 180)
	t.is_true(back, "respawned")
	t.is_true(main.player.alive, "alive")
	t.near(main.player.global_position.z, main.level.spawn_point.z, 2.0, "back at spawn")
	await t.stop_game(main)


func test_coil_block_grants_power_and_coiled_hit_only_shrinks(t: TestKit) -> void:
	var main: Main = await t.start_game()
	main.level.remove_enemies()
	await t.wait_ticks(2)
	main.player.global_position = Vector3(0.0, 0.2, -14.0)
	await t.wait_ticks(15)
	var command := t.drive(main, Vector3.ZERO, true)
	await t.wait_ticks(1)
	command.jump_pressed = false
	var coiled := await t.wait_until(func() -> bool: return main.player.is_coiled(), 180)
	t.is_true(coiled, "Coil Spring collected from falling reward")
	var lives := main.run_state.lives
	main.player.take_hit()
	await t.wait_ticks(2)
	t.is_true(not main.player.is_coiled(), "shrunk")
	t.equal(main.run_state.lives, lives, "no life lost")
	t.is_true(main.player.is_invulnerable(), "invulnerable")
	await t.stop_game(main)


func test_crate_survives_small_bump_and_breaks_when_coiled(t: TestKit) -> void:
	var main: Main = await t.start_game()
	main.level.remove_enemies()
	var crate: SurpriseBlock = main.level.blocks[2]
	t.equal(crate.kind, "crate", "fixture is a crate")
	await t.wait_ticks(2)
	main.player.global_position = Vector3(crate.position.x, 0.2, crate.position.z)
	await t.wait_ticks(15)
	var command := t.drive(main, Vector3.ZERO, true)
	await t.wait_ticks(1)
	command.jump_pressed = false
	await t.wait_ticks(70)
	t.is_true(is_instance_valid(crate), "small bump leaves crate")
	t.equal(main.run_state.score, 0, "no crate score yet")
	main.player.apply_power_up()
	await t.wait_ticks(5)
	command.jump_pressed = true
	await t.wait_ticks(1)
	command.jump_pressed = false
	var crate_score := int(main.tuning.num("run", "score_per_crate"))
	var broken := await t.wait_until(func() -> bool: return main.run_state.score == crate_score, 120)
	t.is_true(broken, "coiled bump scores the crate")
	await t.wait_ticks(20)
	t.is_true(not is_instance_valid(crate), "crate removed")
	await t.stop_game(main)


func test_hidden_block_lets_tock_fall_through_but_reveals_from_below(t: TestKit) -> void:
	var main: Main = await t.start_game()
	main.level.remove_enemies()
	var hidden: SurpriseBlock = null
	for block in main.level.blocks:
		if block.is_hidden_block and block.kind == "life":
			hidden = block
	t.is_true(hidden != null, "fixture exists")
	await t.wait_ticks(2)
	main.player.global_position = hidden.position + Vector3.UP * 3.0
	var fell := await t.wait_until(
		func() -> bool: return main.player.global_position.y < 0.5 and main.player.is_on_floor(), 120
	)
	t.is_true(fell, "fell through from above")
	t.is_true(hidden.is_hidden_block, "still hidden after falling through")
	var lives := main.run_state.lives
	var command := t.drive(main, Vector3.ZERO, true)
	await t.wait_ticks(1)
	command.jump_pressed = false
	var revealed := await t.wait_until(func() -> bool: return not hidden.is_hidden_block, 60)
	t.is_true(revealed, "revealed from below")
	var extra_life := await t.wait_until(func() -> bool: return main.run_state.lives == lives + 1, 180)
	t.is_true(extra_life, "spare key collected")
	await t.stop_game(main)


func test_falling_off_respawns_at_latest_checkpoint(t: TestKit) -> void:
	var main: Main = await t.start_game()
	main.level.remove_enemies()
	await t.wait_ticks(2)
	main.player.global_position = Vector3(0.0, 0.2, -66.0)
	await t.wait_ticks(5)
	main.player.global_position = Vector3(40.0, 0.0, -66.0)
	var died := await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.LIFE_LOST, 240)
	t.is_true(died, "fall lost a life")
	await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.PLAYING, 180)
	t.near(main.player.global_position.z, -66.0, 1.0, "respawned at checkpoint")
	await t.stop_game(main)


func test_last_life_leads_to_game_over(t: TestKit) -> void:
	var main: Main = await t.start_game()
	while main.run_state.lives > 1:
		main.run_state.lose_life()
	main.player.die()
	var over := await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.GAME_OVER, 180)
	t.is_true(over, "game over")
	await t.stop_game(main)


func test_timer_running_out_costs_a_life_and_restarts_timer(t: TestKit) -> void:
	var main: Main = await t.start_game()
	var lives := main.run_state.lives
	main.run_state.time_left = 0.05
	var died := await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.LIFE_LOST, 30)
	t.is_true(died, "time up")
	t.equal(main.run_state.lives, lives - 1, "lives")
	await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.PLAYING, 180)
	t.is_true(main.run_state.time_left > 100.0, "timer restored")
	await t.stop_game(main)


func test_pause_stops_timer_and_world_then_resumes(t: TestKit) -> void:
	var main: Main = await t.start_game()
	t.is_true(main.flow.fire(GameFlow.Trigger.PAUSE), "paused")
	t.is_true(t.tree.paused, "tree paused")
	var time_before := main.run_state.time_left
	var platform_before: Vector3 = main.level.moving_platforms[0].position
	await t.wait_ticks(20)
	t.equal(main.run_state.time_left, time_before, "timer frozen")
	t.equal(main.level.moving_platforms[0].position, platform_before, "world frozen")
	t.is_true(main.flow.fire(GameFlow.Trigger.RESUME), "resumed")
	t.is_true(not t.tree.paused, "tree running")
	await t.wait_ticks(5)
	t.is_true(main.run_state.time_left < time_before, "timer running")
	await t.stop_game(main)


func test_moving_platform_carries_tock(t: TestKit) -> void:
	var main: Main = await t.start_game()
	var platform: Node3D = main.level.moving_platforms[0]
	main.player.global_position = platform.global_position + Vector3.UP * 0.6
	await t.wait_ticks(120)
	t.near(main.player.global_position.z, platform.global_position.z, 0.5, "stays on platform")
	t.is_true(main.player.global_position.y > -0.5, "did not fall")
	t.is_true(platform.global_position.z < -54.6, "platform moved")
	await t.stop_game(main)


func test_full_course_can_be_finished_by_a_bot(t: TestKit) -> void:
	var main: Main = await t.start_game()
	main.level.remove_enemies()
	await t.wait_ticks(2)
	var platform: Node3D = main.level.moving_platforms[0]
	var platform_center := func() -> Vector3: return platform.global_position
	var platform_near := func() -> bool: return platform.global_position.z > -55.0
	var platform_far := func() -> bool: return platform.global_position.z < -60.0
	var steps: Array[Dictionary] = [
		{ "to": Vector3(0, 0, -29.0), "jump": true },
		{ "to": Vector3(0, 0, -50.5), "jump": true, "wait": platform_near },
		{ "to": platform_center, "jump": true, "wait": platform_far },
		{ "to": Vector3(0, 0, -76.0), "radius": 1.5, "no_floor": true },
		{ "to": Vector3(0, 0, -85.0), "radius": 2.0 },
		{ "to": Vector3(2, 0, -95.0), "jump": true },
		{ "to": Vector3(2, 0, -100.0), "jump": true, "radius": 1.0 },
		{ "to": Vector3(-2, 0, -105.0), "jump": true, "radius": 1.0 },
		{ "to": Vector3(2, 0, -110.0), "jump": true, "radius": 1.0 },
		{ "to": Vector3(-2, 0, -115.0), "jump": true, "radius": 1.0 },
		{ "to": Vector3(0, 0, -120.0), "jump": true, "radius": 1.0 },
		{ "to": Vector3(0, 0, -128.0), "radius": 2.0 },
		{ "to": Vector3(0, 0, -160.0), "radius": 0.5 },
	]
	var command := t.drive(main)
	command.run = true
	var index := 0
	for _tick in 5400:
		if main.flow.state != GameFlow.State.PLAYING:
			break
		command.jump_pressed = false
		command.jump_held = true
		var step: Dictionary = steps[mini(index, steps.size() - 1)]
		var target: Vector3 = step["to"].call() if step["to"] is Callable else step["to"]
		var to_target := target - main.player.global_position
		to_target.y = 0.0
		var distance := to_target.length()
		command.move = to_target.normalized() * clampf(distance / 2.0, 0.0, 1.0) if distance > 0.1 else Vector3.ZERO
		var grounded: bool = main.player.is_on_floor() or step.get("no_floor", false)
		var ready: bool = not step.has("wait") or step["wait"].call()
		if distance < step.get("radius", 1.0) and grounded and ready:
			command.jump_pressed = step.get("jump", false)
			index += 1
		await t.wait_ticks(1)
	t.equal(main.flow.state, GameFlow.State.LEVEL_CLEAR, "level cleared at step %d, position %s" % [index, main.player.global_position])
	t.equal(main.run_state.lives, int(main.tuning.num("run", "starting_lives")), "no lives lost")
	t.is_true(main.run_state.cogs > 0, "collected cogs along the route")
	await t.stop_game(main)
