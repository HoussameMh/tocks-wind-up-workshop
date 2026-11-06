extends RefCounted
## Rules behind the five-level campaign, design/expansion-spec.md section 2.


func _tuning() -> Tuning:
	return Tuning.load_from(Tuning.DEFAULT_PATH)


func test_flow_allows_listed_campaign_moves_only(t: TestKit) -> void:
	var flow := GameFlow.new()
	t.is_true(flow.fire(GameFlow.Trigger.START), "start")
	t.is_true(not flow.fire(GameFlow.Trigger.NEXT), "no next level while playing")
	t.is_true(not flow.fire(GameFlow.Trigger.RETRY), "no retry while playing")
	t.is_true(flow.fire(GameFlow.Trigger.CLEAR), "clear")
	t.is_true(not flow.fire(GameFlow.Trigger.RETRY), "no retry from a cleared level")
	t.is_true(not flow.fire(GameFlow.Trigger.WIN), "no win from a cleared level")
	t.is_true(flow.fire(GameFlow.Trigger.NEXT), "next level")
	t.equal(flow.state, GameFlow.State.PLAYING, "next level is played")
	t.is_true(flow.fire(GameFlow.Trigger.DIE), "die")
	t.is_true(flow.fire(GameFlow.Trigger.OUT_OF_LIVES), "out of lives")
	t.is_true(not flow.fire(GameFlow.Trigger.NEXT), "no next level from game over")
	t.is_true(flow.fire(GameFlow.Trigger.RETRY), "retry level")
	t.equal(flow.state, GameFlow.State.PLAYING, "retry is played")
	t.is_true(flow.fire(GameFlow.Trigger.WIN), "win")
	t.equal(flow.state, GameFlow.State.VICTORY, "victory screen")
	t.is_true(not flow.fire(GameFlow.Trigger.RESUME), "cannot resume from victory")
	t.is_true(flow.fire(GameFlow.Trigger.START), "new run from victory")
	t.is_true(flow.fire(GameFlow.Trigger.WIN), "win again")
	t.is_true(flow.fire(GameFlow.Trigger.QUIT), "title from victory")
	t.equal(flow.state, GameFlow.State.TITLE, "back at title")


func test_entering_a_level_keeps_totals_and_resets_level_counters(t: TestKit) -> void:
	var run := RunState.new(_tuning())
	run.add_cog()
	run.add_cog()
	t.equal(run.level_cogs, 2, "level cogs counted")
	run.enter_level(250.0)
	t.equal(run.cogs, 2, "run cogs carry over")
	t.equal(run.level_cogs, 0, "level cogs start again")
	t.near(run.time_left, 250.0, 0.001, "level's own time")
	run.tick(10.0)
	run.restart_timer()
	t.near(run.time_left, 250.0, 0.001, "a new life gets this level's full time")


func test_rewinding_restores_the_level_entry_and_counts(t: TestKit) -> void:
	var tuning := _tuning()
	var run := RunState.new(tuning)
	run.add_cog()
	run.add_stomp()
	run.enter_level(280.0)
	var entry_score := run.score
	run.add_cog()
	run.add_stomp()
	run.lose_life()
	run.lose_life()
	run.lose_life()
	run.rewind_to_level_entry()
	t.equal(run.cogs, 1, "cogs back to entry")
	t.equal(run.level_cogs, 0, "level cogs cleared")
	t.equal(run.score, entry_score, "score back to entry")
	t.equal(run.lives, int(tuning.num("run", "starting_lives")), "lives refilled")
	t.equal(run.rewinds, 1, "rewind counted")
	t.near(run.time_left, 280.0, 0.001, "full time")
	run.reset()
	t.equal(run.rewinds, 0, "a new run clears rewinds")


func test_time_bonus_banks_once_and_stops_the_clock(t: TestKit) -> void:
	var tuning := _tuning()
	var run := RunState.new(tuning)
	run.enter_level(10.0)
	run.bank_time_bonus()
	var after_bank := run.score
	t.equal(after_bank, 10 * int(tuning.num("run", "score_per_second_left")), "bonus for ten seconds")
	run.bank_time_bonus()
	t.equal(run.score, after_bank, "second bank adds nothing")
	t.is_true(not run.tick(100.0), "stopped clock never runs out")
	run.enter_level(10.0)
	run.bank_time_bonus()
	t.is_true(run.score > after_bank, "next level banks again")


func test_victory_bonus_pays_for_lives_and_a_clean_run(t: TestKit) -> void:
	var tuning := _tuning()
	var run := RunState.new(tuning)
	run.bank_victory_bonus()
	var clean := int(tuning.num("run", "starting_lives")) * int(tuning.num("score", "per_life_at_win"))
	clean += int(tuning.num("score", "no_rewind"))
	t.equal(run.score, clean, "lives and clean run")
	var rewound := RunState.new(tuning)
	rewound.rewind_to_level_entry()
	rewound.bank_victory_bonus()
	t.equal(
		rewound.score,
		int(tuning.num("run", "starting_lives")) * int(tuning.num("score", "per_life_at_win")),
		"no clean-run bonus after a rewind"
	)


func test_restored_form_grants_no_invulnerability_and_never_broken(t: TestKit) -> void:
	var power := PowerState.new(1.5)
	power.restore(PowerState.Form.BLASTER)
	t.equal(power.form, PowerState.Form.BLASTER, "blaster carried")
	t.is_true(not power.is_invulnerable(), "no free invulnerability")
	power.restore(PowerState.Form.BROKEN)
	t.equal(power.form, PowerState.Form.SMALL, "a broken Tock enters as small")


func test_campaign_lists_five_existing_levels_starting_with_workbench(t: TestKit) -> void:
	var levels: Array = Tuning.load_json(Main.CAMPAIGN_PATH)["levels"]
	t.equal(levels.size(), 5, "five levels")
	t.equal(levels[0], Level.DEFAULT_PATH, "level one first")
	for path: String in levels:
		t.is_true(FileAccess.file_exists(path), "%s exists" % path)
