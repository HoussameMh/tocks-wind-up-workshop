extends RefCounted
## Sends real controller events through Input.parse_input_event into the real game scene.
## No physical controller is involved, so this cannot prove anything about real hardware.

const PAD := 0
const OTHER_PAD := 3


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _button_event(button: JoyButton, pressed: bool, device := PAD) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	return event


func _axis_event(axis: JoyAxis, value: float, device := PAD) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	return event


func _tap(button: JoyButton) -> void:
	_send(_button_event(button, true))
	_send(_button_event(button, false))


func _push_stick(axis: JoyAxis, value: float) -> void:
	_send(_axis_event(axis, value))


func _center_sticks(device := PAD) -> void:
	for axis: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		_send(_axis_event(axis, 0.0, device))


func _open_title(t: TestKit) -> Main:
	var main: Main = (load(TestKit.MAIN_SCENE) as PackedScene).instantiate()
	t.tree.root.add_child(main)
	await t.wait_ticks(2)
	return main


func _focused(main: Main) -> Control:
	return main.screens.get_viewport().gui_get_focus_owner()


func _focused_text(main: Main) -> String:
	var owner := _focused(main)
	return (owner as Button).text if owner is Button else "<nothing>"


func _horizontal_speed(main: Main) -> float:
	return Vector2(main.player.velocity.x, main.player.velocity.z).length()


func _end_run(main: Main) -> void:
	main.flow.fire(GameFlow.Trigger.DIE)
	main.flow.fire(GameFlow.Trigger.OUT_OF_LIVES)


func test_left_stick_moves_tock_with_analog_speed(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	var start := main.player.global_position
	_push_stick(JOY_AXIS_LEFT_Y, -1.0)
	await t.wait_ticks(30)
	t.is_true(main.player.global_position.z < start.z - 0.5, "stick up moves away from the camera")
	var walk_speed := main.tuning.num("player", "walk_speed")
	t.near(_horizontal_speed(main), walk_speed, 0.1, "full stick is full walking speed")
	_push_stick(JOY_AXIS_LEFT_Y, -0.6)
	await t.wait_ticks(30)
	# 0.6 is halfway between the 0.2 deadzone and full travel.
	t.near(_horizontal_speed(main), walk_speed * 0.5, 0.15, "part stick is part speed")
	_center_sticks()
	await t.stop_game(main)


func test_stick_inside_deadzone_does_not_move_tock(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	var yaw_before := main.camera.yaw
	_push_stick(JOY_AXIS_LEFT_X, 0.15)
	_push_stick(JOY_AXIS_RIGHT_X, 0.15)
	await t.wait_ticks(20)
	t.near(_horizontal_speed(main), 0.0, 0.001, "drifting left stick does nothing")
	t.near(main.camera.yaw, yaw_before, 0.001, "drifting right stick does nothing")
	_center_sticks()
	await t.stop_game(main)


func test_a_button_makes_tock_jump(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	var ground_y := main.player.global_position.y
	_send(_button_event(JOY_BUTTON_A, true))
	var rose := await t.wait_until(func() -> bool: return main.player.global_position.y > ground_y + 1.0, 30)
	_send(_button_event(JOY_BUTTON_A, false))
	t.is_true(rose, "A jumps")
	await t.stop_game(main)


func test_x_button_makes_tock_run(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	_push_stick(JOY_AXIS_LEFT_Y, -1.0)
	_send(_button_event(JOY_BUTTON_X, true))
	await t.wait_ticks(30)
	t.near(_horizontal_speed(main), main.tuning.num("player", "run_speed"), 0.1, "holding X runs")
	_send(_button_event(JOY_BUTTON_X, false))
	_center_sticks()
	await t.stop_game(main)


func test_right_stick_turns_and_tilts_the_camera(t: TestKit) -> void:
	var main: Main = await t.start_game()
	var yaw_before := main.camera.yaw
	var pitch_before := main.camera.pitch
	_push_stick(JOY_AXIS_RIGHT_X, 1.0)
	_push_stick(JOY_AXIS_RIGHT_Y, 1.0)
	await t.wait_ticks(10)
	_center_sticks()
	t.is_true(main.camera.yaw < yaw_before - 0.1, "stick right turns the camera")
	t.is_true(main.camera.pitch > pitch_before + 0.1, "stick down tilts the camera")
	var yaw_after := main.camera.yaw
	await t.wait_ticks(5)
	t.near(main.camera.yaw, yaw_after, 0.001, "centered stick stops turning")
	await t.stop_game(main)


func test_start_button_pauses_and_resumes(t: TestKit) -> void:
	var main: Main = await t.start_game()
	_tap(JOY_BUTTON_START)
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.PAUSED, "paused by Start")
	t.is_true(_focused(main) is Button, "pause menu has a focused button")
	_tap(JOY_BUTTON_START)
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "resumed by Start")
	await t.stop_game(main)


func test_b_button_resumes_from_pause(t: TestKit) -> void:
	var main: Main = await t.start_game()
	_tap(JOY_BUTTON_START)
	await t.wait_ticks(2)
	_tap(JOY_BUTTON_B)
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "B resumes")
	await t.stop_game(main)


func test_b_button_on_end_screen_returns_to_title(t: TestKit) -> void:
	var main: Main = await t.start_game()
	_end_run(main)
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.GAME_OVER, "run ended")
	# B is also Fire, so a player shooting as the run ends must not skip the screen by accident.
	_tap(JOY_BUTTON_B)
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.GAME_OVER, "B mashed as the screen appears is ignored")
	var allowed_at := Time.get_ticks_msec() + Screens.CONFIRM_GRACE_MSEC
	await t.wait_until(func() -> bool: return Time.get_ticks_msec() > allowed_at, 6000)
	_tap(JOY_BUTTON_B)
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.TITLE, "B then goes back to the title")
	_tap(JOY_BUTTON_B)
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.TITLE, "B does nothing more on the title")
	await t.stop_game(main)


