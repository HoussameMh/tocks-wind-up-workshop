extends RefCounted
## Baron Rust in the real game, design/expansion-spec.md section 8, criterion 11.

const LAST_LEVEL := 4


func _start(t: TestKit) -> Main:
	return await t.start_level(LAST_LEVEL)


## Keeps Tock safe from hazards, so a test can look at one thing at a time.
func _shield(main: Main) -> void:
	main.player._power.invulnerable_left = 5.0


func _wait_for_state(t: TestKit, main: Main, state: BaronRust.State, max_ticks: int) -> bool:
	for _i in max_ticks:
		_shield(main)
		if main.level.boss.state == state:
			return true
		await t.wait_ticks(1)
	return main.level.boss.state == state


## Stomps through one window: runs under the spot, jumps, and waits for the health to drop.
func _stomp_window(t: TestKit, main: Main) -> bool:
	var boss := main.level.boss
	if not await _wait_for_state(t, main, BaronRust.State.EXPOSED, 1800):
		return false
	var before := boss.rules.hp
	var command := t.drive(main)
	var spot := Vector3(BaronRust.WEAK_SPOT.x, main.player.global_position.y, BaronRust.WEAK_SPOT.z)
	for _i in 300:
		_shield(main)
		if boss.rules.hp < before:
			command.move = Vector3.ZERO
			command.jump_pressed = false
			return true
		var to_spot := spot - main.player.global_position
		to_spot.y = 0.0
		command.run = true
		command.move = to_spot.normalized() if to_spot.length() > 0.2 else Vector3.ZERO
		command.jump_pressed = main.player.is_on_floor() and to_spot.length() < 0.6
		command.jump_held = true
		await t.wait_ticks(1)
	return false


func test_stomp_only_bot_wins_in_six_windows_through_the_key(t: TestKit) -> void:
	var main: Main = await _start(t)
	var boss := main.level.boss
	t.is_true(boss != null, "the boss exists")
	t.is_true(main.hud.boss_gauge_visible(), "gauge showing")
	t.equal(main.hud.boss_gauge_hp(), 18, "gauge full")
	var windows := 0
	while not boss.rules.is_defeated() and windows < 10:
		t.is_true(await _stomp_window(t, main), "window %d lands a stomp" % windows)
		windows += 1
	t.equal(windows, 6, "six windows")
	t.equal(main.hud.boss_gauge_hp(), 0, "gauge empty")
	t.equal(boss.state, BaronRust.State.DEFEAT, "defeated")
	t.equal(main.flow.state, GameFlow.State.PLAYING, "no win until the key is touched")
	await _wait_for_state(t, main, BaronRust.State.DONE, 300)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "still no win when the key appears")
	t.drive(main, Vector3.ZERO)
	main.player.global_position = Vector3(0.0, 0.2, -13.0)
	var won := await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.VICTORY, 30)
	t.is_true(won, "the key wins")
	await t.stop_game(main)


## The fight is fair: with no shield at all, a bot that only jumps rings and bars, keeps moving and
## runs in when the head comes down can win. It gets a few spare lives, since it never learns.
func test_unshielded_bot_can_win_by_dodging_and_stomping(t: TestKit) -> void:
	var main: Main = await _start(t)
	main.run_state.lives = 9
	var boss := main.level.boss
	var hazards := boss.hazards
	var command := t.drive(main)
	command.run = true
	var patrol_side := 1.0
	var deaths: Array[String] = []
	var note_death := func() -> void:
		deaths.append("hp%d state%d attack%d" % [boss.rules.hp, boss.state, boss._attack])
	main.player.died.connect(note_death)
	for _i in 60 * 280:
		if boss.rules.is_defeated() or main.flow.state == GameFlow.State.GAME_OVER:
			break
		command.jump_pressed = false
		command.jump_held = true
		var feet := main.player.global_position
		var goal := Vector3(patrol_side * 9.0, feet.y, -7.0)
		var teeth_gap := INF
		boss._prune_teeth()
		for set_of_teeth in boss.teeth:
			var gap := feet.distance_to(set_of_teeth.global_position)
			if gap < teeth_gap and gap < 5.0:
				teeth_gap = gap
				# Teeth hop far slower than Tock runs, so the bot just leaves.
				var away: Vector3 = (feet - set_of_teeth.global_position).normalized() * 6.0
				goal = feet + away
				goal.x = clampf(goal.x, -11.0, 11.0)
				goal.z = clampf(goal.z, -22.0, -3.0)
		if boss.is_exposed():
			goal = Vector3(BaronRust.WEAK_SPOT.x, feet.y, BaronRust.WEAK_SPOT.z)
		elif absf(feet.x - goal.x) < 1.0 and teeth_gap == INF:
			patrol_side = -patrol_side
		var to_goal := goal - feet
		to_goal.y = 0.0
		command.move = to_goal.normalized() if to_goal.length() > 0.2 else Vector3.ZERO
		if main.player.is_on_floor():
			var ring := hazards.ring_radius()
			var ring_gap := Vector2(feet.x, feet.z + 25.0).length() - ring
			var bar_gap := absf(feet.x - hazards.sweep_x)
			var ring_near := ring >= 0.0 and ring_gap > 0.0 and ring_gap < 2.2
			var bar_near := hazards.sweep_active and bar_gap < 2.4
			var at_spot := boss.is_exposed() and to_goal.length() < 0.6
			command.jump_pressed = ring_near or bar_near or at_spot
		await t.wait_ticks(1)
	t.is_true(boss.rules.is_defeated(), "fight won, %d health left, deaths: %s" % [boss.rules.hp, deaths])
	await t.stop_game(main)


