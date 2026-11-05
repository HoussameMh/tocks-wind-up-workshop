class_name Hud
extends CanvasLayer
## In-game display. It only listens to RunState and never changes game state.

const FONT_SIZE := 30
const HINT_FONT_SIZE := 20
const HINT_SECONDS := 9.0

var _cogs: Label
var _lives: Label
var _score: Label
var _time: Label
var _hint: Label
var _hint_tween: Tween


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	for side: String in ["margin_left", "margin_right", "margin_top"]:
		margin.add_theme_constant_override(side, 22)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	margin.add_child(row)
	_lives = _add_label(row)
	_cogs = _add_label(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_score = _add_label(row)
	_time = _add_label(row)

	_hint = Label.new()
	_hint.text = tr("Move: WASD or arrows   Jump: Space   Run: Shift   Camera: mouse   Pause: Esc")
	_hint.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -56.0
	_hint.offset_bottom = -22.0
	add_child(_hint)


## Connects to a run. Call once after adding to the tree.
func bind(run_state: RunState) -> void:
	run_state.cogs_changed.connect(func(value: int) -> void: _cogs.text = tr("Cogs %d") % value)
	run_state.lives_changed.connect(func(value: int) -> void: _lives.text = tr("Tock x%d") % value)
	run_state.score_changed.connect(func(value: int) -> void: _score.text = tr("Score %d") % value)
	run_state.time_changed.connect(func(value: int) -> void: _time.text = tr("Time %d") % value)


## Shows the controls for a few seconds at the start of a run.
func show_hint() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
	_hint.modulate.a = 1.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(HINT_SECONDS)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 1.0)


func _add_label(parent: Control) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	parent.add_child(label)
	return label
