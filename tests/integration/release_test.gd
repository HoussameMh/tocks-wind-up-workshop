extends RefCounted
## Saved progress, golden gears, level select, options, graphics quality and effects in the
## real game. design/release-spec.md section 8.

const SAVE_PATH := "user://test_progress.cfg"
## A gear must be reachable from a floor at most this far below it.
const MAX_GEAR_HEIGHT := 3.0


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Opens the title with progress saved to SAVE_PATH.
func _open_title_with_save(t: TestKit) -> Main:
	var main: Main = (load(TestKit.MAIN_SCENE) as PackedScene).instantiate()
	main.progress_path = SAVE_PATH
	t.tree.root.add_child(main)
	await t.wait_ticks(2)
	return main


func _touch(t: TestKit, main: Main, at: Vector3) -> void:
	main.player.global_position = at + Vector3.DOWN * 0.4
	main.player.velocity = Vector3.ZERO
	await t.wait_ticks(4)


func _clear_level(t: TestKit, main: Main) -> void:
	main.level.goal_reached.emit()
	await t.wait_ticks(2)


func test_every_golden_gear_sits_over_a_floor_outside_solids_and_the_key(t: TestKit) -> void:
	var main: Main = await t.start_game()
	var checked := 0
	for index in main.campaign_size():
		main.load_level(index)
		await t.wait_ticks(2)
		var space := main.level.get_world_3d().direct_space_state
		var goal: Area3D = null
		for child in main.level.get_children():
			if child is CourseObjects.GoalKey:
				goal = child
		for gear in main.level.golden_gears:
			var at := gear.global_position
			var label := "level %d gear %d" % [index + 1, gear.index]
			var point := PhysicsPointQueryParameters3D.new()
			point.position = at
			point.collision_mask = Player.LAYER_WORLD
			t.equal(space.intersect_point(point).size(), 0, "%s is not inside a solid" % label)
			var ray := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 40.0, Player.LAYER_WORLD)
			var hit := space.intersect_ray(ray)
			t.is_true(not hit.is_empty(), "%s has a floor below" % label)
			if not hit.is_empty():
				t.is_true(at.y - (hit["position"] as Vector3).y <= MAX_GEAR_HEIGHT, "%s is within jump reach" % label)
			if goal != null:
				# The key's box spins, so it can reach as far as its half-diagonal in any direction.
				var key_shape := (goal.get_child(0) as CollisionShape3D)
				var half := (key_shape.shape as BoxShape3D).size * 0.5
				var reach := Vector2(half.x, half.z).length() + GoldenGear.RADIUS
				var offset := at - key_shape.global_position
				var clear := Vector2(offset.x, offset.z).length() > reach or absf(offset.y) > half.y + GoldenGear.RADIUS
				t.is_true(clear, "%s is outside the key" % label)
			checked += 1
	t.equal(checked, 12, "three gears on each of levels 1 to 4")
	await t.stop_game(main)


func test_collected_gear_scores_shows_on_hud_and_is_banked_on_clear(t: TestKit) -> void:
	_remove_save()
	var main := await _open_title_with_save(t)
	main.start_game()
	await t.wait_ticks(3)
	t.equal(main.hud.golden_gear_text(), "Gold 0/3", "plaque shows none found")
	var score := main.run_state.score
	await _touch(t, main, main.level.golden_gears[1].global_position)
	t.equal(main.level.golden_gears.size(), 2, "the gear is gone")
	t.equal(main.run_state.score - score, int(main.tuning.num("score", "golden_gear")), "gear scored")
	t.equal(main.hud.golden_gear_text(), "Gold 1/3", "plaque counts it")
	t.equal(main.progress.gears_found(0).size(), 0, "not banked before the clear")
	await _clear_level(t, main)
	t.equal(main.progress.gears_found(0), [1] as Array[int], "banked on clear")
	t.is_true(main.screens.body_text().contains("Golden gears 1 of 3"), "clear screen counts it")
	t.is_true(main.screens.body_text().contains("New best!"), "first clear is a best time")
	await t.stop_game(main)
	var reread := Progress.load_from(SAVE_PATH, 5)
	t.equal(reread.gears_found(0), [1] as Array[int], "gear read back from the file")
	t.equal(reread.unlocked_count(), 2, "level two open after a restart")
	t.is_true(reread.best_time(0) > 0.0, "best time read back")
	_remove_save()


