class_name TestKit
extends RefCounted
## Minimal assertions and scene helpers for tests/run_tests.gd.

const MAIN_SCENE := "res://src/core/main.tscn"

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
