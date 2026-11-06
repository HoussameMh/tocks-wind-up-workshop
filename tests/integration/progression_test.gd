extends RefCounted
## The campaign in the real game: level order, carry-over, retry, title reset, re-arming boxes,
## respawn grace and slick paint. design/expansion-spec.md sections 2 and 5.


func _finish_level(t: TestKit, main: Main) -> void:
	main.level.goal_reached.emit()
	await t.wait_ticks(2)


func test_clearing_a_level_carries_run_values_into_the_next(t: TestKit) -> void:
	var main: Main = await t.start_game()
	t.equal(main.level_index, 0, "starts on level one")
	main.player.apply_blaster_power()
	main.level.cog_collected.emit()
	main.level.life_collected.emit()
	var lives := main.run_state.lives
	await _finish_level(t, main)
	t.equal(main.flow.state, GameFlow.State.LEVEL_CLEAR, "level clear")
	t.is_true(main.screens.body_text().contains("1 of %d" % main.level.total_cogs), "summary counts this level's cogs")
	var score := main.run_state.score
	main.next_level()
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "playing the next level")
	t.equal(main.level_index, 1, "on level two")
	t.equal(main.run_state.cogs, 1, "cogs carried")
	t.equal(main.run_state.level_cogs, 0, "level cogs reset")
	t.equal(main.run_state.lives, lives, "lives carried")
	t.equal(main.run_state.score, score, "score carried")
	t.equal(main.player.form(), PowerState.Form.BLASTER, "form carried")
	t.is_true(main.player.controls_enabled, "Tock can move")
	t.near(main.run_state.time_left, main.level.time_seconds, 0.2, "new level's full time")
	await t.stop_game(main)


func test_death_resets_form_keeps_checkpoint_and_grants_grace(t: TestKit) -> void:
	var main: Main = await t.start_game()
	main.player.apply_power_up()
	var respawn_at := Vector3(0.0, 0.2, -66.0)
	main.level.checkpoint_reached.emit(respawn_at)
	main.player.die()
	var back := await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.PLAYING, 120)
	t.is_true(back, "respawned")
	t.equal(main.player.form(), PowerState.Form.SMALL, "small after a death")
	t.is_true(main.player.global_position.distance_to(respawn_at) < 1.0, "at the checkpoint")
	t.is_true(main.player.is_invulnerable(), "protected on arrival")
	var seconds := main.tuning.num("run", "respawn_invulnerable_seconds")
	await t.wait_ticks(int(seconds * 60.0) + 2)
	t.is_true(not main.player.is_invulnerable(), "protection ends")
	await t.stop_game(main)


func test_game_over_retry_rebuilds_the_level_from_its_entry_snapshot(t: TestKit) -> void:
	var main: Main = await t.start_game()
	main.level.cog_collected.emit()
	await _finish_level(t, main)
	main.next_level()
	await t.wait_ticks(2)
	var entry_score := main.run_state.score
	var old_level := main.level
	main.level.cog_collected.emit()
	main.level.enemy_stomped.emit()
	main.player.apply_power_up()
	main.run_state.lives = 1
	main.player.die()
	var over := await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.GAME_OVER, 120)
	t.is_true(over, "game over")
	main.retry_level()
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "playing again")
	t.equal(main.level_index, 1, "same level")
	t.is_true(main.level != old_level, "level rebuilt")
	t.equal(main.run_state.cogs, 1, "cogs back to entry")
	t.equal(main.run_state.score, entry_score, "score back to entry")
	t.equal(main.run_state.lives, int(main.tuning.num("run", "starting_lives")), "lives refilled")
	t.equal(main.run_state.rewinds, 1, "rewind counted")
	t.equal(main.player.form(), PowerState.Form.SMALL, "small")
	await t.stop_game(main)


func test_new_run_and_title_return_to_level_one(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await _finish_level(t, main)
	main.next_level()
	await t.wait_ticks(2)
	t.is_true(main.flow.fire(GameFlow.Trigger.PAUSE), "pause")
	main.start_game()
	await t.wait_ticks(2)
	t.equal(main.level_index, 0, "restart run goes to level one")
	await _finish_level(t, main)
	main.next_level()
	await t.wait_ticks(2)
	t.is_true(main.flow.fire(GameFlow.Trigger.PAUSE), "pause again")
	main.screens.title_requested.emit()
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.TITLE, "title")
	t.equal(main.level_index, 0, "title returns to level one")
	await t.stop_game(main)


func test_each_campaign_level_builds_and_names_itself(t: TestKit) -> void:
	var main: Main = await t.start_game()
	var seen: Array[String] = []
	for index in main.campaign_size():
		main.load_level(index)
		await t.wait_ticks(2)
		t.is_true(not main.level.level_name.is_empty(), "level %d has a name" % index)
		t.is_true(main.level.time_seconds > 0.0, "level %d has a time" % index)
		t.is_true(not seen.has(main.level.level_name), "level %d name is its own" % index)
		seen.append(main.level.level_name)
	await t.stop_game(main)


