class_name InputSetup
extends RefCounted
## Registers keyboard and gamepad actions. Keys use physical positions, so WASD
## stays in the same place on AZERTY and other keyboard layouts.

const DEADZONE := 0.2


## Safe to call more than once. Usage: InputSetup.install()
static func install() -> void:
	_add("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add("move_forward", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("move_back", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("jump", [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_add("run", [_key(KEY_SHIFT), _button(JOY_BUTTON_X)])
	_add("camera_left", [_key(KEY_Q), _axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add("camera_right", [_key(KEY_E), _axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add("camera_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add("camera_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_add("pause", [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])


static func _add(action: String, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, DEADZONE)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEvent:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _button(button: JoyButton) -> InputEvent:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


static func _axis(axis: JoyAxis, value: float) -> InputEvent:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event
