class_name Screens
extends CanvasLayer
## Title, pause, game over and level-clear menus. Works with mouse, keyboard and gamepad.
## Button presses are only reported through signals; this layer owns no game state.
## Implements the menu parts of design/art/art-bible.md section 6.

signal start_requested
signal resume_requested
signal title_requested
signal quit_requested
signal reduced_motion_toggle_requested

const COLUMN_LEFT := 72.0
const COLUMN_WIDTH := 500.0
const TITLE_TOP := 64.0
const COLUMN_BOTTOM_MARGIN := 64.0
const HINTS_BOTTOM_MARGIN := 40.0
const COLUMN_SEPARATION := 14
const BUTTON_SEPARATION := 10
## Space above the buttons.
const BUTTONS_GAP := 14.0

const LOGO_SIZES: Array[int] = [64, 84, 84]
const HEADING_SIZE := 64

const INTRO_SECONDS := 0.6
const SLIDE_SECONDS := 0.22
const SLIDE_DISTANCE := 48.0
const LOGO_TICK_SECONDS := 1.0
## Confirm presses are ignored this long after an end screen appears, so a player mashing
## jump as the run ends does not skip the screen by accident.
const CONFIRM_GRACE_MSEC := 400
const SCORE_STEPS := 12
const SCORE_STEP_SECONDS := 0.05
## A stick pushed this far skips the intro, the same as pressing a button.
const SKIP_STICK_THRESHOLD := 0.5

var _settings: UiSettings
var _device: InputDeviceTracker
var _root: Control
var _vignette: TextureRect
var _column: VBoxContainer
var _logo: VBoxContainer
var _logo_lines: Array[BrassLine] = []
var _heading: BrassLine
var _body: Label
var _score: Label
var _buttons: VBoxContainer
var _hints: HintBar
var _logo_timer: Timer
var _motion: Tween
var _score_tween: Tween
var _motion_button: ClockButton
var _last_focus: ClockButton
var _back := Callable()
var _back_text := ""
var _score_target := -1
var _confirm_allowed_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiTheme.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_vignette = _add_backdrop(UiTheme.vignette())
	_add_backdrop(UiTheme.left_scrim())
	_build_column()
	_hints = HintBar.new()
	_root.add_child(_hints)
	_hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	_hints.offset_left = COLUMN_LEFT
	_hints.offset_top = -HINTS_BOTTOM_MARGIN
	_hints.offset_bottom = -HINTS_BOTTOM_MARGIN
	_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_logo_timer = Timer.new()
	_logo_timer.wait_time = LOGO_TICK_SECONDS
	_logo_timer.timeout.connect(_tick_logo)
	add_child(_logo_timer)


## Connects preferences and device tracking. Call once after adding to the tree.
func bind(settings: UiSettings, device: InputDeviceTracker) -> void:
	_settings = settings
	_device = device
	_settings.changed.connect(_on_settings_changed)
	_device.device_changed.connect(func(_kind: InputDeviceTracker.Kind) -> void: _refresh_hints())


## Shows the menu for a game state, or nothing during play. summary fills in end-of-run text,
## and a score of 0 or more is shown as the run's result.
func show_for(state: GameFlow.State, summary: String, score := -1) -> void:
	_finish_motion()
	_clear_buttons()
	_logo_timer.stop()
	_confirm_allowed_msec = 0
	match state:
		GameFlow.State.TITLE:
			_present_title()
		GameFlow.State.PAUSED:
			_present(tr("PAUSED"), summary, -1, resume_requested.emit, tr("Resume"), [
				[tr("Resume"), resume_requested.emit],
				[tr("Restart run"), start_requested.emit],
				_motion_entry(),
				[tr("Title screen"), title_requested.emit],
			])
		GameFlow.State.GAME_OVER:
			_present(tr("GAME OVER"), summary, score, title_requested.emit, tr("Title screen"), [
				[tr("Try again"), start_requested.emit],
				[tr("Title screen"), title_requested.emit],
			])
			_confirm_allowed_msec = Time.get_ticks_msec() + CONFIRM_GRACE_MSEC
		GameFlow.State.LEVEL_CLEAR:
			_present(tr("WORKSHOP CLEARED"), summary, score, title_requested.emit, tr("Title screen"), [
				[tr("Play again"), start_requested.emit],
				[tr("Title screen"), title_requested.emit],
			])
			_confirm_allowed_msec = Time.get_ticks_msec() + CONFIRM_GRACE_MSEC
			_start_score_tick()
		_:
			_root.visible = false
			_back = Callable()


