extends RefCounted
## The four new enemies and their shots in the real game scene.
## Implements acceptance criterion 7 of design/expansion-spec.md section 8.


func _vec_array(at: Vector3) -> Array:
	return [at.x, at.y, at.z]


func _ahead(main: Main, x: float, z_ahead: float) -> Vector3:
	return main.player.global_position * Vector3(1.0, 0.0, 1.0) + Vector3(x, t_floor(main), -z_ahead)


func t_floor(_main: Main) -> float:
	return TestKit.ARENA_Y


func _beetle(main: Main, at: Vector3, armored: bool, speed := 0.0) -> GearBeetle:
	return main.level.add_beetle({
		"a": _vec_array(at), "b": _vec_array(at + Vector3.RIGHT * 6.0), "speed": speed, "armored": armored,
	})


## Drops Tock onto an enemy from just above its box. Returns true once he bounces.
func _stomp(t: TestKit, main: Main, enemy: EnemyBase, above := 0.3) -> bool:
	main.player.velocity = Vector3.ZERO
	main.player.global_position = enemy.global_position + Vector3.UP * (enemy.bolt_bounds().size.y + above)
	return await t.wait_until(func() -> bool: return main.player.velocity.y > 1.0, 60)


## Fires real bolts at a target ahead of Tock until it is defeated.
func _shoot(t: TestKit, main: Main, enemy: EnemyBase) -> bool:
	main.player.apply_blaster_power()
	await t.wait_ticks(11)
	var command := t.drive(main)
	command.fire_pressed = true
	var done := await t.wait_until(func() -> bool: return enemy.defeated, 60)
	command.fire_pressed = false
	return done


## Walks Tock into an enemy from the side at floor level.
func _walk_into(t: TestKit, main: Main, enemy: EnemyBase) -> bool:
	var hurt := {"yes": false}
	main.player.hurt.connect(func() -> void: hurt["yes"] = true)
	main.player.global_position = enemy.global_position + Vector3(0.0, 0.2, 2.2)
	main.player.velocity = Vector3.ZERO
	t.drive(main, Vector3.FORWARD)
	return await t.wait_until(func() -> bool: return bool(hurt["yes"]), 60)


func _gone(t: TestKit, enemy: EnemyBase) -> bool:
	# No lambda: one capturing the enemy logs an error once the enemy is freed.
	for _i in 150:
		if not is_instance_valid(enemy):
			return true
		await t.wait_ticks(1)
	return not is_instance_valid(enemy)


## Ticks counted while a condition holds, from when it starts. Fails the wait after max_ticks.
func _ticks_while(t: TestKit, condition: Callable, max_ticks: int) -> int:
	await t.wait_until(condition, max_ticks)
	var count := 0
	while bool(condition.call()) and count < max_ticks:
		await t.wait_ticks(1)
		count += 1
	return count


# Armored beetle

