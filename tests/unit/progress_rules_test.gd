extends RefCounted
## Saved progress, best times and quality defaults, in memory only. design/release-spec.md
## sections 3 and 4.

const CAMPAIGN_SIZE := 5
const FIRST_TIME := 90.0
const FASTER_TIME := 75.5
const SLOWER_TIME := 120.0


func _fresh() -> Progress:
	return Progress.load_from("", CAMPAIGN_SIZE)


func test_new_player_has_only_level_one_open(t: TestKit) -> void:
	var progress := _fresh()
	t.equal(progress.unlocked_count(), 1, "one level open")
	t.is_true(progress.is_unlocked(0), "level one open")
	t.is_true(not progress.is_unlocked(1), "level two locked")
	t.equal(progress.best_time(0), Progress.NO_TIME, "no best time")
	t.equal(progress.gears_found(0).size(), 0, "no gears")
	t.equal(progress.best_run_score, 0, "no best run")


func test_clearing_a_level_opens_the_next_and_never_closes_one(t: TestKit) -> void:
	var progress := _fresh()
	progress.record_clear(2, FIRST_TIME, [])
	t.equal(progress.unlocked_count(), 4, "clearing level three opens level four")
	progress.record_clear(0, FIRST_TIME, [])
	t.equal(progress.unlocked_count(), 4, "clearing an earlier level does not close any")
	progress.record_clear(CAMPAIGN_SIZE - 1, FIRST_TIME, [])
	t.equal(progress.unlocked_count(), CAMPAIGN_SIZE, "the last clear stays within the campaign")


func test_best_time_keeps_the_lower_time(t: TestKit) -> void:
	var progress := _fresh()
	var first := progress.record_clear(1, FIRST_TIME, [])
	t.is_true(first.new_best_time, "the first clear is a best")
	var slower := progress.record_clear(1, SLOWER_TIME, [])
	t.is_true(not slower.new_best_time, "a slower clear is not a best")
	t.equal(progress.best_time(1), FIRST_TIME, "slower time ignored")
	var faster := progress.record_clear(1, FASTER_TIME, [])
	t.is_true(faster.new_best_time, "a faster clear is a best")
	t.equal(faster.best_time, FASTER_TIME, "result reports the new best")
	t.equal(progress.best_time(1), FASTER_TIME, "faster time kept")


func test_gears_add_up_across_clears_without_duplicates(t: TestKit) -> void:
	var progress := _fresh()
	var first := progress.record_clear(0, FIRST_TIME, [2])
	t.equal(first.gears_found, 1, "one gear after the first clear")
	var second := progress.record_clear(0, FIRST_TIME, [0, 2])
	t.equal(second.gears_found, 2, "the repeat gear is not counted twice")
	t.equal(progress.gears_found(0), [0, 2] as Array[int], "gears listed in order")
	t.equal(progress.total_gears_found(), 2, "campaign total")


func test_out_of_range_level_changes_nothing(t: TestKit) -> void:
	var progress := _fresh()
	progress.record_clear(CAMPAIGN_SIZE, FIRST_TIME, [0])
	progress.record_clear(-1, FIRST_TIME, [0])
	t.equal(progress.unlocked_count(), 1, "still one level open")
	t.equal(progress.total_gears_found(), 0, "no gears banked")


func test_best_run_counts_only_runs_from_level_one(t: TestKit) -> void:
	var progress := _fresh()
	t.is_true(not progress.record_victory(50000, false), "a level select run is not a best run")
	t.equal(progress.best_run_score, 0, "score not kept")
	t.is_true(progress.campaign_won, "but the campaign counts as won")
	t.is_true(progress.record_victory(30000, true), "a full run is a best")
	t.is_true(not progress.record_victory(20000, true), "a lower full run is not")
	t.equal(progress.best_run_score, 30000, "best kept")


func test_time_formats_as_minutes_seconds_and_tenths(t: TestKit) -> void:
	t.equal(Screens.format_time(0.0), "0:00.0", "zero")
	t.equal(Screens.format_time(83.44), "1:23.4", "rounds to tenths")
	t.equal(Screens.format_time(59.96), "1:00.0", "rounds up into the next minute")
	t.equal(Screens.format_time(-3.0), "0:00.0", "never negative")


func test_default_quality_is_low_for_intel_browser_and_software(t: TestKit) -> void:
	t.equal(GraphicsQuality.default_for("Intel(R) HD Graphics 520", false), UiSettings.QUALITY_LOW, "Intel")
	t.equal(GraphicsQuality.default_for("llvmpipe (LLVM 15.0.7, 256 bits)", false), UiSettings.QUALITY_LOW, "software")
	t.equal(GraphicsQuality.default_for("NVIDIA GeForce RTX 3060", true), UiSettings.QUALITY_LOW, "browser")
	t.equal(GraphicsQuality.default_for("", false), UiSettings.QUALITY_LOW, "unknown")
	t.equal(GraphicsQuality.default_for("NVIDIA GeForce RTX 3060", false), UiSettings.QUALITY_HIGH, "NVIDIA")
	t.equal(GraphicsQuality.default_for("AMD Radeon RX 6600", false), UiSettings.QUALITY_HIGH, "AMD")
