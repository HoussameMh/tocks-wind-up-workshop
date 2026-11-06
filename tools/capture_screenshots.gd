extends SceneTree
## Saves screenshots of key moments to .scratch/shots for visual review.
## Usage: godot --path . --resolution 1280x720 --fixed-fps 60 -s res://tools/capture_screenshots.gd
## Needs a real window: it does not work with --headless.

const OUT_DIR := "res://.scratch/shots"

var _main: Main


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_main = (load(TestKit.MAIN_SCENE) as PackedScene).instantiate()
	_main.films_enabled = false
	root.add_child(_main)
	await _frames(30)
	await _shot("01_title")
	_main.start_game()
	await _frames(20)
	await _shot("02_start")
	await _view_from(Vector3(0.0, 0.2, -9.0), 0.0, 0.2)
	await _shot("03_toy_boxes")
	await _view_from(Vector3(0.0, 0.2, -18.0), 0.0, 0.15)
	await _shot("04_beetle")
	await _view_from(Vector3(0.0, 0.2, -48.0), 0.0, 0.25)
	await _shot("05_moving_platform")
	_main.player.apply_power_up()
	await _view_from(Vector3(0.0, 5.7, -94.0), 0.0, 0.3)
	await _shot("06_coiled_block_steps")
	await _view_from(Vector3(0.0, 0.2, -146.0), 0.0, 0.2)
	await _shot("07_golden_key")
	print("Screenshots saved to %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


func _view_from(at: Vector3, yaw: float, pitch: float) -> void:
	_main.player.global_position = at
	_main.player.velocity = Vector3.ZERO
	_main.camera.yaw = yaw
	_main.camera.pitch = pitch
	_main.camera.snap_to_target()
	await _frames(25)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT_DIR, shot_name])


func _frames(count: int) -> void:
	for _i in count:
		await process_frame