## The key names in the current menu hint row, such as "A" or "Enter".
func hint_keys() -> Array[String]:
	return _hints.keys()


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if _is_press(event):
		_finish_motion()
	if event.is_action("ui_accept") and Time.get_ticks_msec() < _confirm_allowed_msec:
		get_viewport().set_input_as_handled()
	if event.is_echo() and _is_menu_direction(event):
		# Holding a key sends about 30 repeats a second, which made the selection race through
		# the menu and stop somewhere that often looked like the opposite of the key pressed.
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and _back.is_valid() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back.call()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN and _root != null:
		_restore_focus()


func _present_title() -> void:
	_logo.visible = true
	_heading.visible = false
	_vignette.visible = true
	_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	_column.offset_top = TITLE_TOP
	_show_menu(tr("Race the clock, stomp the gear-beetles and reach the Golden Key!"), -1, Callable(), "", [
		[tr("Start"), start_requested.emit],
		_motion_entry(),
		[tr("Quit"), quit_requested.emit],
	])
	if not _is_reduced_motion():
		_logo_timer.start()
	_play_entrance(INTRO_SECONDS)


func _present(heading: String, body: String, score: int, back: Callable, back_text: String, entries: Array) -> void:
	_logo.visible = false
	_heading.visible = true
	_heading.configure(heading, HEADING_SIZE)
	_vignette.visible = false
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.offset_top = 0.0
	_show_menu(body, score, back, back_text, entries)
	_play_entrance(SLIDE_SECONDS)


func _show_menu(body: String, score: int, back: Callable, back_text: String, entries: Array) -> void:
	_root.visible = true
	_body.text = body
	_body.visible = not body.is_empty()
	_score_target = score
	_score.visible = score >= 0
	if score >= 0:
		_score.text = tr("Score %d") % score
	_back = back
	_back_text = back_text
	for entry: Array in entries:
		_add_button(entry[0], entry[1])
	_link_focus_ring()
	_last_focus = _buttons.get_child(0) as ClockButton
	_last_focus.grab_focus()
	_refresh_hints()


func _add_button(text: String, on_pressed: Callable) -> ClockButton:
	var button := ClockButton.new()
	button.text = text
	button.reduced_motion = _is_reduced_motion()
	button.pressed.connect(on_pressed)
	button.focus_entered.connect(func() -> void: _last_focus = button)
	button.focus_exited.connect(_restore_focus, CONNECT_DEFERRED)
	_buttons.add_child(button)
	if on_pressed == reduced_motion_toggle_requested.emit:
		_motion_button = button
	return button


## Up and down stop at the ends of the list, so Up can never land on a lower button or Down on a
## higher one. Left and right stay on the same button.
func _link_focus_ring() -> void:
	var last := _buttons.get_child_count() - 1
	for i in last + 1:
		var button := _buttons.get_child(i) as Control
		var previous := _buttons.get_child(maxi(i - 1, 0)) as Control
		var next := _buttons.get_child(mini(i + 1, last)) as Control
		button.focus_neighbor_top = previous.get_path()
		button.focus_previous = previous.get_path()
		button.focus_neighbor_bottom = next.get_path()
		button.focus_next = next.get_path()
		button.focus_neighbor_left = button.get_path()
		button.focus_neighbor_right = button.get_path()


## A click on empty space, or the window losing focus, must not leave a controller player
## with nothing selected, because then direction input would do nothing.
func _restore_focus() -> void:
	if not _root.visible or get_viewport().gui_get_focus_owner() != null:
		return
	if is_instance_valid(_last_focus) and _last_focus.is_inside_tree():
		_last_focus.grab_focus()


func _clear_buttons() -> void:
	_motion_button = null
	_last_focus = null
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()


func _motion_entry() -> Array:
	return [_motion_text(), reduced_motion_toggle_requested.emit]