func test_a_button_presses_focused_title_button(t: TestKit) -> void:
	var main := await _open_title(t)
	t.equal(_focused_text(main), main.tr("Start"), "Start has focus when the title appears")
	_tap(JOY_BUTTON_A)
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "A starts the run")
	t.equal(_focused(main), null, "nothing has focus during play")
	await t.stop_game(main)


func test_confirming_start_with_a_does_not_also_jump(t: TestKit) -> void:
	var main := await _open_title(t)
	# A held for a few ticks, as a thumb does: the button fires on release.
	_send(_button_event(JOY_BUTTON_A, true))
	await t.wait_ticks(4)
	t.equal(main.flow.state, GameFlow.State.TITLE, "nothing starts until A is released")
	_send(_button_event(JOY_BUTTON_A, false))
	await t.wait_ticks(1)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "releasing A starts the run")
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	var ground_y := main.player.global_position.y
	await t.wait_ticks(15)
	t.near(main.player.global_position.y, ground_y, 0.05, "Tock stays on the ground")
	await t.stop_game(main)


func test_dpad_moves_focus_and_stops_at_the_ends(t: TestKit) -> void:
	var main := await _open_title(t)
	var buttons := main.screens.find_children("*", "Button", true, false)
	var first := _focused(main)
	_tap(JOY_BUTTON_DPAD_DOWN)
	await t.wait_ticks(1)
	t.equal(_focused(main), buttons[1], "D-pad down moves to the button below")
	_tap(JOY_BUTTON_DPAD_UP)
	await t.wait_ticks(1)
	t.equal(_focused(main), first, "D-pad up comes back")
	_tap(JOY_BUTTON_DPAD_UP)
	await t.wait_ticks(1)
	t.equal(_focused(main), first, "up at the top stays on the top button")
	for _i in buttons.size() + 1:
		_tap(JOY_BUTTON_DPAD_DOWN)
		await t.wait_ticks(1)
	t.equal(_focused(main), buttons[-1], "down at the bottom stays on the bottom button")
	_tap(JOY_BUTTON_DPAD_LEFT)
	await t.wait_ticks(1)
	t.equal(_focused(main), buttons[-1], "left stays on the button")
	await t.stop_game(main)