func test_blaster_bot_wins_with_bolts_alone(t: TestKit) -> void:
	var main: Main = await _start(t)
	var boss := main.level.boss
	main.player.apply_blaster_power()
	var spot := Vector3(0.0, 0.2, -18.0)
	var command := t.drive(main)
	for _i in 12000:
		_shield(main)
		if boss.rules.is_defeated():
			break
		main.player.global_position = spot
		main.player.velocity = Vector3.ZERO
		main.player.apply_blaster_power()
		command.move = Vector3.FORWARD * 0.01
		command.fire_pressed = boss.is_exposed()
		await t.wait_ticks(1)
	t.is_true(boss.rules.is_defeated(), "bolts win the fight, at %d health" % boss.rules.hp)
	await t.stop_game(main)


func test_window_damage_is_capped_and_a_closed_head_takes_none(t: TestKit) -> void:
	var main: Main = await _start(t)
	var boss := main.level.boss
	boss.take_bolt()
	t.equal(boss.rules.hp, 18, "a closed head takes nothing")
	t.is_true(not boss._weak_spot.is_in_group(BoltBlaster.TARGET_GROUP), "and cannot be aimed at")
	await _wait_for_state(t, main, BaronRust.State.EXPOSED, 1800)
	t.is_true(boss._weak_spot.is_in_group(BoltBlaster.TARGET_GROUP), "an open head can be aimed at")
	for _i in 5:
		boss.take_bolt()
	t.equal(boss.rules.hp, 15, "a window gives three")
	t.equal(boss.state, BaronRust.State.RAISE, "and closes")
	t.is_true(not boss._weak_spot.is_in_group(BoltBlaster.TARGET_GROUP), "cannot be aimed at again")
	await t.stop_game(main)


func test_each_phase_runs_its_attack_list_with_spec_timing(t: TestKit) -> void:
	var main: Main = await _start(t)
	var boss := main.level.boss
	# Phase 1: three slams (tell 1.2, recover 1.5) before the droop.
	var ticks := 0
	while boss.state == BaronRust.State.ATTACK and ticks < 1200:
		_shield(main)
		await t.wait_ticks(1)
		ticks += 1
	t.near(ticks / 60.0, 8.1, 0.15, "phase 1 attacks last 8.1 s")
	t.equal(boss.state, BaronRust.State.DROOP, "droops")
	var loop := 0
	while boss.state != BaronRust.State.ATTACK and loop < 1200:
		_shield(main)
		await t.wait_ticks(1)
		loop += 1
	t.near(loop / 60.0, 6.8, 0.15, "droop, 5 s window and raise")
	await t.stop_game(main)


