extends SceneTree
## Compares frame rate across graphics settings along the course, with vsync off.
## Usage: godot --path . --resolution 1280x720 -s res://tools/measure_fps.gd
## Needs a real window: it does not work with --headless.

const SPOTS: Array[Vector3] = [
	Vector3(0.0, 0.2, 2.0),
	Vector3(0.0, 0.2, -40.0),
	Vector3(0.0, 5.7, -90.0),
	Vector3(0.0, 0.2, -140.0),
]
const SAMPLE_MSEC := 2500
const SETTLE_FRAMES := 20

var _main: Main


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("screen %d of %d, refresh %.1f Hz, size %s" % [
		DisplayServer.window_get_current_screen(),
		DisplayServer.get_screen_count(),
		DisplayServer.screen_get_refresh_rate(),
		DisplayServer.screen_get_size(),
	])
	Engine.max_fps = 0
	_main = (load(TestKit.MAIN_SCENE) as PackedScene).instantiate()
	_main.films_enabled = false
	root.add_child(_main)
	await _frames(30)
	print("title, vsync on                   %5.1f fps" % await _count_fps())
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _frames(30)
	print("title, vsync off                   %5.1f fps" % await _count_fps())
	_main.start_game()
	await _frames(30)
	_main.player.controls_enabled = false
	await _measure("gameplay, vsync off", Viewport.MSAA_DISABLED, true, 1.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	await _frames(30)
	await _measure("gameplay, vsync on", Viewport.MSAA_DISABLED, true, 1.0)
	print("draw calls: %d, objects: %d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
	])
	quit(0)


func _measure(label: String, msaa: Viewport.MSAA, shadows: bool, render_scale: float) -> void:
	root.msaa_3d = msaa
	root.scaling_3d_scale = render_scale
	for sun: Node in _main.level.find_children("*", "DirectionalLight3D", true, false):
		(sun as DirectionalLight3D).shadow_enabled = shadows
	var results: Array[String] = []
	var total := 0.0
	for spot in SPOTS:
		_main.player.global_position = spot
		_main.player.velocity = Vector3.ZERO
		_main.camera.snap_to_target()
		await _frames(SETTLE_FRAMES)
		var frames := 0
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < SAMPLE_MSEC:
			await process_frame
			frames += 1
		var fps := frames * 1000.0 / float(Time.get_ticks_msec() - start)
		total += fps
		results.append("%.0f" % fps)
	print("%-34s avg %5.1f fps  spots %s" % [label, total / SPOTS.size(), ", ".join(results)])


func _count_fps() -> float:
	var frames := 0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < SAMPLE_MSEC:
		await process_frame
		frames += 1
	return frames * 1000.0 / float(Time.get_ticks_msec() - start)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame
