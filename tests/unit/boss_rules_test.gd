extends RefCounted
## The Baron's health arithmetic, design/expansion-spec.md section 6.

const HP := 18
const CAP := 3


func test_a_stomp_and_three_bolts_cost_the_same_and_six_windows_win(t: TestKit) -> void:
	var stomps := BossRules.new(HP, CAP)
	var bolts := BossRules.new(HP, CAP)
	for window in 6:
		stomps.open_window()
		t.equal(stomps.hit(3), 3, "stomp %d deals 3" % window)
		bolts.open_window()
		for bolt in 3:
			t.equal(bolts.hit(1), 1, "window %d bolt %d deals 1" % [window, bolt])
		t.equal(stomps.hp, bolts.hp, "same health after window %d" % window)
	t.is_true(stomps.is_defeated(), "six stomps win")
	t.is_true(bolts.is_defeated(), "eighteen bolts win")


func test_one_window_never_takes_more_than_the_cap(t: TestKit) -> void:
	var rules := BossRules.new(HP, CAP)
	rules.open_window()
	t.equal(rules.hit(1), 1, "first bolt")
	t.equal(rules.hit(3), 2, "a stomp is cut to what the window has left")
	t.is_true(rules.window_spent(), "window spent")
	t.equal(rules.hit(1), 0, "nothing more")
	t.equal(rules.hp, HP - CAP, "three in all")


func test_damage_stops_at_each_phase_boundary(t: TestKit) -> void:
	var rules := BossRules.new(HP, CAP)
	rules.hp = 13
	rules.open_window()
	t.equal(rules.hit(3), 1, "a stomp at 13 is cut to the boundary")
	t.equal(rules.hp, 12, "stops at 12, not 10")
	t.is_true(rules.at_phase_boundary(), "phase is over")
	t.equal(rules.phase(), 1, "second phase next")


func test_there_are_exactly_three_phases_with_the_spec_ranges(t: TestKit) -> void:
	var rules := BossRules.new(HP, CAP)
	for hp: int in [18, 13]:
		rules.hp = hp
		t.equal(rules.phase(), 0, "phase 1 at %d" % hp)
	for hp: int in [12, 7]:
		rules.hp = hp
		t.equal(rules.phase(), 1, "phase 2 at %d" % hp)
	for hp: int in [6, 1, 0]:
		rules.hp = hp
		t.equal(rules.phase(), 2, "phase 3 at %d" % hp)


func test_restarting_a_phase_returns_to_its_starting_health(t: TestKit) -> void:
	var rules := BossRules.new(HP, CAP)
	rules.hp = 8
	rules.restart_phase(rules.phase())
	t.equal(rules.hp, 12, "phase 2 starts at 12")
	rules.hp = 2
	rules.restart_phase(rules.phase())
	t.equal(rules.hp, 6, "phase 3 starts at 6")
	rules.hp = 15
	rules.restart_phase(rules.phase())
	t.equal(rules.hp, 18, "phase 1 starts at 18")