func test_banked_gear_returns_as_a_ghost_that_scores_but_does_not_count(t: TestKit) -> void:
	var main: Main = await t.start_game()
	main.progress.record_clear(0, 100.0, [0])
	main.load_level(0)
	await t.wait_ticks(2)
	var ghost := main.level.golden_gears[0]
	t.is_true(ghost.ghost, "banked gear is a ghost")
	t.is_true(not main.level.golden_gears[1].ghost, "others are not")
	t.equal(main.hud.golden_gear_text(), "Gold 1/3", "plaque starts with the banked gear")
	var score := main.run_state.score
	await _touch(t, main, ghost.global_position)
	t.is_true(main.run_state.score > score, "ghost still scores")
	t.equal(main.hud.golden_gear_text(), "Gold 1/3", "ghost does not count twice")
	await t.stop_game(main)


func test_game_over_retry_loses_unbanked_gears(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await _touch(t, main, main.level.golden_gears[0].global_position)
	t.equal(main.hud.golden_gear_text(), "Gold 1/3", "collected")
	main.run_state.lives = 1
	main.player.die()
	await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.GAME_OVER, 120)
	main.retry_level()
	await t.wait_ticks(2)
	t.equal(main.level.golden_gears.size(), 3, "all three gears are back")
	t.equal(main.hud.golden_gear_text(), "Gold 0/3", "nothing kept from the failed attempt")
	await t.stop_game(main)


func test_level_select_starts_a_fresh_run_on_an_unlocked_level(t: TestKit) -> void:
	var main: Main = (load(TestKit.MAIN_SCENE) as PackedScene).instantiate()
	t.tree.root.add_child(main)
	await t.wait_ticks(2)
	t.is_true(not main.screens.button_texts().has("Level select"), "no level select for a new player")
	main.progress.record_clear(0, 80.0, [])
	main.progress.record_clear(1, 120.0, [0, 2])
	main.flow.fire(GameFlow.Trigger.START)
	main.flow.fire(GameFlow.Trigger.PAUSE)
	main.screens.title_requested.emit()
	await t.wait_ticks(2)
	t.is_true(main.screens.press("Level select"), "level select offered")
	await t.wait_ticks(1)
	t.equal(main.screens.page(), Screens.Page.LEVELS, "on the level page")
	t.equal(main.screens.button_texts().size(), 4, "three unlocked levels and Back")
	t.is_true(main.screens.body_text().contains("Best time 1:20.0"), "focused level shows its best time")
	t.is_true(main.screens.press("3. Paint Shelf Panic"), "level three offered")
	await t.wait_ticks(3)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "playing")
	t.equal(main.level_index, 2, "on level three")
	t.equal(main.run_state.lives, int(main.tuning.num("run", "starting_lives")), "full lives")
	t.equal(main.player.form(), PowerState.Form.SMALL, "no power")
	main.flow.fire(GameFlow.Trigger.PAUSE)
	await t.wait_ticks(1)
	main.screens.press("Restart run")
	await t.wait_ticks(3)
	t.equal(main.level_index, 2, "restart returns to the level the run began on")
	await t.stop_game(main)


