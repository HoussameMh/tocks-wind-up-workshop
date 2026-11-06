extends RefCounted
## The Bolt Blaster in the real game scene: input, fire rate, bolt pool, aim and hit rules.
## Implements acceptance criteria 4, 5 and 6 of design/expansion-spec.md section 8.

const OTHER_ACTIONS: Array[String] = [
	"move_left", "move_right", "move_forward", "move_back", "jump", "run",
	"camera_left", "camera_right", "camera_up", "camera_down", "pause",
	"ui_accept", "ui_up", "ui_down", "ui_left", "ui_right",
]


func _armed(t: TestKit) -> Main:
	var main: Main = await t.start_arena()
	main.player.apply_blaster_power()
	await t.wait_ticks(int(ceilf(main.tuning.num("blaster", "fire_grace") * 60.0)) + 1)
	return main


func _fire_counter(main: Main) -> Dictionary:
	var counter := {"fired": 0, "clinks": 0}
	main.player.blaster.fired.connect(func() -> void: counter["fired"] += 1)
	main.player.blaster.clinked.connect(func() -> void: counter["clinks"] += 1)
	return counter


## A point on the arena floor, relative to facing -z from Tock.
func _ahead(main: Main, yaw_degrees: float, distance: float) -> Vector3:
	var yaw := deg_to_rad(yaw_degrees)
	return main.player.global_position + Vector3(sin(yaw) * distance, 0.0, -cos(yaw) * distance)


