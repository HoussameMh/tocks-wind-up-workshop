class_name InputSetup
extends RefCounted
## Registers keyboard and gamepad actions. Keys use physical positions, so WASD
## stays in the same place on AZERTY and other keyboard layouts.

## Stick travel ignored in play. Input.get_vector rescales what is left, so walking stays analog.
const DEADZONE := 0.2
## Stick travel needed before a menu moves. Large, so a push at an angle moves focus only once.
const MENU_DEADZONE := 0.5
## Matches every device. A new event defaults to device 0, which would only accept the first
## controller, and a controller can come back with a new number after being plugged in again.
const ALL_DEVICES := -1


## Safe to call more than once. Usage: InputSetup.install()
static func install() -> void:
	_add("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add("move_forward", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("move_back", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("jump", [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_add("run", [_key(KEY_SHIFT), _button(JOY_BUTTON_X)])
	_add("fire", [_key(KEY_F), _mouse(MOUSE_BUTTON_LEFT), _button(JOY_BUTTON_RIGHT_SHOULDER), _button(JOY_BUTTON_B)])
	_add("camera_left", [_key(KEY_Q), _axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add("camera_right", [_key(KEY_E), _axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add("camera_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add("camera_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_add("pause", [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
	_extend_menu_action("ui_accept", [_button(JOY_BUTTON_A)])
	_extend_menu_action("ui_cancel", [_button(JOY_BUTTON_B)])
	_extend_menu_action("ui_up", [_button(JOY_BUTTON_DPAD_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_extend_menu_action("ui_down", [_button(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_extend_menu_action("ui_left", [_button(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_extend_menu_action("ui_right", [_button(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])


static func _add(action: String, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, DEADZONE)
	for event in events:
		InputMap.action_add_event(action, event)


## The engine's menu actions already exist, so this only adds what they are missing.
static func _extend_menu_action(action: String, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, MENU_DEADZONE)
	for event in events:
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEvent:
	var event := InputEventKey.new()
	event.device = ALL_DEVICES
	event.physical_keycode = code
	return event


static func _mouse(button: MouseButton) -> InputEvent:
	var event := InputEventMouseButton.new()
	event.device = ALL_DEVICES
	event.button_index = button
	return event


static func _button(button: JoyButton) -> InputEvent:
	var event := InputEventJoypadButton.new()
	event.device = ALL_DEVICES
	event.button_index = button
	return event


static func _axis(axis: JoyAxis, value: float) -> InputEvent:
	var event := InputEventJoypadMotion.new()
	event.device = ALL_DEVICES
	event.axis = axis
	event.axis_value = value
	return event