func _arrow_event(code: Key, pressed: bool, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


## Regression: on a menu that wrapped, Up at the top jumped to the bottom, which reads as inverted.
func test_arrow_keys_never_move_focus_the_opposite_way(t: TestKit) -> void:
	var main := await _open_title(t)
	var buttons := main.screens.find_children("*", "Button", true, false)
	_send(_arrow_event(KEY_UP, true))
	_send(_arrow_event(KEY_UP, false))
	await t.wait_ticks(1)
	t.equal(_focused(main), buttons[0], "Up at the top button does not jump to the bottom")
	_send(_arrow_event(KEY_DOWN, true))
	_send(_arrow_event(KEY_DOWN, false))
	await t.wait_ticks(1)
	t.equal(_focused(main), buttons[1], "Down moves one button down")
	await t.stop_game(main)


## Regression: a slightly long press sends key-repeat. Two steps on a three-button wrapping menu
## land on the button one step the other way, so one press must only ever move one step.
func test_held_arrow_key_repeat_moves_only_one_step(t: TestKit) -> void:
	var main := await _open_title(t)
	var buttons := main.screens.find_children("*", "Button", true, false)
	# Real key events arrive between frames, not inside a physics tick.
	await t.tree.process_frame
	_send(_arrow_event(KEY_DOWN, true))
	await t.tree.process_frame
	t.equal(_focused(main), buttons[1], "first press moves one step")
	# Not a multiple of the button count, or a wrapping menu would land back here and hide the bug.
	for _i in 2:
		_send(_arrow_event(KEY_DOWN, true, true))
		await t.tree.process_frame
	_send(_arrow_event(KEY_DOWN, false))
	await t.tree.process_frame
	t.equal(_focused(main), buttons[1], "key-repeat from holding the key moves nothing more")
	await t.stop_game(main)


func test_left_stick_moves_focus_once_per_push(t: TestKit) -> void:
	var main := await _open_title(t)
	# Real controller events arrive between frames, not inside a physics tick. The engine's
	# guard against a held stick repeating only reads correctly from there.
	await t.tree.process_frame
	var first := _focused(main)
	_push_stick(JOY_AXIS_LEFT_Y, 1.0)
	await t.tree.process_frame
	var second := _focused(main)
	t.is_true(second != first and second is Button, "stick down moves focus")
	_push_stick(JOY_AXIS_LEFT_Y, 0.9)
	await t.tree.process_frame
	_push_stick(JOY_AXIS_LEFT_Y, 1.0)
	await t.tree.process_frame
	t.equal(_focused(main), second, "a held stick does not keep moving focus")
	_push_stick(JOY_AXIS_LEFT_Y, 0.0)
	await t.tree.process_frame
	_push_stick(JOY_AXIS_LEFT_Y, -1.0)
	await t.tree.process_frame
	t.equal(_focused(main), first, "stick up moves focus back")
	_center_sticks()
	await t.stop_game(main)


func test_every_menu_focuses_a_button_and_keeps_focus_after_mouse_use(t: TestKit) -> void:
	var main := await _open_title(t)
	t.is_true(_focused(main) is Button, "title focuses a button")
	await _check_focus_survives_mouse(t, main, "title")
	main.start_game()
	await t.wait_ticks(2)
	_tap(JOY_BUTTON_START)
	await t.wait_ticks(2)
	t.is_true(_focused(main) is Button, "pause focuses a button")
	await _check_focus_survives_mouse(t, main, "pause")
	main.start_game()
	await t.wait_ticks(2)
	_end_run(main)
	await t.wait_ticks(2)
	t.is_true(_focused(main) is Button, "game over focuses a button")
	await _check_focus_survives_mouse(t, main, "game over")
	main.start_game()
	await t.wait_ticks(2)
	main.flow.fire(GameFlow.Trigger.CLEAR)
	await t.wait_ticks(2)
	t.is_true(_focused(main) is Button, "level clear focuses a button")
	await t.stop_game(main)


func _check_focus_survives_mouse(t: TestKit, main: Main, screen: String) -> void:
	var before := _focused(main)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = Vector2(1100.0, 400.0)
		click.pressed = pressed
		_send(click)
	await t.tree.process_frame
	await t.tree.process_frame
	t.equal(_focused(main), before, "%s keeps focus after a click on empty space" % screen)
	main.screens.get_viewport().gui_release_focus()
	await t.tree.process_frame
	await t.tree.process_frame
	t.equal(_focused(main), before, "%s takes focus back when it is lost" % screen)


func test_sticks_in_play_do_not_reach_the_menu_buttons(t: TestKit) -> void:
	var main: Main = await t.start_game()
	_tap(JOY_BUTTON_DPAD_DOWN)
	_push_stick(JOY_AXIS_LEFT_Y, 1.0)
	await t.wait_ticks(2)
	_center_sticks()
	t.equal(_focused(main), null, "nothing takes focus")
	t.equal(main.flow.state, GameFlow.State.PLAYING, "still playing")
	await t.stop_game(main)


func test_sticks_in_menu_do_not_move_tock_or_the_camera(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	_end_run(main)
	await t.wait_ticks(2)
	var position_before := main.player.global_position
	var yaw_before := main.camera.yaw
	_push_stick(JOY_AXIS_RIGHT_X, 1.0)
	_push_stick(JOY_AXIS_LEFT_Y, -1.0)
	await t.wait_ticks(15)
	_center_sticks()
	t.near(main.camera.yaw, yaw_before, 0.001, "right stick does not turn the camera")
	t.near(main.player.global_position.z, position_before.z, 0.001, "left stick does not move Tock")
	await t.stop_game(main)


func test_a_held_when_run_ends_does_not_confirm_the_end_screen(t: TestKit) -> void:
	var main: Main = await t.start_game()
	_send(_button_event(JOY_BUTTON_A, true))
	await t.wait_ticks(2)
	_end_run(main)
	await t.wait_ticks(2)
	_send(_button_event(JOY_BUTTON_A, false))
	_tap(JOY_BUTTON_A)
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.GAME_OVER, "mashing A does not skip Game Over")
	await t.stop_game(main)


func test_any_connected_controller_number_works(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	var start_z := main.player.global_position.z
	_send(_axis_event(JOY_AXIS_LEFT_Y, -1.0, OTHER_PAD))
	await t.wait_ticks(20)
	_center_sticks(OTHER_PAD)
	t.is_true(main.player.global_position.z < start_z - 0.5, "a controller with another number moves Tock")
	await t.stop_game(main)


func test_removing_controller_releases_held_stick_and_pauses(t: TestKit) -> void:
	var main: Main = await t.start_game()
	await t.wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	_push_stick(JOY_AXIS_LEFT_Y, -1.0)
	_send(_button_event(JOY_BUTTON_X, true))
	await t.wait_ticks(5)
	t.is_true(Input.is_action_pressed("move_forward"), "stick is held")
	Input.joy_connection_changed.emit(PAD, false)
	Input.flush_buffered_events()
	await t.wait_ticks(2)
	t.is_true(not Input.is_action_pressed("move_forward"), "the held stick is released")
	t.is_true(not Input.is_action_pressed("run"), "the held button is released")
	t.equal(main.flow.state, GameFlow.State.PAUSED, "removing the controller in use pauses")
	t.is_true(_focused(main) is Button, "pause menu is usable")
	t.equal(main.input_device.kind, InputDeviceTracker.Kind.KEYBOARD_MOUSE, "hints go back to keyboard")
	await t.stop_game(main)


func test_removing_controller_during_respawn_delay_pauses_after_respawn(t: TestKit) -> void:
	var main: Main = await t.start_game()
	_tap(JOY_BUTTON_LEFT_SHOULDER)
	await t.wait_ticks(1)
	main.player.die()
	t.equal(main.flow.state, GameFlow.State.LIFE_LOST, "life lost")
	Input.joy_connection_changed.emit(PAD, false)
	await t.wait_ticks(1)
	t.equal(main.flow.state, GameFlow.State.LIFE_LOST, "the respawn delay is not interrupted")
	var paused := await t.wait_until(func() -> bool: return main.flow.state == GameFlow.State.PAUSED, 240)
	t.is_true(paused, "pauses as soon as Tock respawns")
	await t.stop_game(main)


func test_removing_controller_on_end_screen_does_not_pause_the_next_run(t: TestKit) -> void:
	var main: Main = await t.start_game()
	_tap(JOY_BUTTON_LEFT_SHOULDER)
	await t.wait_ticks(1)
	_end_run(main)
	await t.wait_ticks(1)
	Input.joy_connection_changed.emit(PAD, false)
	await t.wait_ticks(1)
	t.equal(main.flow.state, GameFlow.State.GAME_OVER, "still on Game Over")
	main.start_game()
	await t.wait_ticks(2)
	main.player.die()
	await t.wait_until(func() -> bool: return main.flow.state != GameFlow.State.LIFE_LOST, 240)
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "the next respawn does not pause")
	await t.stop_game(main)


func test_plugging_in_or_removing_unused_controller_changes_nothing(t: TestKit) -> void:
	var main: Main = await t.start_game()
	Input.joy_connection_changed.emit(OTHER_PAD, true)
	Input.joy_connection_changed.emit(OTHER_PAD, false)
	Input.flush_buffered_events()
	await t.wait_ticks(2)
	t.equal(main.flow.state, GameFlow.State.PLAYING, "still playing")
	t.equal(main.input_device.kind, InputDeviceTracker.Kind.KEYBOARD_MOUSE, "hints unchanged")
	await t.stop_game(main)


func test_hints_match_the_last_used_device(t: TestKit) -> void:
	var main: Main = await t.start_game()
	t.is_true(main.hud.hint_keys().has(main.tr("Space")), "keyboard hint starts on Space")
	_tap(JOY_BUTTON_A)
	await t.wait_ticks(1)
	t.is_true(main.hud.hint_keys().has(main.tr("A")), "pad use switches the play hint to A")
	t.is_true(not main.hud.hint_keys().has(main.tr("Space")), "Space is gone")
	_tap(JOY_BUTTON_START)
	await t.wait_ticks(2)
	t.is_true(main.screens.hint_keys().has(main.tr("B")), "pause menu hint shows B")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F1
	key.pressed = true
	_send(key)
	key = key.duplicate() as InputEventKey
	key.pressed = false
	_send(key)
	await t.tree.process_frame
	t.is_true(main.screens.hint_keys().has(main.tr("Esc")), "keyboard use switches the menu hint to Esc")
	t.is_true(main.hud.hint_keys().has(main.tr("Space")), "and the play hint back to Space")
	await t.stop_game(main)


func test_small_mouse_bump_keeps_gamepad_hints_but_real_mouse_use_switches(t: TestKit) -> void:
	var main := await _open_title(t)
	_tap(JOY_BUTTON_DPAD_DOWN)
	await t.wait_ticks(1)
	t.equal(main.input_device.kind, InputDeviceTracker.Kind.GAMEPAD, "pad in use")
	var headless := DisplayServer.get_name() == "headless" # It has no cursor to hide.
	if not headless:
		t.equal(Input.mouse_mode, Input.MOUSE_MODE_HIDDEN, "cursor hides while the pad is in use")
	var bump := InputEventMouseMotion.new()
	bump.screen_relative = Vector2(3.0, 0.0)
	_send(bump)
	await t.wait_ticks(1)
	t.equal(main.input_device.kind, InputDeviceTracker.Kind.GAMEPAD, "a bump does not switch")
	for _i in 5:
		var move := InputEventMouseMotion.new()
		move.screen_relative = Vector2(3.0, 0.0)
		_send(move)
	await t.wait_ticks(1)
	t.equal(main.input_device.kind, InputDeviceTracker.Kind.KEYBOARD_MOUSE, "a slow real move switches")
	if not headless:
		t.equal(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "cursor comes back")
	await t.stop_game(main)


func test_game_over_saturation_resets_on_next_run(t: TestKit) -> void:
	var main: Main = await t.start_game()
	var environment := Look.environment()
	t.is_true(not environment.adjustment_enabled, "normal color in play")
	_end_run(main)
	await t.wait_ticks(40)
	t.is_true(environment.adjustment_enabled, "adjustments on at Game Over")
	t.near(environment.adjustment_saturation, Main.GAME_OVER_SATURATION, 0.01, "faded")
	main.start_game()
	await t.wait_ticks(2)
	t.is_true(not environment.adjustment_enabled, "adjustments off on the next run")
	t.near(environment.adjustment_saturation, 1.0, 0.001, "saturation restored")
	await t.stop_game(main)


func test_reduced_motion_stops_title_sway_and_can_be_turned_back_off(t: TestKit) -> void:
	var main := await _open_title(t)
	var was_reduced := main.ui_settings.reduced_motion
	if was_reduced:
		main.ui_settings.toggle_reduced_motion()
	await t.wait_ticks(30)
	var position_a := main.camera.global_position
	await t.wait_ticks(30)
	t.is_true(main.camera.global_position.distance_to(position_a) > 0.001, "camera sways by default")
	_tap(JOY_BUTTON_DPAD_DOWN)
	await t.wait_ticks(1)
	var toggle := _focused(main) as Button
	var text_before := toggle.text
	_tap(JOY_BUTTON_A)
	await t.wait_ticks(2)
	t.is_true(main.ui_settings.reduced_motion, "A on the toggle turns it on")
	t.is_true(toggle.text != text_before, "button shows the new setting")
	t.equal(_focused(main), toggle, "focus stays on the toggle")
	var position_b := main.camera.global_position
	await t.wait_ticks(30)
	t.near(main.camera.global_position.distance_to(position_b), 0.0, 0.001, "no sway when reduced")
	var motes := main.level.find_children("*", "CPUParticles3D", true, false)
	t.equal(motes.size(), 1, "the title has one mote emitter")
	t.is_true(not (motes[0] as CPUParticles3D).visible, "no motes when reduced")
	_tap(JOY_BUTTON_A)
	await t.wait_ticks(2)
	t.is_true(not main.ui_settings.reduced_motion, "A turns it back off")
	if was_reduced:
		main.ui_settings.toggle_reduced_motion()
	await t.stop_game(main)
