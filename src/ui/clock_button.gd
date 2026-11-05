class_name ClockButton
extends Button
## A menu button with distinct normal, hover, focus and pressed states and clockwork motion.
## Colors and boxes come from UiTheme; this class only picks the state and moves the button.
## Implements the button table in design/art/art-bible.md section 6.
##
## Usage:
##   var button := ClockButton.new()
##   button.text = tr("Start")
##   button.pressed.connect(start_requested.emit)
##   column.add_child(button)

const MIN_SIZE := Vector2(340.0, 54.0)
const ENGAGED_SHIFT := Vector2(6.0, 0.0)
const PRESSED_SHIFT := Vector2(0.0, 2.0)
const SHIFT_SECONDS := 0.12
const MARKER_SIZE := 24.0
## Gap between the marker cog and the button's left edge.
const MARKER_GAP := 12.0

## While true, the button changes state at once, with no shift animation or cog tick.
var reduced_motion := false

var _hovered := false
var _held := false
var _tween: Tween
var _marker: CogGlyph


func _init() -> void:
	custom_minimum_size = MIN_SIZE
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	offset_transform_enabled = true
	_marker = CogGlyph.new()
	_marker.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	_marker.position = Vector2(-MARKER_SIZE - MARKER_GAP, (MIN_SIZE.y - MARKER_SIZE) * 0.5)
	_marker.layers = [[Vector2.ZERO, UiTheme.BRASS_HIGHLIGHT, UiTheme.BRASS_FACE]]
	_marker.hole_color = UiTheme.BRASS_DEEP
	_marker.visible = false
	add_child(_marker)
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	button_down.connect(_on_held_changed.bind(true))
	button_up.connect(_on_held_changed.bind(false))


func _on_focus_changed(focused: bool) -> void:
	theme_type_variation = UiTheme.BUTTON_FOCUSED if focused else &""
	_marker.visible = focused
	if focused:
		_marker.advance(not reduced_motion and is_visible_in_tree())
	_update_shift()


func _on_hover_changed(hovered: bool) -> void:
	_hovered = hovered
	_update_shift()


func _on_held_changed(held: bool) -> void:
	_held = held
	_update_shift()


func _update_shift() -> void:
	var goal := Vector2.ZERO
	if _hovered or has_focus():
		goal += ENGAGED_SHIFT
	if _held:
		goal += PRESSED_SHIFT
	if _tween != null:
		_tween.kill()
	if reduced_motion or not is_inside_tree():
		offset_transform_position = goal
		return
	_tween = create_tween()
	_tween.tween_property(self, "offset_transform_position", goal, SHIFT_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
