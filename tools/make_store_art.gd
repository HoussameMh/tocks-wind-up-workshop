extends SceneTree
## Makes the itch.io cover (630 by 500) from a still recorded with tools/record_film.gd, with the
## game's brass logo drawn over it as on the title screen.
## Usage: godot --path . -s res://tools/make_store_art.gd -- <cover still .jpg> <output .png>
## Needs a real window: it does not work with --headless.

const SIZE := Vector2i(1260, 1000)
const OUT_SIZE := Vector2i(630, 500)
const LOGO_SIZES: Array[int] = [64, 88, 88]
const MARGIN := Vector2(56.0, 44.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var still := Image.load_from_file(args[0])
	# Keep the still's full height and crop its width to the cover's shape, leaning left to keep Tock.
	var crop_width := int(still.get_height() * float(SIZE.x) / SIZE.y)
	var crop_left := clampi(int(still.get_width() * 0.16), 0, still.get_width() - crop_width)
	var cropped := still.get_region(Rect2i(crop_left, 0, crop_width, still.get_height()))
	cropped.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)

	var view := SubViewport.new()
	view.size = SIZE
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var back := TextureRect.new()
	back.texture = ImageTexture.create_from_image(cropped)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.add_child(back)
	var scrim := TextureRect.new()
	scrim.texture = UiTheme.left_scrim()
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.add_child(scrim)
	var logo := VBoxContainer.new()
	logo.theme = UiTheme.theme()
	logo.position = MARGIN
	logo.add_theme_constant_override(&"separation", 0)
	view.add_child(logo)
	var words: Array[String] = ["TOCK'S", "WIND-UP", "WORKSHOP"]
	for i in words.size():
		var line := BrassLine.new()
		line.max_width = SIZE.x * 0.6
		logo.add_child(line)
		line.configure(words[i], LOGO_SIZES[i], i == 0)

	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	image.resize(OUT_SIZE.x, OUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(args[1])
	print("saved ", args[1])
	quit(0)