func _motion_text() -> String:
	return tr("Reduced motion: On") if _is_reduced_motion() else tr("Reduced motion: Off")


func _is_reduced_motion() -> bool:
	return _settings != null and _settings.reduced_motion


func _on_settings_changed() -> void:
	var reduced := _is_reduced_motion()
	for child in _buttons.get_children():
		(child as ClockButton).reduced_motion = reduced
	if _motion_button != null:
		_motion_button.text = _motion_text()
	if reduced:
		_logo_timer.stop()
	elif _root.visible and _logo.visible:
		_logo_timer.start()


func _refresh_hints() -> void:
	if _device != null and _root.visible:
		_hints.show_menu_hints(_device.kind, _back_text)


func _tick_logo() -> void:
	_logo_lines[0].tick_cog()


func _play_entrance(seconds: float) -> void:
	if _is_reduced_motion():
		return
	_column.modulate.a = 0.0
	_column.offset_transform_position = Vector2(-SLIDE_DISTANCE, 0.0)
	_motion = create_tween().set_parallel()
	_motion.tween_property(_column, "modulate:a", 1.0, seconds * 0.5)
	_motion.tween_property(_column, "offset_transform_position", Vector2.ZERO, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Counts the score up in visible steps. The final value is already in place if motion is off.
func _start_score_tick() -> void:
	if _is_reduced_motion() or _score_target <= 0:
		return
	_score_tween = create_tween()
	for step in range(1, SCORE_STEPS + 1):
		_score_tween.tween_callback(_show_score.bind(_score_target * step / SCORE_STEPS)).set_delay(SCORE_STEP_SECONDS)
	_show_score(0)


func _show_score(value: int) -> void:
	_score.text = tr("Score %d") % value


## Ends any entrance or count-up at once. Any input does this, so motion is always skippable.
func _finish_motion() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	if _score_tween != null:
		_score_tween.kill()
		_score_tween = null
		_show_score(_score_target)
	_column.modulate.a = 1.0
	_column.offset_transform_position = Vector2.ZERO


func _is_menu_direction(event: InputEvent) -> bool:
	return (
		event.is_action("ui_up")
		or event.is_action("ui_down")
		or event.is_action("ui_left")
		or event.is_action("ui_right")
	)


func _is_press(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= SKIP_STICK_THRESHOLD
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		return event.is_pressed()
	return false


func _add_backdrop(texture: Texture2D) -> TextureRect:
	var backdrop := TextureRect.new()
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	return backdrop


func _build_column() -> void:
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.offset_transform_enabled = true
	_column.add_theme_constant_override(&"separation", COLUMN_SEPARATION)
	_root.add_child(_column)
	_column.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_column.offset_left = COLUMN_LEFT
	_column.offset_right = COLUMN_LEFT + COLUMN_WIDTH
	_column.offset_bottom = -COLUMN_BOTTOM_MARGIN

	_logo = VBoxContainer.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.add_theme_constant_override(&"separation", 0)
	_logo.accessibility_name = tr("Tock's Wind-Up Workshop")
	_column.add_child(_logo)
	var words: Array[String] = [tr("TOCK'S"), tr("WIND-UP"), tr("WORKSHOP")]
	for i in words.size():
		var line := BrassLine.new()
		line.max_width = COLUMN_WIDTH
		_logo.add_child(line)
		line.configure(words[i], LOGO_SIZES[i], i == 0)
		_logo_lines.append(line)

	_heading = BrassLine.new()
	_heading.max_width = COLUMN_WIDTH
	_column.add_child(_heading)

	_body = Label.new()
	_body.theme_type_variation = UiTheme.LABEL_BODY
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(COLUMN_WIDTH - COLUMN_LEFT, 0.0)
	_body.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_column.add_child(_body)

	_score = Label.new()
	_score.theme_type_variation = UiTheme.LABEL_SCORE
	_column.add_child(_score)

	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(0.0, BUTTONS_GAP)
	_column.add_child(gap)

	_buttons = VBoxContainer.new()
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_buttons.add_theme_constant_override(&"separation", BUTTON_SEPARATION)
	_column.add_child(_buttons)