func test_slam_ring_hurts_on_the_floor_and_a_jump_clears_it(t: TestKit) -> void:
	var main: Main = await _start(t)
	var boss := main.level.boss
	var spot := Vector3(0.0, 0.2, -14.0)
	main.player.global_position = spot
	var hurt := {"yes": false}
	main.player.hurt.connect(func() -> void: hurt["yes"] = true)
	main.player.apply_power_up()
	var command := t.drive(main)
	var distance := spot.distance_to(BaronRust.RING_ORIGIN)
	await t.wait_until(func() -> bool: return boss.hazards.ring_radius() > distance - 3.0, 400)
	t.is_true(not hurt["yes"], "not hurt before the ring arrives")
	command.jump_pressed = true
	command.jump_held = true
	await t.wait_ticks(1)
	command.jump_pressed = false
	await t.wait_until(func() -> bool: return boss.hazards.ring_radius() > distance + 3.0 or boss.hazards.ring_radius() < 0.0, 120)
	t.is_true(not hurt["yes"], "a jump clears the ring")
	command.jump_held = false
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 120)
	await t.wait_until(func() -> bool: return boss.hazards.rings_alive() > 0 and boss.hazards.ring_radius() > distance + 0.8, 500)
	await t.wait_until(func() -> bool: return hurt["yes"] or boss.hazards.rings_alive() == 0, 200)
	await t.stop_game(main)


func test_standing_still_on_the_floor_is_hit_by_the_ring(t: TestKit) -> void:
	var main: Main = await _start(t)
	var boss := main.level.boss
	main.player.global_position = Vector3(0.0, 0.2, -14.0)
	main.player.apply_power_up()
	t.drive(main)
	var hit := await t.wait_until(func() -> bool: return main.player.form() == PowerState.Form.SMALL, 400)
	t.is_true(hit, "ring takes the coil")
	t.is_true(boss.hazards.rings_alive() > 0, "the ring did it")
	await t.stop_game(main)


func test_lob_lands_on_the_marker_and_two_metres_clear_it(t: TestKit) -> void:
	var main: Main = await _start(t)
	var boss := main.level.boss
	boss.set_physics_process(false)
	main.player.apply_power_up()
	t.drive(main)
	var target := Vector3(5.0, 0.0, -10.0)
	main.player.global_position = target + Vector3(2.0, 0.2, 0.0)
	boss.hazards.throw_lob(BaronRust.HAND_FROM, target)
	t.equal(boss.hazards.lobs_alive(), 1, "in the air")
	await t.wait_ticks(int(main.tuning.num("boss", "lob_flight") * 60.0) + 3)
	t.equal(main.player.form(), PowerState.Form.COILED, "two metres away is safe")
	main.player.global_position = target + Vector3(0.5, 0.2, 0.0)
	await t.wait_ticks(1)
	boss.hazards.throw_lob(BaronRust.HAND_FROM, target)
	await t.wait_ticks(int(main.tuning.num("boss", "lob_flight") * 60.0) + 3)
	t.equal(main.player.form(), PowerState.Form.SMALL, "on the marker hurts")
	await t.stop_game(main)


func test_sweep_hurts_on_the_floor_and_bounces_a_landing(t: TestKit) -> void:
	var main: Main = await _start(t)
	var boss := main.level.boss
	# Just this one hazard: the Baron's own attack list would land hits of its own.
	boss.set_physics_process(false)
	var hazards := boss.hazards
	main.player.apply_power_up()
	t.drive(main)
	main.player.global_position = Vector3(0.0, 0.2, -14.0)
	hazards.start_sweep()
	var hit := await t.wait_until(func() -> bool: return main.player.form() == PowerState.Form.SMALL, 500)
	t.is_true(hit, "the bar hurts a grounded Tock")
	await t.wait_until(func() -> bool: return not hazards.sweep_active, 400)
	main.player._power.invulnerable_left = 0.0
	hazards.start_sweep()
	await t.wait_until(func() -> bool: return absf(hazards.sweep_x) < 6.0 and hazards.sweep_active, 400)
	main.player.global_position = Vector3(hazards.sweep_x, 1.02, -14.0)
	main.player.velocity = Vector3.DOWN * 3.0
	main.player.apply_power_up()
	var bounced := await t.wait_until(func() -> bool: return main.player.velocity.y > 1.0, 20)
	t.is_true(bounced, "landing on the bar bounces")
	t.equal(main.player.form(), PowerState.Form.COILED, "unhurt")
	await t.stop_game(main)


