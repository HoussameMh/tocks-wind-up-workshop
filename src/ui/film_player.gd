class_name FilmPlayer
extends CanvasLayer
## Plays a full-screen film over everything, and any button skips it. It owns no game state: the
## caller says what happens next. A film that cannot be loaded just counts as finished, so a
## missing file can never strand the player on a black screen.
##
## Usage:
##   film_player.play("res://assets/video/tocks_workshop_intro.ogv", show_title)

## Above the HUD and every menu.
const LAYER_ABOVE_ALL := 10
const FILM_ASPECT := 16.0 / 9.0
## Presses are ignored this long after a film starts, so a player mashing jump or fire as the last
## level ends does not skip the ending by accident.
const SKIP_GRACE_MSEC := 500
const HINT_SECONDS := 3.0
const HINT_FADE_SECONDS := 0.5
const HINT_MARGIN := 40.0

var _video: VideoStreamPlayer
var _hint: Label
var _hint_tween: Tween
var _on_done := Callable()
var _playing := false
var _skip_allowed_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER_ABOVE_ALL
	var root := Control.new()
	root.theme = UiTheme.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	var frame := AspectRatioContainer.new()
	frame.ratio = FILM_ASPECT
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(frame)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.finished.connect(_finish)
	frame.add_child(_video)
	_hint = Label.new()
	_hint.theme_type_variation = UiTheme.LABEL_HINT_TEXT
	_hint.text = tr("Press any button to skip")
	root.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_left = -HINT_MARGIN
	_hint.offset_right = -HINT_MARGIN
	_hint.offset_top = -HINT_MARGIN
	_hint.offset_bottom = -HINT_MARGIN
	visible = false


## Starts a film, and calls on_done once when it ends or is skipped.
func play(path: String, on_done: Callable) -> void:
	_on_done = on_done
	var stream: VideoStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null:
		push_error("Film not found: %s" % path)
		_end()
		return
	_video.stream = stream
	_video.play()
	_playing = true
	_skip_allowed_msec = Time.get_ticks_msec() + SKIP_GRACE_MSEC
	visible = true
	_show_hint()


## True from the start of a film until it ends or is skipped.
func is_playing() -> bool:
	return _playing


## Ends the film now, as a press of any button does once the grace is over.
func skip() -> void:
	_finish()


func _input(event: InputEvent) -> void:
	if not _playing:
		return
	# Nothing behind a film reacts to input: not the pause key, and not the menu that comes after.
	get_viewport().set_input_as_handled()
	if _is_press(event) and Time.get_ticks_msec() >= _skip_allowed_msec:
		skip()


func _process(_delta: float) -> void:
	# A film that fails while decoding stops without saying so.
	if _playing and not _video.is_playing():
		_finish()


func _finish() -> void:
	if not _playing:
		return
	_playing = false
	_video.stop()
	_video.stream = null
	visible = false
	if _hint_tween != null:
		_hint_tween.kill()
	_end()


func _end() -> void:
	var done := _on_done
	_on_done = Callable()
	if done.is_valid():
		done.call()


func _show_hint() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
	_hint.modulate.a = 1.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(HINT_SECONDS)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, HINT_FADE_SECONDS)


func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		return event.is_pressed() and not event.is_echo()
	return false