func test_options_back_returns_to_the_pause_menu_with_focus_kept(t: TestKit) -> void:
	var main: Main = await t.start_game()
	main.flow.fire(GameFlow.Trigger.PAUSE)
	await t.wait_ticks(1)
	t.is_true(main.screens.press("Options"), "options in pause")
	await t.wait_ticks(1)
	t.equal(main.screens.page(), Screens.Page.OPTIONS, "options page")
	t.is_true(main.screens.press("Back"), "back offered")
	await t.wait_ticks(1)
	t.equal(main.screens.page(), Screens.Page.ROOT, "back on the pause menu")
	t.equal(main.flow.state, GameFlow.State.PAUSED, "still paused")
	var focused := main.screens.get_viewport().gui_get_focus_owner() as Button
	t.equal(focused.text if focused != null else "", "Options", "focus returns to Options")
	await t.stop_game(main)


func test_graphics_toggle_changes_anti_aliasing_glow_and_saves(t: TestKit) -> void:
	var main: Main = await t.start_game()
	var before := main.ui_settings.graphics_quality
	main.flow.fire(GameFlow.Trigger.PAUSE)
	await t.wait_ticks(1)
	main.screens.press("Options")
	await t.wait_ticks(1)
	var label := "Graphics: High" if before == UiSettings.QUALITY_HIGH else "Graphics: Low"
	t.is_true(main.screens.press(label), "graphics button shows the setting")
	await t.wait_ticks(1)
	var now_high := main.ui_settings.graphics_quality == UiSettings.QUALITY_HIGH
	t.is_true(main.ui_settings.graphics_quality != before, "quality switched")
	t.equal(main.get_viewport().msaa_3d, Viewport.MSAA_4X if now_high else Viewport.MSAA_DISABLED, "anti-aliasing follows")
	t.equal(Look.environment().glow_enabled, now_high, "glow follows")
	t.is_true(main.screens.button_texts().has("Graphics: High" if now_high else "Graphics: Low"), "button text updates")
	var reread := UiSettings.load_from(UiSettings.DEFAULT_PATH)
	t.equal(reread.graphics_quality, main.ui_settings.graphics_quality, "saved")
	main.ui_settings.toggle_graphics_quality()
	t.equal(main.ui_settings.graphics_quality, before, "restored")
	await t.stop_game(main)


func test_effects_reuse_their_emitters_and_stop_with_reduced_motion(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var children := main.effects.get_child_count()
	for i in 10:
		main.level.enemy_stomped.emit()
		main.level.cog_collected.emit()
	await t.wait_ticks(1)
	t.is_true(main.effects.active_count() > 0, "bursts play")
	t.equal(main.effects.get_child_count(), children, "no emitters were added")
	await t.wait_ticks(60)
	t.equal(main.effects.active_count(), 0, "bursts end")
	var was_reduced := main.ui_settings.reduced_motion
	if not was_reduced:
		main.ui_settings.toggle_reduced_motion()
	main.level.enemy_stomped.emit()
	await t.wait_ticks(1)
	t.equal(main.effects.active_count(), 0, "no bursts with reduced motion")
	if not was_reduced:
		main.ui_settings.toggle_reduced_motion()
	await t.stop_game(main)


func test_hard_landing_raises_dust_and_a_step_does_not(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	await t.wait_ticks(30)
	t.equal(main.effects.active_count(), 0, "quiet on the ground")
	main.player.global_position += Vector3.UP * 0.4
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	await t.wait_ticks(1)
	t.equal(main.effects.active_count(), 0, "a short drop raises no dust")
	main.player.global_position += Vector3.UP * 8.0
	main.player.velocity = Vector3.ZERO
	await t.wait_ticks(2)
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 120)
	await t.wait_ticks(1)
	t.is_true(main.effects.active_count() > 0, "a long fall raises dust")
	await t.stop_game(main)


func test_boss_level_has_no_gear_plaque(t: TestKit) -> void:
	var main: Main = await t.start_level(4)
	t.equal(main.level.golden_gear_total, 0, "no gears in the arena")
	t.equal(main.hud.golden_gear_text(), "", "plaque hidden")
	await t.stop_game(main)
