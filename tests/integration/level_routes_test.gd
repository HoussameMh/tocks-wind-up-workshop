extends RefCounted
## Levels 2 to 4 can be finished, and their data keeps to design/expansion-spec.md sections 1 and 8.
## Bots use small-form numbers with no Coil, walking everywhere but the marked run jumps.

const COGS: Array[int] = [54, 50, 45, 40, 12]
const GEAR: Array[int] = [9, 5, 4, 4, 0]
const ARMORED: Array[int] = [0, 2, 2, 3, 0]
const PLANES: Array[int] = [0, 3, 2, 2, 0]
const DUCKS: Array[int] = [0, 0, 4, 2, 0]
const TEETH: Array[int] = [0, 0, 0, 5, 0]
const WINDOW_ENEMIES := 5
const WINDOW_LENGTH := 40.0
const WINDOW_COGS := 20
const COG_WINDOW_LENGTH := 50.0
const NO_AMBUSH_RADIUS := 16.0
const BOX_COUNTS: Array = [["coil", 2, 0], ["coil", 2, 2], ["coil", 2, 1], ["coil", 1, 1], ["coil", 1, 1]]


func _levels() -> Array:
	return Tuning.load_json(Main.CAMPAIGN_PATH)["levels"]


func _vec(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])


## Every enemy's z: plane rails count at their midpoint.
func _enemy_points(data: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for entry: Dictionary in data["beetles"]:
		points.append(_vec(entry["a"]).lerp(_vec(entry["b"]), 0.5))
	for entry: Dictionary in data.get("planes", []):
		points.append(_vec(entry["a"]).lerp(_vec(entry["b"]), 0.5))
	for entry: Dictionary in data.get("ducks", []):
		points.append(_vec(entry["pos"]))
	for entry: Dictionary in data.get("teeth", []):
		points.append(_vec(entry["pos"]))
	return points


func _cog_points(data: Dictionary) -> Array[float]:
	var zs: Array[float] = []
	for entry: Dictionary in data["cog_lines"]:
		var count := int(entry["count"])
		for i in count:
			var ratio := float(i) / float(maxi(count - 1, 1))
			zs.append(_vec(entry["from"]).lerp(_vec(entry["to"]), ratio).z)
	for entry: Array in data["cogs"]:
		zs.append(float(entry[2]))
	for entry: Dictionary in data["blocks"]:
		if entry["kind"] == "cog":
			zs.append(float(entry["pos"][2]))
	return zs


func _max_in_window(zs: Array[float], length: float) -> int:
	var worst := 0
	for start in zs:
		var count := 0
		for z in zs:
			if z <= start and z > start - length:
				count += 1
		worst = maxi(worst, count)
	return worst


func test_every_level_has_the_spec_counts_and_keeps_the_limits(t: TestKit) -> void:
	var levels := _levels()
	for index in levels.size():
		var data := Tuning.load_json(levels[index])
		var label := "level %d" % (index + 1)
		var gear := 0
		var armored := 0
		for entry: Dictionary in data["beetles"]:
			if entry.get("armored", false):
				armored += 1
			else:
				gear += 1
		t.equal(gear, GEAR[index], "%s gear beetles" % label)
		t.equal(armored, ARMORED[index], "%s armored beetles" % label)
		t.equal(data.get("planes", []).size(), PLANES[index], "%s planes" % label)
		t.equal(data.get("ducks", []).size(), DUCKS[index], "%s ducks" % label)
		t.equal(data.get("teeth", []).size(), TEETH[index], "%s teeth" % label)
		var cog_zs := _cog_points(data)
		t.equal(cog_zs.size(), COGS[index], "%s cogs" % label)
		# The limit is for new levels; level one's layout is kept exactly as it shipped.
		if index > 0:
			t.is_true(_max_in_window(cog_zs, COG_WINDOW_LENGTH) <= WINDOW_COGS, "%s cogs per 50 m" % label)
		var enemy_zs: Array[float] = []
		for point in _enemy_points(data):
			enemy_zs.append(point.z)
		t.is_true(
			_max_in_window(enemy_zs, WINDOW_LENGTH) <= WINDOW_ENEMIES,
			"%s enemies per 40 m: %d" % [label, _max_in_window(enemy_zs, WINDOW_LENGTH)]
		)
		var coils := 0
		var bolts := 0
		for entry: Dictionary in data["blocks"]:
			coils += 1 if entry["kind"] == "coil" else 0
			bolts += 1 if entry["kind"] == "bolt" else 0
		t.equal(coils, BOX_COUNTS[index][1], "%s coil boxes" % label)
		t.equal(bolts, BOX_COUNTS[index][2], "%s bolt boxes" % label)


func test_no_duck_or_teeth_can_ambush_a_spawn_or_respawn(t: TestKit) -> void:
	for path: String in _levels():
		var data := Tuning.load_json(path)
		var safe: Array[Vector3] = [_vec(data["spawn"])]
		for entry: Dictionary in data["checkpoints"]:
			safe.append(_vec(entry["respawn"]))
		var ambushers: Array = data.get("ducks", []) + data.get("teeth", [])
		for entry: Dictionary in ambushers:
			for point in safe:
				var distance := Vector2(point.x, point.z).distance_to(Vector2(entry["pos"][0], entry["pos"][2]))
				t.is_true(distance >= NO_AMBUSH_RADIUS, "%s: %s is %.1f m from %s" % [path, entry["pos"], distance, point])


func _finish(t: TestKit, main: Main, steps: Array[Dictionary], max_ticks: int, label: String) -> void:
	main.level.remove_enemies()
	await t.wait_ticks(2)
	var lives := main.run_state.lives
	var reached := await t.walk_route(main, steps, max_ticks)
	t.equal(
		main.flow.state,
		GameFlow.State.LEVEL_CLEAR,
		"%s cleared; step %d of %d at %s" % [label, reached, steps.size(), main.player.global_position]
	)
	t.equal(main.run_state.lives, lives, "%s no lives lost" % label)


func test_level_two_can_be_finished_walking(t: TestKit) -> void:
	var main: Main = await t.start_level(1)
	var steps: Array[Dictionary] = [
		{ "to": Vector3(0, 0, -29.2), "jump": true },
		{ "to": Vector3(0, 0, -36.0) },
		{ "to": Vector3(0, 0, -47.0), "jump": true },
		{ "to": Vector3(-1.5, 0, -52.5), "jump": true },
		{ "to": Vector3(1.5, 0, -58.5), "jump": true },
		{ "to": Vector3(-1.5, 0, -64.5), "jump": true },
		{ "to": Vector3(0, 0, -72.0) },
		{ "to": Vector3(0, 0, -99.2), "jump": true },
		{ "to": Vector3(0, 0, -105.0) },
		{ "to": Vector3(0, 0, -108.0), "radius": 0.8, "no_floor": true },
		{ "to": Vector3(0, 0, -114.0), "radius": 1.5 },
		{ "to": Vector3(1.5, 0, -127.2), "jump": true },
		{ "to": Vector3(1.5, 0, -133.25) },
		{ "to": Vector3(1.08, 0, -134.16), "jump": true, "radius": 0.4 },
		{ "to": Vector3(-1.5, 0, -139.75) },
		{ "to": Vector3(-1.11, 0, -140.67), "jump": true, "radius": 0.4 },
		{ "to": Vector3(1.5, 0, -146.75) },
		{ "to": Vector3(1.3, 0, -147.73), "jump": true, "radius": 0.4 },
		{ "to": Vector3(0, 0, -154.25) },
		{ "to": Vector3(0, 0, -155.2), "jump": true, "radius": 0.4 },
		{ "to": Vector3(0, 0, -162.0) },
		{ "to": Vector3(0, 0, -192.0), "radius": 0.5 },
	]
	await _finish(t, main, steps, 3600, "level 2")
	await t.stop_game(main)


func test_level_three_can_be_finished_walking_but_for_its_run_jump(t: TestKit) -> void:
	var main: Main = await t.start_level(2)
	var steps: Array[Dictionary] = [
		{ "to": Vector3(0, 0, -23.2), "jump": true },
		{ "to": Vector3(3.5, 0, -30.0) },
		{ "to": Vector3(3.5, 0, -46.0) },
		{ "to": Vector3(0, 0, -63.2), "jump": true },
		{ "to": Vector3(0, 0, -72.0) },
		{ "to": Vector3(0, 0, -95.2), "jump": true },
		{ "to": Vector3(0, 0, -106.5), "jump": true },
		{ "to": Vector3(0, 0, -118.0), "jump": true },
		{ "to": Vector3(0, 0, -129.5), "jump": true },
		{ "to": Vector3(0, 0, -137.0) },
		{ "to": Vector3(0, 0, -159.2), "jump": true, "run": true },
		{ "to": Vector3(0, 0, -170.0), "run": true },
		{ "to": Vector3(0, 0, -191.2), "jump": true },
		{ "to": Vector3(0, 0, -198.0) },
		{ "to": Vector3(3.5, 0, -206.0) },
		{ "to": Vector3(3.5, 0, -214.0) },
		{ "to": Vector3(0, 0, -224.0), "radius": 0.5 },
	]
	await _finish(t, main, steps, 3600, "level 3")
	await t.stop_game(main)


func test_level_four_can_be_finished_on_the_wrenches(t: TestKit) -> void:
	var main: Main = await t.start_level(3)
	var plates: Array = main.level.moving_platforms
	var shuttle: Node3D = plates[0]
	var lift: Node3D = plates[1]
	var sweep: Node3D = plates[2]
	var first: Node3D = plates[3]
	var second: Node3D = plates[4]
	var drop: Node3D = plates[5]
	# The front of a plate: where a player stands to jump to whatever comes next.
	var front := func(node: Node3D, reach: float) -> Vector3: return node.global_position + Vector3.FORWARD * reach
	var steps: Array[Dictionary] = [
		{ "to": Vector3(0, 0, -25.2), "jump": true, "wait": func() -> bool: return shuttle.global_position.z > -30.0 },
		{ "to": shuttle.get_global_position, "radius": 1.2 },
		{ "to": front.bind(shuttle, 2.4), "radius": 0.8, "jump": true, "wait": func() -> bool: return shuttle.global_position.z < -32.0 },
		{ "to": Vector3(0, 0, -39.0) },
		{ "to": Vector3(0, 0, -59.2), "jump": true, "wait": func() -> bool: return lift.global_position.y < 0.0 },
		{ "to": lift.get_global_position, "radius": 1.0 },
		{ "to": front.bind(lift, 1.4), "radius": 0.8, "jump": true, "wait": func() -> bool: return lift.global_position.y > 5.5 },
		{ "to": Vector3(0, 0, -73.0), "radius": 1.5 },
		{ "to": Vector3(0, 0, -83.5), "wait": func() -> bool: return absf(sweep.global_position.x) > 6.0 },
		{ "to": Vector3(0, 0, -93.0), "run": true },
		{ "to": Vector3(0, 0, -95.4), "jump": true, "wait": func() -> bool: return absf(first.global_position.x) < 1.5 },
		{ "to": first.get_global_position, "radius": 1.2 },
		{ "to": front.bind(first, 2.4), "radius": 0.8, "jump": true, "wait": func() -> bool: return absf(first.global_position.x - second.global_position.x) < 3.0 },
		{ "to": second.get_global_position, "radius": 1.2 },
		{ "to": front.bind(second, 2.4), "radius": 0.8, "jump": true, "wait": func() -> bool: return absf(second.global_position.x) < 1.0 },
		{ "to": Vector3(0, 0, -119.5), "radius": 0.6, "jump": true },
		{ "to": Vector3(0, 0, -126.0) },
		{ "to": Vector3(0, 0, -149.3), "jump": true, "run": true },
		{ "to": Vector3(0, 0, -161.0), "run": true },
		{ "to": Vector3(0, 0, -185.3), "jump": true, "wait": func() -> bool: return drop.global_position.y > 5.5 },
		{ "to": drop.get_global_position, "radius": 1.0 },
		{ "to": front.bind(drop, 1.4), "radius": 0.8, "jump": true, "wait": func() -> bool: return drop.global_position.y < 1.0 },
		{ "to": Vector3(0, 0, -198.0), "radius": 1.5 },
		{ "to": Vector3(0, 0, -230.0), "radius": 0.5 },
	]
	await _finish(t, main, steps, 5400, "level 4")
	await t.stop_game(main)


func test_level_four_sweep_shoves_tock_without_hurting_or_trapping_him(t: TestKit) -> void:
	var main: Main = await t.start_level(3)
	main.level.remove_enemies()
	await t.wait_ticks(1)
	var sweep: Node3D = main.level.moving_platforms[2]
	main.player.global_position = Vector3(0.0, 6.2, -88.0)
	main.player.velocity = Vector3.ZERO
	t.drive(main)
	var start_x := main.player.global_position.x
	var moved := await t.wait_until(func() -> bool: return absf(main.player.global_position.x - start_x) > 0.5, 300)
	t.is_true(moved, "the bar moves Tock")
	t.equal(main.player.form(), PowerState.Form.SMALL, "unhurt, since a small Tock would be dead")
	t.is_true(main.player.alive or main.player.global_position.y < 5.0, "alive unless shoved off the side")
	t.is_true(absf(sweep.global_position.x) <= 7.01, "the bar stays on its rail")
	await t.stop_game(main)
