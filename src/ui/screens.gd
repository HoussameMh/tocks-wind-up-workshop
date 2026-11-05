class_name Screens
extends CanvasLayer
## Title, pause, game over and level-clear menus. Works with mouse, keyboard and
## gamepad. Button presses are only reported through signals.

signal start_requested
signal resume_requested
signal title_requested
signal quit_requested

var _dim: ColorRect
var _title: Label
var _body: Label
var _buttons: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0.09, 0.06, 0.04, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	_title = _add_text(column, 58, Color("ffd24a"))
	_body = _add_text(column, 24, Color.WHITE)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	column.add_child(_buttons)


## Shows the menu for a game state, or nothing during play. summary fills in end-of-run text.
func show_for(state: GameFlow.State, summary: String) -> void:
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	match state:
		GameFlow.State.TITLE:
			_present(
				tr("Tock's Wind-Up Workshop"),
				tr("Race the clock, stomp the gear-beetles and reach the Golden Key!"),
				[[tr("Start"), start_requested], [tr("Quit"), quit_requested]]
			)
		GameFlow.State.PAUSED:
			_present(
				tr("Paused"),
				"",
				[[tr("Resume"), resume_requested], [tr("Restart run"), start_requested], [tr("Title screen"), title_requested]]
			)
		GameFlow.State.GAME_OVER:
			_present(
				tr("Game Over"),
				summary,
				[[tr("Try again"), start_requested], [tr("Title screen"), title_requested]]
			)
		GameFlow.State.LEVEL_CLEAR:
			_present(
				tr("Workshop Cleared!"),
				summary,
				[[tr("Play again"), start_requested], [tr("Title screen"), title_requested]]
			)
		_:
			_dim.visible = false


func _present(title: String, body: String, buttons: Array) -> void:
	_dim.visible = true
	_title.text = title
	_body.text = body
	_body.visible = not body.is_empty()
	for entry: Array in buttons:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(320.0, 56.0)
		button.add_theme_font_size_override("font_size", 26)
		var requested: Signal = entry[1]
		button.pressed.connect(func() -> void: requested.emit())
		_buttons.add_child(button)
	(_buttons.get_child(0) as Button).grab_focus()


func _add_text(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label