func test_whole_campaign_runs_in_order_and_only_the_last_key_wins(t: TestKit) -> void:
	var main: Main = await t.start_game()
	for index in main.campaign_size() - 1:
		t.equal(main.level_index, index, "on level %d" % (index + 1))
		await _finish_level(t, main)
		t.equal(main.flow.state, GameFlow.State.LEVEL_CLEAR, "level %d clears, not wins" % (index + 1))
		main.next_level()
		await t.wait_ticks(2)
	t.equal(main.level_index, main.campaign_size() - 1, "last level reached")
	t.is_true(main.level.boss != null, "the last level has the Baron")
	await _finish_level(t, main)
	t.equal(main.flow.state, GameFlow.State.VICTORY, "the last key wins")
	t.is_true(main.screens.body_text().contains("rewinds 0"), "summary: %s" % main.screens.body_text())
	main.screens.start_requested.emit()
	await t.wait_ticks(2)
	t.equal(main.level_index, 0, "new run starts at level one")
	t.equal(main.run_state.score, 0, "and from nothing")
	await t.stop_game(main)


func test_rearm_box_refills_on_respawn_and_removes_its_uncollected_reward(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var at := main.player.global_position + Vector3(20.0, 2.7, 0.0)
	var block := main.level.add_block({"pos": [at.x, at.y, at.z], "kind": "coil", "rearm": true})
	var plain := main.level.add_block({"pos": [at.x + 3.0, at.y, at.z], "kind": "coil"})
	block.bump(false)
	plain.bump(false)
	await t.wait_ticks(1)
	t.is_true(block.used, "used")
	t.equal(main.level.released_reward_count(), 2, "two rewards out")
	main.level.rearm_boxes()
	await t.wait_ticks(1)
	t.is_true(not block.used, "fresh again")
	t.is_true(plain.used, "an ordinary box stays used")
	t.equal(main.level.released_reward_count(), 1, "its reward is gone, the other stays")
	await t.stop_game(main)


func _stop_distance(t: TestKit, main: Main, run: bool) -> float:
	var command := t.drive(main, Vector3.RIGHT)
	command.run = run
	var top := main.tuning.num("player", "run_speed" if run else "walk_speed")
	await t.wait_until(func() -> bool: return absf(main.player.velocity.x) >= top - 0.01, 300)
	var start_x := main.player.global_position.x
	command.move = Vector3.ZERO
	await t.wait_until(func() -> bool: return absf(main.player.velocity.x) < 0.01, 300)
	return main.player.global_position.x - start_x


func test_paint_slides_to_the_tuned_distance_and_floor_grips_after(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var feet := main.player.global_position
	main.level.add_paint_spill({"center": [feet.x, TestKit.ARENA_Y, feet.z], "size": [150.0, 20.0]})
	await t.wait_ticks(3)
	var walk := await _stop_distance(t, main, false)
	t.near(walk, 4.08, 4.08 * 0.05, "walk slide")
	var run := await _stop_distance(t, main, true)
	t.near(run, 10.08, 10.08 * 0.05, "run slide")
	var command := t.drive(main)
	var jump_from := main.player.global_position.y
	command.jump_pressed = true
	command.jump_held = true
	await t.wait_ticks(1)
	command.jump_pressed = false
	var peak := jump_from
	for _i in 60:
		peak = maxf(peak, main.player.global_position.y)
		await t.wait_ticks(1)
	t.near(peak - jump_from, main.tuning.num("player", "jump_height_small"), 0.15, "jump unaffected on paint")
	main.player.global_position = Vector3(feet.x, TestKit.ARENA_Y + 0.2, feet.z + 40.0)
	await t.wait_ticks(5)
	var dry := await _stop_distance(t, main, false)
	var expected := 49.0 / (2.0 * main.tuning.num("player", "ground_deceleration"))
	t.near(dry, expected, 0.2, "normal floor unchanged after leaving")
	await t.stop_game(main)


func test_hud_shows_form_banner_and_only_a_boss_level_shows_a_gauge(t: TestKit) -> void:
	var main: Main = await t.start_game()
	t.equal(main.hud.power_text(), "Small", "small plaque")
	main.player.apply_power_up()
	t.equal(main.hud.power_text(), "Coil", "coil plaque")
	main.player.apply_blaster_power()
	t.equal(main.hud.power_text(), "Blaster", "blaster plaque")
	t.is_true(main.hud.hint_keys().has("F"), "fire hint while in Blaster")
	main.player.take_hit()
	t.equal(main.hud.power_text(), "Coil", "plaque follows a hit")
	t.is_true(not main.hud.hint_keys().has("F"), "no fire hint without the Blaster")
	t.is_true(main.hud.banner_text().contains("1 of 5"), "banner on entry: %s" % main.hud.banner_text())
	t.is_true(main.hud.banner_visible(), "banner showing")
	t.is_true(not main.hud.boss_gauge_visible(), "no gauge on a course level")
	await t.wait_ticks(int(Hud.BANNER_SECONDS * 60.0) + 70)
	t.is_true(not main.hud.banner_visible(), "banner gone")
	await t.stop_game(main)