func _add_wall(main: Main, center: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = Player.LAYER_WORLD
	wall.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	wall.add_child(collider)
	main.level.add_child(wall)
	return wall


func _press_and_release(event: InputEvent) -> Array[bool]:
	var press: InputEvent = event.duplicate()
	press.set("pressed", true)
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var down := Input.is_action_pressed("fire")
	var release: InputEvent = event.duplicate()
	release.set("pressed", false)
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	return [down, Input.is_action_pressed("fire")]


func _fire_events() -> Array[InputEvent]:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_MOUSE
	mouse.button_index = MOUSE_BUTTON_LEFT
	var right_bumper := InputEventJoypadButton.new()
	right_bumper.button_index = JOY_BUTTON_RIGHT_SHOULDER
	var b_button := InputEventJoypadButton.new()
	b_button.button_index = JOY_BUTTON_B
	return [key, mouse, right_bumper, b_button]


func test_fire_is_bound_to_f_mouse_rb_and_b_and_no_other_action(t: TestKit) -> void:
	for event in _fire_events():
		var states := _press_and_release(event)
		t.is_true(states[0], "%s presses fire" % event.as_text())
		t.is_true(not states[1], "%s releases fire" % event.as_text())
		event.set("pressed", true)
		for action in OTHER_ACTIONS:
			t.is_true(not InputMap.event_is_action(event, action), "%s not on %s" % [event.as_text(), action])
	# B is shared with menu cancel on purpose. The 0.15 s grace is what makes that safe.
	var b_event := _fire_events()[3]
	b_event.set("pressed", true)
	t.is_true(InputMap.event_is_action(b_event, "ui_cancel"), "B still cancels menus")


func test_real_f_key_fires_a_bolt_and_hold_repeats(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var counter := _fire_counter(main)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await t.wait_ticks(30)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	t.equal(counter["fired"], 2, "two bolts in 0.5 s of holding F")
	await t.wait_ticks(30)
	t.equal(counter["fired"], 2, "released: no more bolts")
	await t.stop_game(main)


func test_trigger_is_ignored_for_the_grace_after_entering_play(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var counter := _fire_counter(main)
	main.flow.fire(GameFlow.Trigger.PAUSE)
	await t.tree.process_frame
	var command := t.drive(main)
	main.flow.fire(GameFlow.Trigger.RESUME)
	command.fire_pressed = true
	var grace_ticks := int(main.tuning.num("blaster", "fire_grace") * 60.0)
	await t.wait_ticks(grace_ticks - 2)
	t.equal(counter["fired"], 0, "nothing inside the grace")
	await t.wait_ticks(5)
	t.equal(counter["fired"], 1, "fires once the grace ends, if still held")
	await t.stop_game(main)


func test_small_and_coiled_fire_nothing(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var counter := _fire_counter(main)
	var command := t.drive(main)
	command.fire_pressed = true
	await t.wait_ticks(30)
	t.equal(main.player.form(), PowerState.Form.SMALL, "small")
	t.equal(counter["fired"], 0, "small fires nothing")
	t.equal(main.player.blaster.alive_count(), 0, "small: no bolts")
	main.player.apply_power_up()
	await t.wait_ticks(30)
	t.equal(main.player.form(), PowerState.Form.COILED, "coiled")
	t.equal(counter["fired"], 0, "coiled fires nothing")
	t.equal(main.player.blaster.alive_count(), 0, "coiled: no bolts")
	main.player.apply_blaster_power()
	await t.wait_ticks(5)
	t.equal(counter["fired"], 1, "control: the same trigger fires in blaster")
	await t.stop_game(main)


func test_bolts_alive_reach_but_never_exceed_the_cap(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var counter := _fire_counter(main)
	# No cooldown, so only the cap can stop a fourth bolt. At the real rate the cap is never tested.
	main.player.blaster.cooldown = 0.0
	var command := t.drive(main)
	command.fire_pressed = true
	var highest := 0
	# Shorter than one 0.77 s flight, so no bolt has finished and made room for another.
	for _i in 40:
		await t.wait_ticks(1)
		highest = maxi(highest, main.player.blaster.alive_count())
	t.equal(highest, 3, "alive cap")
	t.equal(counter["fired"], 3, "the three in flight were all it could fire")
	await t.stop_game(main)


func test_cooldown_spaces_bolts_by_the_tuned_time(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var fire_ticks: Array[int] = []
	var clock := {"tick": 0}
	main.player.blaster.fired.connect(func() -> void: fire_ticks.append(clock["tick"]))
	var command := t.drive(main)
	command.fire_pressed = true
	for _i in 120:
		await t.wait_ticks(1)
		clock["tick"] += 1
	command.fire_pressed = false
	var expected_gap := main.tuning.num("blaster", "cooldown") * 60.0
	t.is_true(fire_ticks.size() >= 5, "several shots in 2 s, got %d" % fire_ticks.size())
	for i in range(1, fire_ticks.size()):
		t.near(float(fire_ticks[i] - fire_ticks[i - 1]), expected_gap, 1.01, "gap %d" % i)
	await t.stop_game(main)


func test_untargeted_bolt_flies_flat_from_hip_height_until_range_ends(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var counter := _fire_counter(main)
	var feet := main.player.global_position
	var command := t.drive(main)
	command.fire_pressed = true
	await t.wait_ticks(1)
	command.fire_pressed = false
	await t.wait_ticks(1)
	t.equal(main.player.blaster.alive_count(), 1, "one bolt")
	var bolt: Bolt = main.player.blaster._bolts[0]
	var last := bolt.global_position
	t.near(last.y, feet.y + main.tuning.num("blaster", "muzzle_height"), 0.01, "launch height")
	var ticks := 0
	while bolt.active and ticks < 90:
		last = bolt.global_position
		await t.wait_ticks(1)
		ticks += 1
	t.is_true(not bolt.active, "bolt ended")
	t.near(last.y, feet.y + main.tuning.num("blaster", "muzzle_height"), 0.01, "stayed flat")
	t.near(feet.distance_to(Vector3(last.x, feet.y, last.z)), main.tuning.num("blaster", "bolt_range"), 0.6, "range")
	t.equal(counter["clinks"], 1, "small clink at range end")
	await t.stop_game(main)


func test_aim_selects_29_degrees_17_m_but_not_31_degrees_or_19_m(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var blaster := main.player.blaster
	for entry: Array in [[29.0, 17.0, true], [-29.0, 17.0, true], [31.0, 17.0, false], [29.0, 19.0, false]]:
		var duck := main.level.add_duck({"pos": _vec_array(_ahead(main, entry[0], entry[1]))})
		await t.wait_ticks(10)
		t.equal(blaster.current_target == duck, entry[2], "yaw %s, distance %s" % [entry[0], entry[1]])
		duck.queue_free()
		await t.wait_ticks(10)
		t.equal(blaster.current_target, null, "target cleared when it is gone")
	await t.stop_game(main)


func test_aim_uses_move_input_immediately_over_the_turning_model(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var duck := main.level.add_duck({"pos": _vec_array(_ahead(main, 90.0, 12.0))})
	await t.wait_ticks(10)
	t.equal(main.player.blaster.current_target, null, "off to the side while facing forward")
	var command := t.drive(main, Vector3.RIGHT)
	command.fire_pressed = true
	# Fire on the first tick of input: the model has barely started to turn.
	await t.wait_ticks(1)
	t.equal(main.player.blaster.current_target, duck, "moving toward it targets it at once")
	await t.stop_game(main)


func test_ring_shows_the_current_target_only_in_blaster(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var ring: MeshInstance3D = main.player.blaster._ring
	t.is_true(not ring.visible, "no target, no ring")
	var duck := main.level.add_duck({"pos": _vec_array(_ahead(main, 0.0, 15.0))})
	await t.wait_ticks(10)
	t.is_true(ring.visible, "ring on a target")
	t.is_true(ring.global_position.y > duck.bolt_bounds().end.y, "ring sits above the target")
	t.near(ring.global_position.x, duck.global_position.x, 0.01, "ring over the target")
	main.player._power.invulnerable_left = 0.0
	main.player.take_hit()
	await t.wait_ticks(2)
	t.equal(main.player.form(), PowerState.Form.COILED, "hit drops to coiled")
	t.is_true(not ring.visible, "ring gone with the blaster")
	t.is_true(not main.player._model._barrel.visible, "barrel gone with the blaster")
	await t.stop_game(main)


func test_elevated_plane_in_the_cone_is_hit_with_no_pitch_input(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var at := _ahead(main, 0.0, 10.0)
	var plane := main.level.add_plane({"a": _vec_array(at), "b": _vec_array(at + Vector3.RIGHT * 4.0), "speed": 0.0})
	await t.wait_ticks(2)
	var altitude := main.tuning.num("plane", "altitude")
	t.near(plane.global_position.y, main.player.global_position.y + altitude, 0.3, "plane is high overhead")
	var command := t.drive(main)
	command.fire_pressed = true
	var hit := await t.wait_until(func() -> bool: return plane.defeated, 40)
	command.fire_pressed = false
	t.is_true(hit, "bolt reached the plane with no aiming input")
	t.equal(main.run_state.score, int(main.tuning.num("score", "plane_bolt")), "plane bolt score")
	await t.stop_game(main)


func test_blocked_line_of_sight_means_no_target(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var counter := _fire_counter(main)
	var duck := main.level.add_duck({"pos": _vec_array(_ahead(main, 0.0, 15.0))})
	await t.wait_ticks(10)
	t.equal(main.player.blaster.current_target, duck, "control: clear line targets it")
	var wall := _add_wall(main, _ahead(main, 0.0, 7.0) + Vector3.UP * 5.0, Vector3(30.0, 10.0, 1.0))
	await t.wait_ticks(10)
	t.equal(main.player.blaster.current_target, null, "wall blocks the target")
	var command := t.drive(main)
	command.fire_pressed = true
	await t.wait_ticks(1)
	command.fire_pressed = false
	var ended := await t.wait_until(func() -> bool: return main.player.blaster.alive_count() == 0, 40)
	t.is_true(ended, "bolt stopped at the wall")
	t.equal(counter["clinks"], 1, "clinked on the wall")
	t.is_true(not duck.defeated, "duck behind the wall is safe")
	wall.queue_free()
	await t.stop_game(main)


func test_bolt_steers_at_most_the_tuned_rate_and_flies_straight_when_target_dies(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var duck := main.level.add_duck({"pos": _vec_array(_ahead(main, 90.0, 9.0))})
	await t.wait_ticks(2)
	var bolt: Bolt = main.player.blaster._bolts[0]
	bolt.launch(main.player.global_position + Vector3.UP, Vector3.FORWARD, duck)
	var limit := deg_to_rad(main.tuning.num("blaster", "steer_degrees")) / 60.0 + 0.0005
	var previous := bolt.direction
	var turned := 0.0
	for _i in 8:
		await t.wait_ticks(1)
		var step := previous.angle_to(bolt.direction)
		t.is_true(step <= limit, "turn per tick %s within %s" % [step, limit])
		turned += step
		previous = bolt.direction
	t.is_true(turned > limit * 7.0, "it did steer at about the limit, %s" % turned)
	duck.bolt_hit()
	await t.wait_ticks(2)
	t.equal(bolt.target, null, "dropped its target")
	var straight := bolt.direction
	await t.wait_ticks(4)
	t.is_true(bolt.direction.is_equal_approx(straight), "flies straight after the target dies")
	await t.stop_game(main)


func test_bolt_breaks_crate_for_50_and_only_clinks_on_boxes(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var counter := _fire_counter(main)
	var y := main.tuning.num("blaster", "muzzle_height")
	var cases := [{"kind": "crate", "hidden": false}, {"kind": "coil", "hidden": false}, {"kind": "life", "hidden": true}]
	var score := 0
	for entry: Dictionary in cases:
		var pos := _ahead(main, 0.0, 5.0) + Vector3.UP * y
		var block := SurpriseBlock.new()
		block.setup(entry["kind"], entry["hidden"], pos)
		main.level.add_child(block)
		var rewards := {"count": 0}
		block.reward_released.connect(func(_k: String, _a: Vector3) -> void: rewards["count"] += 1)
		if entry["kind"] == "crate":
			block.crate_broken.connect(main.level.crate_broken.emit)
		var clinks_before: int = counter["clinks"]
		var command := t.drive(main)
		command.fire_pressed = true
		await t.wait_ticks(1)
		command.fire_pressed = false
		await t.wait_until(func() -> bool: return main.player.blaster.alive_count() == 0, 40)
		t.equal(counter["clinks"], clinks_before + 1, "%s clinks" % entry["kind"])
		t.equal(rewards["count"], 0, "%s releases nothing" % entry["kind"])
		await t.wait_ticks(25)
		if entry["kind"] == "crate":
			score += int(main.tuning.num("run", "score_per_crate"))
			t.is_true(not is_instance_valid(block), "crate broke")
		else:
			t.is_true(not block.used, "%s stays unopened" % entry["kind"])
			t.equal(block.is_hidden_block, entry["hidden"], "%s stays as it was" % entry["kind"])
			block.queue_free()
		t.equal(main.run_state.score, score, "score after %s" % entry["kind"])
		await t.wait_ticks(25)
	await t.stop_game(main)


func test_bolt_box_bumped_from_below_grants_blaster_and_barrel(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var forms: Array[PowerState.Form] = []
	main.player.form_changed.connect(func(form: PowerState.Form) -> void: forms.append(form))
	t.is_true(not main.player._model._barrel.visible, "no barrel when small")
	var above := main.player.global_position + Vector3.UP * 2.7
	main.level.add_block({"pos": [above.x, above.y, above.z], "kind": "bolt"})
	var command := t.drive(main, Vector3.ZERO, true)
	await t.wait_ticks(1)
	command.jump_pressed = false
	var got := await t.wait_until(func() -> bool: return main.player.form() == PowerState.Form.BLASTER, 180)
	t.is_true(got, "picked up the blaster")
	t.equal(forms, [PowerState.Form.BLASTER] as Array[PowerState.Form], "form_changed carries the form")
	t.is_true(main.player.is_coiled(), "is_coiled is true in BLASTER")
	t.is_true(main.player._model._barrel.visible, "barrel shows")
	await t.stop_game(main)


func test_spare_power_ups_score_500_and_change_nothing(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var spare := int(main.tuning.num("score", "spare_power"))
	main.player.apply_power_up()
	t.equal(main.run_state.score, 0, "first coil is not spare")
	main.player.apply_power_up()
	t.equal(main.run_state.score, spare, "coil while coiled")
	main.player.apply_blaster_power()
	t.equal(main.run_state.score, spare, "bolt while coiled is an upgrade")
	main.player.apply_power_up()
	t.equal(main.run_state.score, spare * 2, "coil while blaster")
	t.equal(main.player.form(), PowerState.Form.BLASTER, "coil did not downgrade the blaster")
	main.player.apply_blaster_power()
	t.equal(main.run_state.score, spare * 3, "bolt while blaster")
	await t.stop_game(main)


func test_player_hits_walk_blaster_to_coiled_to_small_to_broken(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var player := main.player
	player.apply_blaster_power()
	player.take_hit()
	t.equal(player.form(), PowerState.Form.COILED, "blaster to coiled")
	t.is_true(player.is_invulnerable(), "invulnerable after the first hit")
	t.is_true(player.is_coiled(), "coiled body stays")
	player.take_hit()
	t.equal(player.form(), PowerState.Form.COILED, "invulnerability honored")
	player._power.invulnerable_left = 0.0
	player.take_hit()
	t.equal(player.form(), PowerState.Form.SMALL, "coiled to small")
	t.is_true(player.is_invulnerable(), "invulnerable after the second hit")
	player._power.invulnerable_left = 0.0
	player.take_hit()
	t.equal(player.form(), PowerState.Form.BROKEN, "small to broken")
	t.is_true(not player.alive, "life lost")
	await t.stop_game(main)


func test_death_removes_bolts_in_flight(t: TestKit) -> void:
	var main: Main = await _armed(t)
	var command := t.drive(main)
	command.fire_pressed = true
	await t.wait_ticks(2)
	command.fire_pressed = false
	t.equal(main.player.blaster.alive_count(), 1, "one in flight")
	main.player.die()
	t.equal(main.player.blaster.alive_count(), 0, "cleared on death")
	await t.stop_game(main)


func _vec_array(at: Vector3) -> Array:
	return [at.x, at.y, at.z]
