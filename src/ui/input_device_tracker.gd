class_name InputDeviceTracker
extends Node
## Tracks which device the player used last, so hints match it, and looks after controllers
## being plugged in or removed. It only watches input and never consumes it.
##
## Usage:
##   tracker.device_changed.connect(_refresh_hints)
##   tracker.active_gamepad_lost.connect(_pause_game)

## The kind of device used most recently changed.
signal device_changed(kind: Kind)
## The controller the player was using was removed.
signal active_gamepad_lost

enum Kind { KEYBOARD_MOUSE, GAMEPAD }

## Stick travel needed to count as using the controller, so a drifting stick does not switch hints.
const STICK_THRESHOLD := 0.35
## Mouse travel in pixels needed to count as using the mouse, so a nudged desk does not.
const MOUSE_THRESHOLD := 12.0
## Mouse travel adds up until the mouse rests this long, so a slow, deliberate move still counts.
const MOUSE_REST_MSEC := 250

var kind := Kind.KEYBOARD_MOUSE

var _last_gamepad := -1
var _mouse_travel := 0.0
var _last_mouse_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.is_pressed():
			_use_gamepad(event.device)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= STICK_THRESHOLD:
			_use_gamepad(event.device)
	elif event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			_set_kind(Kind.KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion:
		# Screen distance: the plain "relative" is scaled by the window's stretch.
		_add_mouse_travel((event as InputEventMouseMotion).screen_relative.length())


func _add_mouse_travel(distance: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_mouse_msec > MOUSE_REST_MSEC:
		_mouse_travel = 0.0
	_last_mouse_msec = now
	_mouse_travel += distance
	if _mouse_travel >= MOUSE_THRESHOLD:
		_set_kind(Kind.KEYBOARD_MOUSE)


func _use_gamepad(device: int) -> void:
	_last_gamepad = device
	_set_kind(Kind.GAMEPAD)


func _set_kind(value: Kind) -> void:
	if kind == value:
		return
	kind = value
	device_changed.emit(kind)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	_release_held_inputs(device)
	if kind == Kind.GAMEPAD and device == _last_gamepad:
		_set_kind(Kind.KEYBOARD_MOUSE)
		active_gamepad_lost.emit()


## The engine does not send a release for what was held when a controller was removed, so
## Tock would keep running. Sending neutral events clears those actions for that device only.
func _release_held_inputs(device: int) -> void:
	for button in JOY_BUTTON_SDL_MAX:
		var release := InputEventJoypadButton.new()
		release.device = device
		release.button_index = button as JoyButton
		release.pressed = false
		Input.parse_input_event(release)
	for axis in JOY_AXIS_SDL_MAX:
		var center := InputEventJoypadMotion.new()
		center.device = device
		center.axis = axis as JoyAxis
		center.axis_value = 0.0
		Input.parse_input_event(center)
