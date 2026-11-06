extends RefCounted
## The intro on launch and the outro after the win, in the real game.


func _start_with_films(t: TestKit) -> Main:
	var main: Main = (load(TestKit.MAIN_SCENE) as PackedScene).instantiate()
	main.films_enabled = true
	t.tree.root.add_child(main)
	await t.wait_ticks(2)
	return main


func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


## Waits out the skip grace in real time, because it is measured in real time.
func _wait_for_skip_grace(t: TestKit) -> void:
	var allowed_at := Time.get_ticks_msec() + FilmPlayer.SKIP_GRACE_MSEC + 20
	await t.wait_until(func() -> bool: return Time.get_ticks_msec() > allowed_at, 6000)


func _to_boss_level(t: TestKit, main: Main) -> void:
	main.film.skip()
	await t.wait_ticks(1)
	main.start_game()
	main.load_level(main.campaign_size() - 1)
	main.run_state.enter_level(main.level.time_seconds)
	await t.wait_ticks(2)


func test_films_are_real_files_godot_can_load(t: TestKit) -> void:
	for path: String in [Main.INTRO_FILM, Main.OUTRO_FILM]:
		t.is_true(ResourceLoader.exists(path), "%s exists" % path)
		t.is_true(load(path) is VideoStream, "%s is a video" % path)


func test_intro_plays_on_launch_before_the_title_menu(t: TestKit) -> void:
	var main: Main = await _start_with_films(t)
	t.is_true(main.film.is_playing(), "the intro is playing")
	t.is_true(not main.screens.menu_open(), "no menu behind it yet")
	t.is_true(t.tree.paused, "the world waits")
	main.film.skip()
	await t.wait_ticks(1)
	t.is_true(not main.film.is_playing(), "the intro ended")
	t.is_true(main.screens.menu_open(), "the title menu appears")
	t.equal(main.flow.state, GameFlow.State.TITLE, "at the title")
	t.is_true(not t.tree.paused, "the world runs")
	await t.stop_game(main)


func test_a_press_skips_the_film_without_also_pressing_the_menu(t: TestKit) -> void:
	var main: Main = await _start_with_films(t)
	_press_key(KEY_ENTER)
	await t.wait_ticks(1)
	t.is_true(main.film.is_playing(), "a press inside the grace is ignored")
	await _wait_for_skip_grace(t)
	_press_key(KEY_ENTER)
	await t.wait_ticks(2)
	t.is_true(not main.film.is_playing(), "a later press skips")
	t.equal(main.flow.state, GameFlow.State.TITLE, "the press did not also start the game")
	await t.stop_game(main)


func test_outro_plays_before_the_victory_screen_and_pays_bonuses_once(t: TestKit) -> void:
	var main: Main = await _start_with_films(t)
	await _to_boss_level(t, main)
	var before := main.run_state.score
	main.level.goal_reached.emit()
	t.is_true(main.film.is_playing(), "the outro is playing")
	t.equal(main.flow.state, GameFlow.State.PLAYING, "no victory screen yet")
	t.is_true(t.tree.paused, "the world waits")
	var paid := main.run_state.score
	t.is_true(paid > before, "bonuses paid")
	main.level.goal_reached.emit()
	t.equal(main.run_state.score, paid, "a second touch pays nothing")
	main.film.skip()
	await t.wait_ticks(1)
	t.equal(main.flow.state, GameFlow.State.VICTORY, "then the victory screen")
	t.is_true(main.screens.menu_open(), "with its menu")
	t.is_true(not t.tree.paused, "the world runs")
	await t.stop_game(main)


func test_only_the_last_level_plays_the_outro(t: TestKit) -> void:
	var main: Main = await _start_with_films(t)
	main.film.skip()
	await t.wait_ticks(1)
	main.start_game()
	await t.wait_ticks(1)
	main.level.goal_reached.emit()
	t.is_true(not main.film.is_playing(), "no film on level one")
	t.equal(main.flow.state, GameFlow.State.LEVEL_CLEAR, "just the clear screen")
	await t.stop_game(main)


func test_a_lost_gamepad_during_the_outro_cannot_block_the_win(t: TestKit) -> void:
	var main: Main = await _start_with_films(t)
	await _to_boss_level(t, main)
	main.level.goal_reached.emit()
	main._on_gamepad_lost()
	t.equal(main.flow.state, GameFlow.State.PLAYING, "no pause during the film")
	main.film.skip()
	await t.wait_ticks(1)
	t.equal(main.flow.state, GameFlow.State.VICTORY, "the win still lands")
	await t.stop_game(main)


func test_reduced_motion_skips_the_films(t: TestKit) -> void:
	var main: Main = await _start_with_films(t)
	await _to_boss_level(t, main)
	var was_reduced := main.ui_settings.reduced_motion
	main.ui_settings.reduced_motion = true
	main.level.goal_reached.emit()
	t.is_true(not main.film.is_playing(), "no outro")
	t.equal(main.flow.state, GameFlow.State.VICTORY, "straight to the victory screen")
	main.ui_settings.reduced_motion = was_reduced
	await t.stop_game(main)


func test_a_missing_film_counts_as_finished(t: TestKit) -> void:
	var player := FilmPlayer.new()
	t.tree.root.add_child(player)
	var done := {"yes": false}
	player.play("res://assets/video/no_such_film.ogv", func() -> void: done["yes"] = true)
	t.is_true(done["yes"], "carries straight on")
	t.is_true(not player.is_playing(), "nothing playing")
	player.queue_free()
	await t.tree.process_frame
