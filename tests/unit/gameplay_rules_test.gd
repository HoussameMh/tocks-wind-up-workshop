extends RefCounted
## Pure logic tests: no scene tree or physics.


func _tuning() -> Tuning:
	return Tuning.load_from(Tuning.DEFAULT_PATH)


func test_small_hit_is_fatal(t: TestKit) -> void:
	var power := PowerState.new(1.0)
	t.equal(power.apply_hit(), PowerState.HitResult.FATAL, "hit result")
	t.equal(power.form, PowerState.Form.BROKEN, "form")


func test_coiled_hit_shrinks_and_grants_invulnerability(t: TestKit) -> void:
	var power := PowerState.new(1.0)
	t.is_true(power.apply_pickup(), "pickup changes form")
	t.equal(power.apply_hit(), PowerState.HitResult.SHRUNK, "hit result")
	t.equal(power.form, PowerState.Form.SMALL, "form")
	t.is_true(power.is_invulnerable(), "invulnerable after hit")


func test_invulnerable_hit_is_ignored_until_timer_ends(t: TestKit) -> void:
	var power := PowerState.new(1.0)
	power.apply_pickup()
	power.apply_hit()
	t.equal(power.apply_hit(), PowerState.HitResult.IGNORED, "during invulnerability")
	power.tick(1.1)
	t.equal(power.apply_hit(), PowerState.HitResult.FATAL, "after invulnerability")


func test_second_pickup_changes_nothing(t: TestKit) -> void:
	var power := PowerState.new(1.0)
	power.apply_pickup()
	t.is_true(not power.apply_pickup(), "already coiled")


func test_cogs_score_and_grant_life_at_threshold(t: TestKit) -> void:
	var run := RunState.new(_tuning())
	var per_life := int(_tuning().num("run", "cogs_per_life"))
	var start_lives := run.lives
	for _i in per_life:
		run.add_cog()
	t.equal(run.lives, start_lives + 1, "extra life")
	t.equal(run.score, per_life * int(_tuning().num("run", "score_per_cog")), "score")


func test_lose_life_reports_when_lives_run_out(t: TestKit) -> void:
	var run := RunState.new(_tuning())
	for _i in run.lives - 1:
		t.is_true(run.lose_life(), "lives remain")
	t.is_true(not run.lose_life(), "last life lost")
	t.equal(run.lives, 0, "lives")


func test_timer_reports_expiry_once(t: TestKit) -> void:
	var run := RunState.new(_tuning())
	t.is_true(run.tick(run.time_left + 1.0), "expired")
	t.is_true(not run.tick(1.0), "no second expiry")


func test_stomp_needs_descending_feet_above_margin(t: TestKit) -> void:
	t.is_true(StompRules.is_stomp(0.6, -5.0, 0.0, 0.35), "falling from above")
	t.is_true(not StompRules.is_stomp(0.6, 5.0, 0.0, 0.35), "rising")
	t.is_true(not StompRules.is_stomp(0.1, -5.0, 0.0, 0.35), "feet too low")


func test_coyote_allows_jump_after_leaving_floor_then_expires(t: TestKit) -> void:
	var assist := JumpAssist.new(0.1, 0.1)
	assist.tick(0.016, true)
	assist.tick(0.05, false)
	assist.press()
	t.is_true(assist.consume_jump(), "inside coyote window")
	assist.tick(0.016, true)
	assist.tick(0.2, false)
	assist.press()
	t.is_true(not assist.consume_jump(), "outside coyote window")


func test_buffered_press_fires_on_landing_and_only_once(t: TestKit) -> void:
	var assist := JumpAssist.new(0.1, 0.1)
	assist.tick(0.016, false)
	assist.press()
	t.is_true(not assist.consume_jump(), "still airborne")
	assist.tick(0.05, true)
	t.is_true(assist.consume_jump(), "landed inside buffer")
	t.is_true(not assist.consume_jump(), "consumed")


func test_flow_refuses_invalid_transition(t: TestKit) -> void:
	var flow := GameFlow.new()
	t.is_true(not flow.fire(GameFlow.Trigger.PAUSE), "cannot pause title")
	t.equal(flow.state, GameFlow.State.TITLE, "state unchanged")


func test_flow_full_cycle_reaches_game_over_and_restarts(t: TestKit) -> void:
	var flow := GameFlow.new()
	t.is_true(flow.fire(GameFlow.Trigger.START), "start")
	t.is_true(flow.fire(GameFlow.Trigger.DIE), "die")
	t.is_true(not flow.fire(GameFlow.Trigger.PAUSE), "cannot pause while dying")
	t.is_true(flow.fire(GameFlow.Trigger.OUT_OF_LIVES), "out of lives")
	t.equal(flow.state, GameFlow.State.GAME_OVER, "game over")
	t.is_true(flow.fire(GameFlow.Trigger.START), "restart")


func test_level_data_references_valid_kinds_and_colors(t: TestKit) -> void:
	var data := Tuning.load_json(Level.DEFAULT_PATH)
	t.is_true(not data.is_empty(), "level loaded")
	var palette: Dictionary = data.get("palette", {})
	for platform: Dictionary in data.get("platforms", []):
		t.is_true(palette.has(platform["color"]), "platform color %s" % platform["color"])
	for block: Dictionary in data.get("blocks", []):
		t.is_true(block["kind"] in ["cog", "coil", "life", "crate"], "block kind %s" % block["kind"])
	t.is_true(data.has("goal"), "level has a goal")
