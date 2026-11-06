extends RefCounted
## Pure logic for design/expansion-spec.md section 3: the form table and the aim rule.
## Expected values are written out here, not read from the table under test.

const S := PowerState.Form.SMALL
const C := PowerState.Form.COILED
const B := PowerState.Form.BLASTER
const X := PowerState.Form.BROKEN


func _power_in(form: PowerState.Form) -> PowerState:
	var power := PowerState.new(1.5)
	power.form = form
	return power


func _aim() -> BoltAim:
	return BoltAim.new(Tuning.load_from(Tuning.DEFAULT_PATH))


## A point at a given yaw from facing -z, a given horizontal distance away.
func _point_at(yaw_degrees: float, distance: float, height := 0.0) -> Vector3:
	var yaw := deg_to_rad(yaw_degrees)
	return Vector3(sin(yaw) * distance, height, -cos(yaw) * distance)


func test_form_table_coil_pickup_every_form(t: TestKit) -> void:
	var cases := [[S, C, true], [C, C, false], [B, B, false], [X, X, false]]
	for entry: Array in cases:
		var power := _power_in(entry[0])
		t.equal(power.apply_pickup(), entry[2], "coil changed form from %s" % entry[0])
		t.equal(power.form, entry[1], "coil result from %s" % entry[0])


func test_form_table_bolt_pickup_every_form(t: TestKit) -> void:
	var cases := [[S, B, true], [C, B, true], [B, B, false], [X, X, false]]
	for entry: Array in cases:
		var power := _power_in(entry[0])
		t.equal(power.apply_bolt_pickup(), entry[2], "bolt changed form from %s" % entry[0])
		t.equal(power.form, entry[1], "bolt result from %s" % entry[0])


func test_form_table_hit_every_form(t: TestKit) -> void:
	var cases := [
		[S, X, PowerState.HitResult.FATAL, false],
		[C, S, PowerState.HitResult.SHRUNK, true],
		[B, C, PowerState.HitResult.SHRUNK, true],
		[X, X, PowerState.HitResult.IGNORED, false],
	]
	for entry: Array in cases:
		var power := _power_in(entry[0])
		t.equal(power.apply_hit(), entry[2], "hit result from %s" % entry[0])
		t.equal(power.form, entry[1], "hit form from %s" % entry[0])
		t.equal(power.is_invulnerable(), entry[3], "invulnerable after hit from %s" % entry[0])


func test_hits_walk_down_the_ladder_one_step_at_a_time(t: TestKit) -> void:
	var power := _power_in(B)
	t.equal(power.apply_hit(), PowerState.HitResult.SHRUNK, "blaster hit")
	t.equal(power.form, C, "blaster to coiled")
	t.near(power.invulnerable_left, 1.5, 0.001, "invulnerable length")
	t.equal(power.apply_hit(), PowerState.HitResult.IGNORED, "second hit during invulnerability")
	t.equal(power.form, C, "still coiled")
	power.tick(1.6)
	t.equal(power.apply_hit(), PowerState.HitResult.SHRUNK, "coiled hit")
	t.equal(power.form, S, "coiled to small")
	power.tick(1.6)
	t.equal(power.apply_hit(), PowerState.HitResult.FATAL, "small hit")
	t.equal(power.form, X, "small to broken")


func test_coil_body_is_true_in_coiled_and_blaster_only(t: TestKit) -> void:
	t.is_true(not _power_in(S).has_coil_body(), "small")
	t.is_true(_power_in(C).has_coil_body(), "coiled")
	t.is_true(_power_in(B).has_coil_body(), "blaster")
	t.is_true(not _power_in(X).has_coil_body(), "broken")


func test_aim_allows_29_degrees_at_17_m_only(t: TestKit) -> void:
	var aim := _aim()
	var facing := Vector3.FORWARD
	t.is_true(aim.score(Vector3.ZERO, facing, _point_at(29.0, 17.0)) != BoltAim.OUT_OF_CONE, "29 degrees, 17 m")
	t.is_true(aim.score(Vector3.ZERO, facing, _point_at(-29.0, 17.0)) != BoltAim.OUT_OF_CONE, "-29 degrees, 17 m")
	t.equal(aim.score(Vector3.ZERO, facing, _point_at(31.0, 17.0)), BoltAim.OUT_OF_CONE, "31 degrees")
	t.equal(aim.score(Vector3.ZERO, facing, _point_at(-31.0, 17.0)), BoltAim.OUT_OF_CONE, "-31 degrees")
	t.equal(aim.score(Vector3.ZERO, facing, _point_at(29.0, 19.0)), BoltAim.OUT_OF_CONE, "19 m")


func test_aim_height_window_is_minus_5_to_plus_9_and_ignores_height_in_score(t: TestKit) -> void:
	var aim := _aim()
	var facing := Vector3.FORWARD
	var flat := aim.score(Vector3.ZERO, facing, _point_at(10.0, 9.0))
	t.near(aim.score(Vector3.ZERO, facing, _point_at(10.0, 9.0, 8.9)), flat, 0.0001, "height does not change the score")
	t.is_true(aim.score(Vector3.ZERO, facing, _point_at(10.0, 9.0, -4.9)) != BoltAim.OUT_OF_CONE, "just under -5")
	t.equal(aim.score(Vector3.ZERO, facing, _point_at(10.0, 9.0, 9.1)), BoltAim.OUT_OF_CONE, "above +9")
	t.equal(aim.score(Vector3.ZERO, facing, _point_at(10.0, 9.0, -5.1)), BoltAim.OUT_OF_CONE, "below -5")


func test_aim_score_is_yaw_over_30_plus_distance_over_18_scaled(t: TestKit) -> void:
	var aim := _aim()
	var score := aim.score(Vector3.ZERO, Vector3.FORWARD, _point_at(15.0, 9.0))
	t.near(score, 0.5 + 0.5, 0.0001, "formula")
	t.near(aim.score(Vector3.ZERO, Vector3.FORWARD, _point_at(15.0, 9.0), 0.5), 0.5, 0.0001, "weak spot scale")


func test_bolt_scores_never_exceed_half_a_stomp(t: TestKit) -> void:
	var tuning := Tuning.load_from(Tuning.DEFAULT_PATH)
	t.is_true(tuning.num("score", "bolt_gear") * 2.0 <= tuning.num("run", "score_per_stomp"), "gear")
	t.is_true(tuning.num("score", "plane_bolt") * 2.0 <= tuning.num("score", "plane_stomp"), "plane")
	t.is_true(tuning.num("score", "duck_bolt") * 2.0 <= tuning.num("score", "duck_stomp"), "duck")
	t.is_true(tuning.num("score", "teeth_bolt") * 2.0 <= tuning.num("score", "teeth_stomp"), "teeth")
	var armored_total := tuning.num("score", "armor_stomp_1") + tuning.num("score", "armor_stomp_2")
	t.is_true(tuning.num("score", "bolt_armored") * 2.0 <= armored_total, "armored")


func test_level_one_file_is_byte_identical(t: TestKit) -> void:
	t.equal(
		FileAccess.get_sha256(Level.DEFAULT_PATH),
		"b1df8db811fa1a45862381669a86c7285c14e38af11d5735424a36b2992c17fe",
		"level_workshop_01.json hash"
	)
