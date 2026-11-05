class_name HintBar
extends HBoxContainer
## A row of control hints, written for whichever device the player used last.
##
## Usage:
##   hint_bar.show_play_hints(InputDeviceTracker.Kind.GAMEPAD)   # "[A] Jump" and so on
##   hint_bar.show_menu_hints(kind, tr("Resume"))

const SEPARATION := 14
const KEY_SEPARATION := 7

var _keys: Array[String] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", SEPARATION)


## The key names shown at the moment, such as "A" or "Space".
func keys() -> Array[String]:
	return _keys


## Shows the in-game controls for a device.
func show_play_hints(kind: InputDeviceTracker.Kind) -> void:
	if kind == InputDeviceTracker.Kind.GAMEPAD:
		_show([
			[tr("Left Stick"), tr("Move")],
			[tr("A"), tr("Jump")],
			[tr("X"), tr("Run")],
			[tr("Right Stick"), tr("Camera")],
			[tr("Start"), tr("Pause")],
		])
	else:
		_show([
			[tr("WASD"), tr("Move")],
			[tr("Space"), tr("Jump")],
			[tr("Shift"), tr("Run")],
			[tr("Mouse"), tr("Camera")],
			[tr("Esc"), tr("Pause")],
		])


## Shows the menu controls for a device. An empty back_text leaves the back hint out.
func show_menu_hints(kind: InputDeviceTracker.Kind, back_text: String) -> void:
	var pad := kind == InputDeviceTracker.Kind.GAMEPAD
	var pairs: Array = [[tr("A") if pad else tr("Enter"), tr("Select")]]
	if not back_text.is_empty():
		pairs.append([tr("B") if pad else tr("Esc"), back_text])
	_show(pairs)


func _show(pairs: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_keys.clear()
	for pair: Array in pairs:
		_keys.append(pair[0])
		add_child(_build_hint(pair[0], pair[1]))


func _build_hint(key_text: String, action_text: String) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", KEY_SEPARATION)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.theme_type_variation = UiTheme.PANEL_HINT_CHIP
	var key_label := Label.new()
	key_label.theme_type_variation = UiTheme.LABEL_HINT_KEY
	key_label.text = key_text
	chip.add_child(key_label)
	row.add_child(chip)
	var action_label := Label.new()
	action_label.theme_type_variation = UiTheme.LABEL_HINT_TEXT
	action_label.text = action_text
	row.add_child(action_label)
	return row