func test_death_in_phase_two_restores_twelve_and_rearms_boxes(t: TestKit) -> void:
	var main: Main = await _start(t)
	var boss := main.level.boss
	boss.rules.hp = 9
	boss._phase = 1
	var box: SurpriseBlock = main.level.blocks[0]
	box.bump(false)
	t.is_true(box.used, "box used")
	main.player.die()
	var back := await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.PLAYING, 120)
	t.is_true(back, "respawned")
	t.equal(boss.rules.hp, 12, "health back to the phase's start")
	t.equal(main.hud.boss_gauge_hp(), 12, "gauge agrees")
	t.equal(boss.phase(), 1, "phase kept")
	t.equal(boss.state, BaronRust.State.GRACE, "the Baron has a laugh first")
	t.is_true(not box.used, "boxes re-armed")
	await t.stop_game(main)


func test_game_over_retry_restarts_the_fight_from_the_top(t: TestKit) -> void:
	var main: Main = await _start(t)
	main.level.boss.rules.hp = 5
	main.run_state.lives = 1
	main.player.die()
	var over := await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.GAME_OVER, 120)
	t.is_true(over, "game over")
	main.retry_level()
	await t.wait_ticks(2)
	t.equal(main.level.boss.rules.hp, 18, "full health")
	t.equal(main.level.boss.phase(), 0, "first phase")
	t.equal(main.hud.boss_gauge_hp(), 18, "gauge full")
	await t.stop_game(main)


func test_phase_break_clears_hazards_and_teeth_then_starts_the_next_phase(t: TestKit) -> void:
	var main: Main = await _start(t)
	var boss := main.level.boss
	boss.rules.hp = 13
	await _wait_for_state(t, main, BaronRust.State.EXPOSED, 1800)
	var teeth := main.level.add_teeth({"pos": [6.0, 0.0, -14.0]})
	boss.teeth.append(teeth)
	boss.hazards.start_ring()
	boss.take_bolt()
	t.equal(boss.rules.hp, 12, "phase boundary reached")
	t.equal(boss.state, BaronRust.State.BREAK, "phase break")
	t.equal(boss.hazards.rings_alive(), 0, "hazards gone")
	await t.wait_ticks(1)
	t.is_true(not is_instance_valid(teeth), "teeth gone")
	await _wait_for_state(t, main, BaronRust.State.ATTACK, 300)
	t.equal(boss.phase(), 1, "next phase")
	await t.stop_game(main)


func test_win_pays_the_end_bonuses_and_stops_the_clock(t: TestKit) -> void:
	var main: Main = await _start(t)
	var boss := main.level.boss
	boss.rules.hp = 1
	boss._phase = 2
	await _wait_for_state(t, main, BaronRust.State.EXPOSED, 3000)
	var time_at_hit := main.run_state.time_left
	boss.take_bolt()
	t.equal(boss.state, BaronRust.State.DEFEAT, "defeated")
	await _wait_for_state(t, main, BaronRust.State.DONE, 300)
	t.near(main.run_state.time_left, time_at_hit, 0.05, "clock stopped at the final blow")
	var before := main.run_state.score
	t.drive(main, Vector3.ZERO)
	main.player.global_position = Vector3(0.0, 0.2, -13.0)
	await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.VICTORY, 30)
	var expected := main.run_state.lives * int(main.tuning.num("score", "per_life_at_win"))
	expected += int(main.tuning.num("score", "no_rewind"))
	t.equal(main.run_state.score - before, expected, "lives and clean-run bonus")
	await t.stop_game(main)


func test_arena_walls_hold_tock_and_let_the_camera_and_bolts_through(t: TestKit) -> void:
	var main: Main = await _start(t)
	main.player.global_position = Vector3(11.0, 0.2, -13.0)
	t.drive(main, Vector3.RIGHT)
	for _i in 90:
		_shield(main)
		await t.wait_ticks(1)
	t.is_true(main.player.global_position.x < 13.0, "stopped at the rail")
	t.is_true(main.player.is_on_floor(), "still on the floor")
	main.player.global_position = Vector3(11.0, 6.0, -13.0)
	main.player.velocity = Vector3(8.0, 0.0, 0.0)
	for _i in 40:
		_shield(main)
		await t.wait_ticks(1)
	t.is_true(main.player.global_position.x < 13.2, "the wall stands above the rail too")
	t.equal(Player.LAYER_ARENA_WALL & Player.LAYER_WORLD, 0, "the wall is on a layer of its own")
	await t.stop_game(main)
