class_name TestKit
extends RefCounted
## Minimal assertions and scene helpers for tests/run_tests.gd.

const MAIN_SCENE := "res://src/core/main.tscn"
const ARENA_Y := 60.0
const ARENA_SIZE := 200.0

var tree: SceneTree
var checks := 0
var failures: Array[String] = []
var current_test := ""


func _init(scene_tree: SceneTree) -> void:
	tree = scene_tree


func is_true(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append("%s: expected true: %s" % [current_test, label])


func equal(actual: Variant, expected: Variant, label: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s: %s: expected %s, got %s" % [current_test, label, expected, actual])


func near(actual: float, expected: float, tolerance: float, label: String) -> void:
	checks += 1
	if absf(actual - expected) > tolerance:
		failures.append(
			"%s: %s: expected %s +/- %s, got %s" % [current_test, label, expected, tolerance, actual]
		)


## Creates the real game scene and starts a run.
func start_game() -> Main:
	var main: Main = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	await wait_ticks(2)
	main.start_game()
	await wait_ticks(3)
	return main


## Starts a run on a given campaign level, from 0, with that level's clock.
func start_level(index: int) -> Main:
	var main: Main = await start_game()
	main.load_level(index)
	main.run_state.enter_level(main.level.time_seconds)
	await wait_ticks(3)
	return main


## Walks a bot along a route of steps. Each step is a Dictionary:
##   to: a Vector3 (y ignored) or a Callable returning one
##   radius: how close counts as arrived (default 1.0)
##   jump: jump at the moment of arrival
##   run: hold run on the way there
##   wait: a Callable that must return true before arrival counts
##   no_floor: arrival counts in the air too
## Ends when the level is cleared or max_ticks pass. Returns the last step reached.
func walk_route(main: Main, steps: Array[Dictionary], max_ticks: int) -> int:
	var command := drive(main)
	var index := 0
	for _tick in max_ticks:
		if main.flow.state != GameFlow.State.PLAYING:
			break
		command.jump_pressed = false
		command.jump_held = true
		var step: Dictionary = steps[mini(index, steps.size() - 1)]
		var target: Vector3 = step["to"].call() if step["to"] is Callable else step["to"]
		var to_target := target - main.player.global_position
		to_target.y = 0.0
		var distance := to_target.length()
		var waiting: bool = step.has("wait") and not step["wait"].call()
		var radius: float = step.get("radius", 1.0)
		command.run = step.get("run", false)
		# Holds station at a waypoint rather than wandering off an edge while it waits.
		if waiting and distance < radius * 0.5:
			command.move = Vector3.ZERO
		elif distance > 0.05:
			command.move = to_target.normalized()
		else:
			command.move = Vector3.ZERO
		var grounded: bool = main.player.is_on_floor() or step.get("no_floor", false)
		if distance < radius and grounded and not waiting:
			command.jump_pressed = step.get("jump", false)
			index += 1
		await wait_ticks(1)
	return index


## Starts a run with level 1's enemies gone and Tock on a large clear slab above the course.
## Nothing on the slab but what a test adds, so a test can place enemies freely.
func start_arena() -> Main:
	var main: Main = await start_game()
	main.level.remove_enemies()
	await tree.process_frame
	add_slab(main, Vector3(0.0, ARENA_Y - 1.0, 0.0), Vector3(ARENA_SIZE, 2.0, ARENA_SIZE))
	main.player.global_position = Vector3(0.0, ARENA_Y + 0.2, 0.0)
	main.player.velocity = Vector3.ZERO
	main.camera.snap_to_target()
	await wait_until(func() -> bool: return main.player.is_on_floor(), 60)
	return main


## Adds a solid box to the level.
func add_slab(main: Main, center: Vector3, size: Vector3) -> StaticBody3D:
	var slab := StaticBody3D.new()
	slab.collision_layer = Player.LAYER_WORLD
	slab.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	slab.add_child(collider)
	main.level.add_child(slab)
	return slab


func stop_game(main: Main) -> void:
	tree.paused = false
	main.queue_free()
	await tree.process_frame
	await tree.process_frame


func wait_ticks(count: int) -> void:
	for _i in count:
		await tree.physics_frame


## Keeps a bot command active. Returns the Command so a test can change it later.
func drive(main: Main, move: Vector3 = Vector3.ZERO, jump := false) -> Player.Command:
	var command := Player.Command.new()
	command.move = move
	command.jump_pressed = jump
	command.jump_held = jump
	main.player.bot_control = func() -> Player.Command: return command
	return command


## Waits until a condition is true, up to max_ticks. Returns whether it became true.
func wait_until(condition: Callable, max_ticks: int) -> bool:
	for _i in max_ticks:
		if condition.call():
			return true
		await tree.physics_frame
	return bool(condition.call())