func test_armored_takes_exactly_two_stomps_scoring_100_then_300(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var beetle: ArmoredBeetle = _beetle(main, _ahead(main, 0.0, 3.0), true)
	var lives := main.run_state.lives
	t.is_true(await _stomp(t, main, beetle), "first stomp bounces")
	t.equal(main.run_state.score, 100, "first stomp score")
	t.equal(beetle.state, ArmoredBeetle.State.PANIC, "lid off, panicking")
	t.is_true(not beetle.defeated, "survives the first stomp")
	t.is_true(not beetle.has_lid(), "lid is off")
	t.is_true(beetle._gear.visible, "gear shows once the lid is off")
	await t.wait_ticks(int(main.tuning.num("armored", "stomp_immunity") * 60.0) + 2)
	t.is_true(await _stomp(t, main, beetle), "second stomp bounces")
	t.equal(main.run_state.score, 400, "second stomp score")
	t.is_true(beetle.defeated, "second stomp squashes")
	t.equal(main.run_state.lives, lives, "no life lost")
	t.equal(main.player.form(), PowerState.Form.SMALL, "no hit taken")
	t.is_true(await _gone(t, beetle), "removed")
	await t.stop_game(main)


func test_armored_immunity_blocks_an_early_second_stomp_without_hurting(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var beetle: ArmoredBeetle = _beetle(main, _ahead(main, 0.0, 3.0), true)
	await _stomp(t, main, beetle)
	# Back on top immediately, while the immunity runs.
	main.player.velocity = Vector3.DOWN * 2.0
	main.player.fall_velocity_y = -2.0
	main.player.global_position = beetle.global_position + Vector3.UP * 0.7
	await t.wait_ticks(3)
	t.is_true(beetle._immune_left > 0.0, "still inside the immunity")
	t.is_true(not beetle.defeated, "no squash during immunity")
	t.equal(main.run_state.score, 100, "no extra score")
	t.is_true(main.player.alive, "contact during immunity does not hurt")
	await t.stop_game(main)


func test_armored_panics_at_1_5_speed_for_3_s_then_calms(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var start := _ahead(main, 0.0, 3.0)
	var beetle: ArmoredBeetle = _beetle(main, start, true, 2.0)
	beetle.position = start
	await t.wait_ticks(1)
	var calm := beetle.global_position
	await t.wait_ticks(30)
	var calm_speed := calm.distance_to(beetle.global_position) / 0.5
	t.near(calm_speed, 2.0, 0.1, "patrol speed")
	await _stomp(t, main, beetle)
	main.player.global_position = beetle.global_position + Vector3(0.0, 5.0, 30.0)
	var from := beetle.global_position
	await t.wait_ticks(30)
	t.near(from.distance_to(beetle.global_position) / 0.5, 3.0, 0.15, "panic speed")
	var seconds := main.tuning.num("armored", "panic_seconds")
	await t.wait_ticks(int(seconds * 60.0) - 30 - 3)
	t.equal(beetle.state, ArmoredBeetle.State.PANIC, "still panicking just before the time")
	await t.wait_ticks(6)
	t.equal(beetle.state, ArmoredBeetle.State.NORMAL, "calm after the time")
	from = beetle.global_position
	await t.wait_ticks(30)
	t.near(from.distance_to(beetle.global_position) / 0.5, 2.0, 0.1, "normal speed again")
	await t.stop_game(main)


func test_armored_one_bolt_scores_200_with_lid_100_without(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var lidded: ArmoredBeetle = _beetle(main, _ahead(main, 0.0, 6.0), true)
	t.is_true(await _shoot(t, main, lidded), "one bolt with the lid on")
	t.equal(main.run_state.score, 200, "bolt with lid")
	await _gone(t, lidded)
	var bare: ArmoredBeetle = _beetle(main, _ahead(main, 0.0, 3.0), true)
	await _stomp(t, main, bare)
	var before := main.run_state.score
	bare.bolt_hit()
	t.is_true(bare.defeated, "one bolt with the lid off")
	t.equal(main.run_state.score - before, 100, "bolt without lid")
	await t.stop_game(main)


func test_armored_side_contact_hurts_with_the_lid_on(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	main.player.apply_power_up()
	var beetle: ArmoredBeetle = _beetle(main, _ahead(main, 0.0, 6.0), true)
	t.is_true(await _walk_into(t, main, beetle), "hurt")
	t.equal(main.player.form(), PowerState.Form.SMALL, "coil lost")
	t.equal(beetle.state, ArmoredBeetle.State.ARMORED, "lid stays on")
	await t.stop_game(main)


func test_gear_beetle_one_bolt_scores_100(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var beetle := _beetle(main, _ahead(main, 0.0, 6.0), false)
	t.is_true(await _shoot(t, main, beetle), "one bolt")
	t.equal(main.run_state.score, 100, "gear bolt score")
	t.is_true(await _gone(t, beetle), "removed")
	await t.stop_game(main)


# Paper plane

func _plane_over(main: Main, x: float, z_ahead: float) -> PaperPlane:
	var at := _ahead(main, x, z_ahead)
	return main.level.add_plane({"a": _vec_array(at), "b": _vec_array(at + Vector3.RIGHT * 4.0), "speed": 0.0})


func test_plane_cruises_out_of_reach_of_any_jump(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var plane := _plane_over(main, 0.0, 30.0)
	await t.wait_ticks(5)
	t.equal(plane.state, PaperPlane.State.CRUISE, "cruising far from Tock")
	t.near(plane.global_position.y - TestKit.ARENA_Y, main.tuning.num("plane", "altitude"), 0.001, "altitude")
	var coiled_reach := main.tuning.num("player", "jump_height_coiled") + main.tuning.num("player", "capsule_height_coiled")
	t.is_true(coiled_reach < main.tuning.num("plane", "altitude"), "coiled head at jump peak stays under the plane")
	await t.stop_game(main)


func test_plane_rail_pingpongs_with_u_turn_pause(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var at := _ahead(main, -2.0, 30.0)
	var plane := main.level.add_plane({"a": _vec_array(at), "b": _vec_array(at + Vector3.RIGHT * 2.5), "speed": 5.0})
	var turn_ticks := int(main.tuning.num("plane", "turn_seconds") * 60.0)
	var far_end := await t.wait_until(func() -> bool: return plane.global_position.x >= at.x + 2.49, 60)
	t.is_true(far_end, "reached the far end")
	await t.wait_ticks(turn_ticks - 3)
	t.near(plane.global_position.x, at.x + 2.5, 0.01, "holds position through the U-turn")
	var back := await t.wait_until(func() -> bool: return plane.global_position.x <= at.x + 0.01, 60)
	t.is_true(back, "flew back after the turn")
	await t.stop_game(main)


func test_plane_windup_lasts_tuned_time_before_eraser_falls_and_landing_is_harmless(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var sounds: Array[String] = []
	main.level.enemy_sound.connect(func(sound: String) -> void: sounds.append(sound))
	main.player.apply_power_up()
	var plane := _plane_over(main, 3.0, 0.0)
	var started := await t.wait_until(func() -> bool: return plane.state == PaperPlane.State.WINDUP, 10)
	t.is_true(started, "Tock within the trigger starts the windup")
	t.equal(main.level.shots.alive_count(), 1, "eraser shows under the plane")
	t.is_true("plane_fwip" in sounds, "fwip plays")
	t.is_true(plane._blob.visible, "landing blob shows")
	t.is_true(plane._blob.scale.x > plane._blob_radius * PaperPlane.BLOB_CRUISE_SCALE, "blob grows for the telegraph")
	var eraser := plane._eraser
	var count := 0
	while plane.state == PaperPlane.State.WINDUP and count < 120:
		t.equal(eraser.phase, EnemyShotPool.Shot.Phase.HELD, "eraser is only held during the windup")
		await t.wait_ticks(1)
		count += 1
	t.near(float(count), main.tuning.num("plane", "windup") * 60.0, 1.01, "windup ticks")
	t.equal(eraser.phase, EnemyShotPool.Shot.Phase.FALLING, "eraser drops after the windup")
	var blob_x := plane._blob.global_position.x
	var fall_ticks := await _ticks_while(t, func() -> bool: return eraser.is_falling(), 120)
	t.near(float(fall_ticks), 0.8 * 60.0, 6.0, "about 0.8 s fall")
	t.near(plane._blob.global_position.x, blob_x, 0.01, "blob froze under the falling eraser")
	t.is_true("eraser_boing" in sounds, "boing on landing")
	t.equal(main.level.shots.alive_count(), 0, "eraser is gone")
	t.equal(main.player.form(), PowerState.Form.COILED, "Tock to one side took no hit")
	await t.stop_game(main)


func test_plane_cooldown_stops_a_second_drop_too_soon(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var plane := _plane_over(main, 3.0, 0.0)
	await t.wait_until(func() -> bool: return plane.state == PaperPlane.State.SWOOP_DOWN, 60)
	var cooldown_ticks := int(main.tuning.num("plane", "cooldown") * 60.0)
	var windups := {"seen": 0}
	for _i in cooldown_ticks - 5:
		await t.wait_ticks(1)
		if plane.state == PaperPlane.State.WINDUP:
			windups["seen"] += 1
	t.equal(windups["seen"], 0, "no windup inside the cooldown")
	var again := await t.wait_until(func() -> bool: return plane.state == PaperPlane.State.WINDUP, 30)
	t.is_true(again, "attacks again after the cooldown")
	await t.stop_game(main)


func test_eraser_hits_tock_standing_under_it(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	main.player.apply_power_up()
	var plane := _plane_over(main, 0.0, 0.0)
	await t.wait_until(func() -> bool: return plane.state == PaperPlane.State.SWOOP_DOWN, 60)
	var hit := await t.wait_until(func() -> bool: return main.player.form() == PowerState.Form.SMALL, 90)
	t.is_true(hit, "eraser hurts on the way down")
	t.equal(main.level.shots.alive_count(), 0, "eraser spent")
	await t.stop_game(main)


func test_plane_can_be_stomped_at_swoop_and_scores_500(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var plane := _plane_over(main, 3.0, 0.0)
	var low := await t.wait_until(func() -> bool: return plane.state == PaperPlane.State.SWOOP_HOLD, 120)
	t.is_true(low, "reaches the bottom of the swoop")
	t.near(plane.global_position.y - TestKit.ARENA_Y, main.tuning.num("plane", "swoop_altitude"), 0.01, "swoop altitude")
	# This plane is held still, so its eraser is still falling right under it. Let that land first.
	await t.wait_until(func() -> bool: return main.level.shots.alive_count() == 0, 30)
	t.equal(plane.state, PaperPlane.State.SWOOP_HOLD, "still low once the eraser has landed")
	# Comes down from a jump peak: the spec's 3.6, over the box base of 3.0 plus margin 0.35.
	main.player.velocity = Vector3.ZERO
	main.player.fall_velocity_y = 0.0
	main.player.global_position = Vector3(
		plane.global_position.x, TestKit.ARENA_Y + main.tuning.num("player", "jump_height_small"), plane.global_position.z
	)
	var bounced := await t.wait_until(func() -> bool: return main.player.velocity.y > 1.0, 30)
	t.is_true(bounced, "stomp from a small jump's peak works")
	t.equal(main.run_state.score, 500, "plane stomp score")
	t.is_true(plane.defeated, "one stomp")
	t.equal(main.player.form(), PowerState.Form.SMALL, "not hurt")
	t.is_true(main.player.alive, "not killed")
	t.is_true(await _gone(t, plane), "removed")
	await t.stop_game(main)


## Regression: the overlap is reported about two ticks late. With a window this thin, checking only
## the current feet turned a legal stomp into a death. Harder falls stand in for a coiled jump or
## a bounce.
func test_plane_stomp_counts_from_a_fast_fall(t: TestKit) -> void:
	for above: float in [0.1, 0.6, 1.5, 3.0, 9.0]:
		var main: Main = await t.start_arena()
		var plane := _plane_over(main, 3.0, 0.0)
		await t.wait_until(func() -> bool: return plane.state == PaperPlane.State.SWOOP_HOLD, 120)
		await t.wait_until(func() -> bool: return main.level.shots.alive_count() == 0, 30)
		plane._state_left = 2.0
		t.is_true(await _stomp(t, main, plane, above), "stomp from %s above" % above)
		t.is_true(plane.defeated, "defeated from %s above" % above)
		t.is_true(main.player.alive, "alive from %s above" % above)
		await t.stop_game(main)


func test_side_contact_low_down_while_falling_is_still_a_hit(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	main.player.apply_power_up()
	var beetle := _beetle(main, _ahead(main, 0.0, 6.0), false)
	# Feet below the stomp line throughout, so falling alone earns nothing.
	main.player.global_position = beetle.global_position + Vector3(0.9, 0.25, 0.0)
	main.player.velocity = Vector3.ZERO
	await t.wait_ticks(2)
	var hit := await t.wait_until(func() -> bool: return main.player.form() == PowerState.Form.SMALL, 30)
	t.is_true(hit, "hurt from the side")
	t.is_true(not beetle.defeated, "beetle unharmed")
	await t.stop_game(main)


func test_plane_side_contact_hurts_at_the_swoop(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	main.player.apply_power_up()
	var plane := _plane_over(main, 3.0, 0.0)
	await t.wait_until(func() -> bool: return plane.state == PaperPlane.State.SWOOP_HOLD, 120)
	# Rising into it from below is a hit, however close the feet are to the stomp line.
	main.player.global_position = plane.global_position + Vector3.DOWN * 1.8
	main.player.velocity = Vector3.UP * 8.0
	var hit := await t.wait_until(func() -> bool: return main.player.form() == PowerState.Form.SMALL, 30)
	t.is_true(hit, "contact from below hurts")
	t.is_true(not plane.defeated, "plane unharmed")
	await t.stop_game(main)


func test_plane_at_the_shot_cap_skips_its_attack_and_enters_cooldown(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var held: Array = []
	for _i in int(main.tuning.num("limits", "max_enemy_shots")):
		held.append(main.level.shots.acquire_eraser())
	var plane := _plane_over(main, 3.0, 0.0)
	await t.wait_ticks(20)
	t.equal(plane.state, PaperPlane.State.CRUISE, "no windup at the cap")
	t.is_true(plane._cooldown_left > 0.0, "entered cooldown")
	t.equal(main.level.shots.alive_count(), held.size(), "no extra shot")
	await t.stop_game(main)


func test_plane_bolted_during_windup_gives_back_its_eraser(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var plane := _plane_over(main, 3.0, 0.0)
	await t.wait_until(func() -> bool: return plane.state == PaperPlane.State.WINDUP, 10)
	t.equal(main.level.shots.alive_count(), 1, "eraser held")
	plane.bolt_hit()
	t.equal(main.level.shots.alive_count(), 0, "eraser returned")
	await t.stop_game(main)


# Rubber duck

func test_duck_squeaks_tuned_time_before_any_bubble(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var duck := main.level.add_duck({"pos": _vec_array(_ahead(main, 0.0, 10.0))})
	var started := await t.wait_until(func() -> bool: return duck.state == RubberDuck.State.SQUEAK, 30)
	t.is_true(started, "sees Tock in range")
	var count := 0
	var peak := 1.0
	while duck.state == RubberDuck.State.SQUEAK and count < 120:
		t.equal(main.level.shots.alive_count(), 0, "no bubble during the squeak")
		peak = maxf(peak, duck._model.scale.x)
		await t.wait_ticks(1)
		count += 1
	t.near(float(count), main.tuning.num("duck", "squeak") * 60.0, 1.01, "squeak ticks")
	t.near(peak, main.tuning.num("duck", "inflate_scale"), 0.03, "inflates to the tuned scale")
	t.equal(main.level.shots.alive_count(), 1, "bubble after the squeak")
	t.equal(duck.state, RubberDuck.State.DEFLATE, "deflating")
	var deflate := await _ticks_while(t, func() -> bool: return duck.state == RubberDuck.State.DEFLATE, 120)
	t.near(float(deflate), main.tuning.num("duck", "deflate") * 60.0, 1.01, "deflate ticks")
	var cool := await _ticks_while(t, func() -> bool: return duck.state == RubberDuck.State.COOLDOWN, 200)
	t.near(float(cool), main.tuning.num("duck", "cooldown") * 60.0, 1.01, "cooldown ticks")
	await t.stop_game(main)


func test_duck_aim_locks_before_the_end_so_a_sidestep_dodges(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	main.player.apply_power_up()
	var duck := main.level.add_duck({"pos": _vec_array(_ahead(main, 0.0, 6.0))})
	await t.wait_until(func() -> bool: return duck.state == RubberDuck.State.SQUEAK, 30)
	var lock := main.tuning.num("duck", "aim_lock")
	await t.wait_until(func() -> bool: return duck._state_left <= lock - 0.03, 120)
	var locked := duck._aim_at
	# Sidestep the spec's 1.2 m once the aim has locked.
	var at_lock := main.player.global_position
	main.player.global_position = at_lock + Vector3.RIGHT * 1.2
	await t.wait_until(func() -> bool: return duck.state == RubberDuck.State.DEFLATE, 30)
	t.is_true(duck._aim_at.is_equal_approx(locked), "aim did not follow after the lock")
	var bubble: EnemyShotPool.Shot = main.level.shots._shots[0]
	t.equal(bubble.kind, EnemyShotPool.Shot.Kind.BUBBLE, "a bubble")
	await t.wait_until(func() -> bool: return bubble.phase == EnemyShotPool.Shot.Phase.FREE, 180)
	t.equal(main.player.form(), PowerState.Form.COILED, "the dodge worked")
	await t.stop_game(main)


func test_bubble_hits_tock_who_stays_put(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	main.player.apply_power_up()
	main.level.add_duck({"pos": _vec_array(_ahead(main, 0.0, 6.0))})
	var hit := await t.wait_until(func() -> bool: return main.player.form() == PowerState.Form.SMALL, 240)
	t.is_true(hit, "bubble hits a still target")
	t.equal(main.level.shots.alive_count(), 0, "bubble popped on him")
	await t.stop_game(main)


func test_duck_ignores_tock_out_of_range_or_behind_a_wall(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var far := main.level.add_duck({"pos": _vec_array(_ahead(main, 0.0, 17.0))})
	await t.wait_ticks(30)
	t.equal(far.state, RubberDuck.State.IDLE, "17 m is out of range")
	far.queue_free()
	var near := main.level.add_duck({"pos": _vec_array(_ahead(main, 0.0, 8.0))})
	var wall := StaticBody3D.new()
	wall.collision_layer = Player.LAYER_WORLD
	wall.position = _ahead(main, 0.0, 4.0) + Vector3.UP * 3.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 6.0, 1.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	wall.add_child(collider)
	main.level.add_child(wall)
	await t.wait_ticks(30)
	t.equal(near.state, RubberDuck.State.IDLE, "no sight through a wall")
	wall.queue_free()
	var saw := await t.wait_until(func() -> bool: return near.state == RubberDuck.State.SQUEAK, 30)
	t.is_true(saw, "control: squeaks once the wall is gone")
	await t.stop_game(main)


func test_duck_stomp_scores_300_and_bolt_scores_150(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var duck := main.level.add_duck({"pos": _vec_array(_ahead(main, 0.0, 15.5))})
	t.is_true(await _stomp(t, main, duck), "bounces")
	t.equal(main.run_state.score, 300, "stomp score")
	t.is_true(duck.defeated, "one stomp")
	t.is_true(await _gone(t, duck), "removed")
	main.player.global_position = Vector3(0.0, TestKit.ARENA_Y + 0.2, 0.0)
	await t.wait_ticks(10)
	var second := main.level.add_duck({"pos": _vec_array(_ahead(main, 0.0, 8.0))})
	var before := main.run_state.score
	t.is_true(await _shoot(t, main, second), "one bolt")
	t.equal(main.run_state.score - before, 150, "bolt score")
	await t.stop_game(main)


func test_duck_side_contact_hurts(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	main.player.apply_power_up()
	var duck := main.level.add_duck({"pos": _vec_array(_ahead(main, 0.0, 8.0))})
	t.is_true(await _walk_into(t, main, duck), "hurt")
	t.is_true(not duck.defeated, "duck unharmed")
	await t.stop_game(main)


func test_bubble_stomp_pops_bounces_and_scores_50(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var from := _ahead(main, 0.0, 12.0) + Vector3.UP * 1.0
	var bubble := main.level.shots.fire_bubble(from, from + Vector3.BACK)
	var top := bubble.global_position.y + bubble.radius
	main.player.velocity = Vector3.ZERO
	# Ahead of the bubble, so it arrives under his feet as he comes down.
	main.player.global_position = Vector3(from.x, top + 0.2, from.z + 0.9)
	var bounced := await t.wait_until(func() -> bool: return main.player.velocity.y > 1.0, 30)
	t.is_true(bounced, "bounces off the bubble")
	t.equal(main.run_state.score, 50, "bubble stomp score")
	t.equal(main.level.shots.alive_count(), 0, "bubble popped")
	t.equal(main.player.form(), PowerState.Form.SMALL, "not hurt")
	t.is_true(main.player.alive, "not killed")
	await t.stop_game(main)


func test_bubble_range_and_world_pop_and_bolt_pop_without_being_a_target(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	main.player.global_position += Vector3.RIGHT * 30.0
	await t.wait_ticks(2)
	var from := Vector3(0.0, TestKit.ARENA_Y + 1.0, 0.0)
	var bubble := main.level.shots.fire_bubble(from, from + Vector3.FORWARD)
	var flight := await _ticks_while(t, func() -> bool: return bubble.phase == EnemyShotPool.Shot.Phase.FLYING, 200)
	t.near(float(flight), 2.5 * 60.0, 2.0, "2.5 s of flight")
	var down := main.level.shots.fire_bubble(from, from + Vector3.DOWN)
	var popped := await t.wait_until(func() -> bool: return down.phase == EnemyShotPool.Shot.Phase.FREE, 30)
	t.is_true(popped, "pops on the floor")
	await t.stop_game(main)
	main = await t.start_arena()
	main.player.apply_blaster_power()
	await t.wait_ticks(11)
	var muzzle := main.player.global_position + Vector3(0.0, main.tuning.num("blaster", "muzzle_height"), -9.0)
	var ahead := main.level.shots.fire_bubble(muzzle, muzzle + Vector3.FORWARD)
	await t.wait_ticks(5)
	t.equal(main.player.blaster.current_target, null, "a bubble is never the target")
	var command := t.drive(main)
	command.fire_pressed = true
	await t.wait_ticks(1)
	command.fire_pressed = false
	var hit := await t.wait_until(func() -> bool: return ahead.phase == EnemyShotPool.Shot.Phase.FREE, 45)
	t.is_true(hit, "a bolt pops it")
	t.equal(main.run_state.score, 0, "popping by bolt scores nothing")
	await t.stop_game(main)


# Chattering teeth

func test_teeth_state_times_and_hop_distance_follow_tuning(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var start := _ahead(main, 0.0, 13.0)
	var teeth := main.level.add_teeth({"pos": _vec_array(start)})
	await t.wait_ticks(1)
	var woke := await t.wait_until(func() -> bool: return teeth.state == ChatteringTeeth.State.WIND, 10)
	t.is_true(woke, "wakes within the trigger")
	var wind := 0
	while teeth.state == ChatteringTeeth.State.WIND and wind < 60:
		t.is_true(teeth.global_position.is_equal_approx(start), "stands still in the wind-up")
		await t.wait_ticks(1)
		wind += 1
	t.near(float(wind), main.tuning.num("teeth", "wind") * 60.0, 1.01, "wind ticks")
	var hop_ticks := main.tuning.num("teeth", "hop_seconds") * 60.0
	var land_ticks := main.tuning.num("teeth", "land") * 60.0
	var distance := main.tuning.num("teeth", "hop_distance")
	var peak := 0.0
	for hop in int(main.tuning.num("teeth", "hops")):
		var from := teeth.global_position
		var count := 0
		while teeth.state == ChatteringTeeth.State.HOP and count < 60:
			peak = maxf(peak, teeth.global_position.y - TestKit.ARENA_Y)
			await t.wait_ticks(1)
			count += 1
		t.near(float(count), hop_ticks, 1.01, "hop %d ticks" % hop)
		t.near(from.distance_to(teeth.global_position), distance, 0.01, "hop %d length" % hop)
		count = 0
		while teeth.state == ChatteringTeeth.State.LAND and count < 60:
			await t.wait_ticks(1)
			count += 1
		t.near(float(count), land_ticks, 1.01, "land %d ticks" % hop)
	t.near(peak, main.tuning.num("teeth", "hop_height"), 0.05, "arc height")
	t.equal(teeth.state, ChatteringTeeth.State.TIRED, "tired after the last hop")
	var tired := 0
	while teeth.state == ChatteringTeeth.State.TIRED and tired < 200:
		await t.wait_ticks(1)
		tired += 1
	t.near(float(tired), main.tuning.num("teeth", "tired") * 60.0, 1.01, "tired ticks")
	t.equal(teeth.state, ChatteringTeeth.State.WIND, "Tock in reach: winds up again")
	await t.stop_game(main)


func test_teeth_go_dormant_when_tock_escapes_and_stay_dormant_out_of_range(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var teeth := main.level.add_teeth({"pos": _vec_array(_ahead(main, 0.0, 15.0))})
	await t.wait_ticks(20)
	t.equal(teeth.state, ChatteringTeeth.State.DORMANT, "15 m is outside the trigger")
	main.player.global_position += Vector3.FORWARD * 3.0
	var woke := await t.wait_until(func() -> bool: return teeth.state == ChatteringTeeth.State.WIND, 10)
	t.is_true(woke, "control: wakes inside the trigger")
	main.player.global_position += Vector3.BACK * 25.0
	var tired := await t.wait_until(func() -> bool: return teeth.state == ChatteringTeeth.State.TIRED, 300)
	t.is_true(tired, "runs down")
	var slept := await t.wait_until(func() -> bool: return teeth.state == ChatteringTeeth.State.DORMANT, 120)
	t.is_true(slept, "goes dormant with Tock beyond keep_chasing")
	await t.stop_game(main)


func test_teeth_stay_on_the_floor_and_laugh_at_a_ledge(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var edge_x := TestKit.ARENA_SIZE * 0.5
	main.player.global_position = Vector3(edge_x + 8.0, TestKit.ARENA_Y + 3.0, 0.0)
	var ledge := t.add_slab(main, Vector3(edge_x + 8.0, TestKit.ARENA_Y - 1.0, 0.0), Vector3(8.0, 2.0, 8.0))
	var start := Vector3(edge_x - 0.8, TestKit.ARENA_Y, 0.0)
	var teeth := main.level.add_teeth({"pos": _vec_array(start)})
	var hopped := await t.wait_until(func() -> bool: return teeth.state == ChatteringTeeth.State.HOP, 60)
	t.is_true(hopped, "tries to hop")
	t.is_true(teeth.at_ledge, "sees no floor ahead")
	var tired := await t.wait_until(func() -> bool: return teeth.state == ChatteringTeeth.State.TIRED, 240)
	t.is_true(tired, "finishes its cycles")
	t.near(teeth.global_position.x, start.x, 0.001, "stayed at the edge")
	t.near(teeth.global_position.y, start.y, 0.001, "still on the floor")
	ledge.queue_free()
	await t.stop_game(main)


func test_teeth_one_stomp_in_any_state_scores_300(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var states := [
		ChatteringTeeth.State.DORMANT, ChatteringTeeth.State.WIND, ChatteringTeeth.State.HOP,
		ChatteringTeeth.State.LAND, ChatteringTeeth.State.TIRED,
	]
	var score := 0
	for state: ChatteringTeeth.State in states:
		main.player.global_position = Vector3(0.0, TestKit.ARENA_Y + 0.2, 0.0)
		main.player.velocity = Vector3.ZERO
		await t.wait_ticks(25)
		var distance := 18.0 if state == ChatteringTeeth.State.DORMANT else 10.0
		var teeth := main.level.add_teeth({"pos": _vec_array(_ahead(main, 0.0, distance))})
		teeth._hop_distance = 0.0
		var reached := await t.wait_until(func() -> bool: return teeth.state == state, 240)
		t.is_true(reached, "reached state %d" % state)
		t.is_true(await _stomp(t, main, teeth, 0.1), "bounce in state %d" % state)
		t.is_true(teeth.defeated, "defeated in state %d" % state)
		score += 300
		t.equal(main.run_state.score, score, "score in state %d" % state)
		await _gone(t, teeth)
	t.equal(main.player.form(), PowerState.Form.SMALL, "never hurt")
	t.is_true(main.player.alive, "never killed")
	await t.stop_game(main)


func test_teeth_one_bolt_scores_150(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var teeth := main.level.add_teeth({"pos": _vec_array(_ahead(main, 0.0, 8.0))})
	t.is_true(await _shoot(t, main, teeth), "one bolt")
	t.equal(main.run_state.score, 150, "bolt score")
	t.is_true(await _gone(t, teeth), "removed")
	await t.stop_game(main)


func test_teeth_side_contact_hurts_even_when_tired(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	main.player.apply_power_up()
	var teeth := main.level.add_teeth({"pos": _vec_array(_ahead(main, 0.0, 10.0))})
	teeth._hop_distance = 0.0
	await t.wait_until(func() -> bool: return teeth.state == ChatteringTeeth.State.TIRED, 240)
	teeth._state_left = 100.0
	t.is_true(await _walk_into(t, main, teeth), "hurt by tired teeth")
	t.equal(teeth.state, ChatteringTeeth.State.TIRED, "was tired at the time")
	await t.stop_game(main)


# Shared rules

func test_enemy_shots_reach_but_never_exceed_the_shared_cap(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	# A blinking Tock: every shot flies its full course, so the only limit left is the cap.
	main.player._power.invulnerable_left = 1000.0
	var ducks: Array[RubberDuck] = []
	for i in 6:
		var angle := TAU * i / 6.0
		var at := main.player.global_position * Vector3(1.0, 0.0, 1.0) + Vector3(sin(angle) * 14.0, TestKit.ARENA_Y, cos(angle) * 14.0)
		ducks.append(main.level.add_duck({"pos": _vec_array(at)}))
	var plane := _plane_over(main, 3.0, 0.0)
	plane._cooldown_left = 0.5
	var shots := main.level.shots
	var highest := 0
	var skipped := 0
	var previous_states: Array[int] = []
	for duck in ducks:
		previous_states.append(duck.state)
	for _i in 180:
		await t.wait_ticks(1)
		highest = maxi(highest, shots.alive_count())
		for d in ducks.size():
			if previous_states[d] == RubberDuck.State.SQUEAK and ducks[d].state == RubberDuck.State.COOLDOWN:
				skipped += 1
			previous_states[d] = ducks[d].state
	t.equal(highest, int(main.tuning.num("limits", "max_enemy_shots")), "cap reached and held")
	t.is_true(skipped >= 2, "ducks over the cap skipped their shot, %d" % skipped)
	await t.stop_game(main)


func test_erasers_and_bubbles_draw_from_one_cap(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var shots := main.level.shots
	var from := Vector3(0.0, TestKit.ARENA_Y + 40.0, 0.0)
	t.is_true(shots.acquire_eraser() != null, "eraser 1")
	t.is_true(shots.acquire_eraser() != null, "eraser 2")
	t.is_true(shots.fire_bubble(from, from + Vector3.FORWARD) != null, "bubble 3")
	t.is_true(shots.fire_bubble(from, from + Vector3.FORWARD) != null, "bubble 4")
	t.equal(shots.fire_bubble(from, from + Vector3.FORWARD), null, "fifth bubble refused")
	t.equal(shots.acquire_eraser(), null, "fifth eraser refused")
	await t.stop_game(main)


func test_death_removes_enemy_shots(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var from := Vector3(30.0, TestKit.ARENA_Y + 3.0, 0.0)
	main.level.shots.fire_bubble(from, from + Vector3.FORWARD)
	t.equal(main.level.shots.alive_count(), 1, "one bubble")
	main.player.die()
	t.equal(main.level.shots.alive_count(), 0, "cleared on death")
	await t.stop_game(main)


func test_level_builds_new_enemies_from_data_and_removes_them_all(t: TestKit) -> void:
	var main: Main = await t.start_game()
	t.equal(main.level.enemies.size(), 0, "level 1 has no new enemies")
	t.equal(main.level.beetles.size(), 9, "level 1 keeps its beetles")
	var data := Tuning.load_json(Level.DEFAULT_PATH)
	(data["beetles"] as Array).append({"a": [0, 0, 0], "b": [1, 0, 0], "speed": 2.0, "armored": true})
	data["planes"] = [{"a": [0, 0, -5], "b": [4, 0, -5], "speed": 5.0}]
	data["ducks"] = [{"pos": [2, 0, -6]}]
	data["teeth"] = [{"pos": [-2, 0, -6]}]
	var level := Level.new()
	level.build(data, main.tuning)
	main.add_child(level)
	await t.wait_ticks(1)
	t.equal(level.enemies.size(), 3, "plane, duck, teeth")
	t.is_true(level.beetles[-1] is ArmoredBeetle, "armored flag builds an armored beetle")
	t.is_true(not (level.beetles[0] is ArmoredBeetle), "no flag builds a gear beetle")
	level.remove_enemies()
	await t.wait_ticks(2)
	t.equal(level.enemies.size(), 0, "enemies removed")
	t.equal(level.beetles.size(), 0, "beetles removed")
	level.queue_free()
	await t.stop_game(main)


func test_new_enemies_stop_drawing_at_the_cull_distance_in_every_part(t: TestKit) -> void:
	var main: Main = await t.start_arena()
	var at := _ahead(main, 0.0, 40.0)
	var cull := main.tuning.num("limits", "enemy_cull_distance")
	var list: Array[EnemyBase] = [
		_beetle(main, at, true),
		main.level.add_plane({"a": _vec_array(at), "b": _vec_array(at + Vector3.RIGHT), "speed": 0.0}),
		main.level.add_duck({"pos": _vec_array(at)}),
		main.level.add_teeth({"pos": _vec_array(at)}),
	]
	for enemy in list:
		var parts := enemy.find_children("*", "MeshInstance3D", true, false)
		t.is_true(parts.size() >= 2, "%s has parts" % enemy.get_script().get_global_name())
		for part: Node in parts:
			t.equal((part as MeshInstance3D).visibility_range_end, cull, "%s %s" % [enemy.get_script().get_global_name(), part.name])
	await t.stop_game(main)
