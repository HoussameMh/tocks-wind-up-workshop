class_name Hud
extends CanvasLayer
## In-game display. It only listens to RunState and never changes game state.
## Implements the HUD row of design/art/art-bible.md section 6.

## Above the menus' scrim, so the plaques stay crisp. The HUD never takes mouse input.
const LAYER_ABOVE_MENUS := 2
const EDGE_MARGIN := 18
const PLAQUE_SEPARATION := 10
const COG_GLYPH_SIZE := 28.0
const COG_GLYPH_SEPARATION := 8
const HINT_BOTTOM_MARGIN := 22.0
const HINT_SECONDS := 9.0
const HINT_FADE_SECONDS := 1.0
## At this many seconds or fewer, the time turns red and its digits grow.
const LOW_TIME_SECONDS := 30
const LOW_TIME_TICK_SCALE := 1.18
const LOW_TIME_TICK_SECONDS := 0.2
## How long the level banner stays up, and how long it fades.
const BANNER_SECONDS := 2.5
const BANNER_FADE_SECONDS := 0.5
const BANNER_TOP := 84.0
const GAUGE_TOP := 20.0

var _banner: Label
var _banner_tween: Tween
var _power: Label
var _boss_panel: CenterContainer
var _boss_gauge: BossGauge
var _can_fire := false
var _seen_blaster := false
var _settings: UiSettings
var _cogs: Label
var _cog_glyph: CogGlyph
var _lives: Label
var _score: Label
var _time: Label
var _time_plaque: PanelContainer
var _time_is_low := false
var _hint_plaque: CenterContainer
var _hints: HintBar
var _hint_tween: Tween
var _device: InputDeviceTracker


func _ready() -> void:
	layer = LAYER_ABOVE_MENUS
	var root := Control.new()
	root.theme = UiTheme.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top"]:
		margin.add_theme_constant_override(side, EDGE_MARGIN)
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override(&"separation", PLAQUE_SEPARATION)
	margin.add_child(row)

	_lives = _add_plaque(row)
	_cogs = _add_plaque(row)
	_cog_glyph = CogGlyph.new()
	_cog_glyph.custom_minimum_size = Vector2(COG_GLYPH_SIZE, COG_GLYPH_SIZE)
	_cog_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cog_row := HBoxContainer.new()
	cog_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cog_row.add_theme_constant_override(&"separation", COG_GLYPH_SEPARATION)
	var cog_plaque := _cogs.get_parent() as Control
	cog_plaque.remove_child(_cogs)
	cog_plaque.add_child(cog_row)
	cog_row.add_child(_cog_glyph)
	cog_row.add_child(_cogs)
	_power = _add_plaque(row)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_score = _add_plaque(row)
	_time = _add_plaque(row)
	_time_plaque = _time.get_parent() as PanelContainer
	_time_plaque.offset_transform_enabled = true
	_time_plaque.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_hint_plaque = CenterContainer.new()
	_hint_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_plaque)
	_hint_plaque.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_plaque.offset_top = -HINT_BOTTOM_MARGIN
	_hint_plaque.offset_bottom = -HINT_BOTTOM_MARGIN
	_hint_plaque.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var hint_panel := PanelContainer.new()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.theme_type_variation = UiTheme.PANEL_PLAQUE
	_hint_plaque.add_child(hint_panel)
	_hints = HintBar.new()
	hint_panel.add_child(_hints)
	_hint_plaque.modulate.a = 0.0

	var banner_row := CenterContainer.new()
	banner_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_row)
	banner_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner_row.offset_top = BANNER_TOP
	var banner_panel := PanelContainer.new()
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_panel.theme_type_variation = UiTheme.PANEL_PLAQUE
	banner_row.add_child(banner_panel)
	_banner = Label.new()
	_banner.theme_type_variation = UiTheme.LABEL_HUD
	banner_panel.add_child(_banner)
	banner_row.modulate.a = 0.0

	_boss_panel = CenterContainer.new()
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_boss_panel)
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_panel.offset_top = GAUGE_TOP
	var boss_plaque := PanelContainer.new()
	boss_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_plaque.theme_type_variation = UiTheme.PANEL_PLAQUE
	_boss_panel.add_child(boss_plaque)
	var boss_row := HBoxContainer.new()
	boss_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_row.add_theme_constant_override(&"separation", COG_GLYPH_SEPARATION)
	boss_plaque.add_child(boss_row)
	var boss_label := Label.new()
	boss_label.theme_type_variation = UiTheme.LABEL_HUD
	boss_label.text = tr("Baron Rust")
	boss_row.add_child(boss_label)
	_boss_gauge = BossGauge.new()
	_boss_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boss_row.add_child(_boss_gauge)
	_boss_panel.visible = false


## Shows which form Tock is in, as words so color is never the only cue. Its controls follow.
func set_form(form: PowerState.Form) -> void:
	match form:
		PowerState.Form.BLASTER:
			_power.text = tr("Blaster")
		PowerState.Form.COILED:
			_power.text = tr("Coil")
		_:
			_power.text = tr("Small")
	var can_fire := form == PowerState.Form.BLASTER
	if can_fire == _can_fire:
		return
	_can_fire = can_fire
	if _device != null:
		_hints.show_play_hints(_device.kind, _can_fire)
	# The first Blaster of a run re-shows the controls, so the player learns the Fire button.
	if _can_fire and not _seen_blaster and visible:
		_seen_blaster = true
		show_hint()


## A new run: the first Blaster will show the controls again.
func new_run() -> void:
	_seen_blaster = false


## Shows which level this is for a moment.
func show_level_banner(number: int, total: int, level_name: String) -> void:
	show_caption(tr("Level %d of %d: %s") % [number, total, level_name])


## Shows one line of text across the top for a moment. A new line replaces the last.
func show_caption(text: String) -> void:
	_banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	var row := _banner.get_parent().get_parent() as Control
	row.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(BANNER_SECONDS)
	if _is_reduced_motion():
		_banner_tween.tween_callback(func() -> void: row.modulate.a = 0.0)
	else:
		_banner_tween.tween_property(row, "modulate:a", 0.0, BANNER_FADE_SECONDS)


## Shows the boss gauge. Only the boss level calls this.
func set_boss_health(hp: int, max_hp: int) -> void:
	_boss_panel.visible = true
	_boss_gauge.set_health(hp, max_hp)


## Hides the boss gauge.
func hide_boss_health() -> void:
	_boss_panel.visible = false


## The power plaque's text.
func power_text() -> String:
	return _power.text


## The banner's text.
func banner_text() -> String:
	return _banner.text


## True while the banner can be seen.
func banner_visible() -> bool:
	return (_banner.get_parent().get_parent() as Control).modulate.a > 0.01


## True while the boss gauge is up.
func boss_gauge_visible() -> bool:
	return _boss_panel.visible


## Filled pips on the boss gauge.
func boss_gauge_hp() -> int:
	return _boss_gauge.hp


## Connects to a run. Call once after adding to the tree.
func bind(run_state: RunState) -> void:
	run_state.cogs_changed.connect(_on_cogs_changed)
	run_state.lives_changed.connect(func(value: int) -> void: _lives.text = tr("Tock x%d") % value)
	run_state.score_changed.connect(func(value: int) -> void: _score.text = tr("Score %d") % value)
	run_state.time_changed.connect(_on_time_changed)


## Connects preferences and device tracking. Call once after adding to the tree.
func bind_input(settings: UiSettings, device: InputDeviceTracker) -> void:
	_settings = settings
	_device = device
	_device.device_changed.connect(_on_device_changed)
	_hints.show_play_hints(_device.kind, _can_fire)


## Shows the controls for a few seconds at the start of a run.
func show_hint() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_plaque.modulate.a = 1.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(HINT_SECONDS)
	_hint_tween.tween_property(_hint_plaque, "modulate:a", 0.0, HINT_FADE_SECONDS)


## Hides the play controls while a menu shows its own. The hint's timer keeps running.
func set_menu_open(open: bool) -> void:
	_hint_plaque.visible = not open
	# A caption across the top would run into a menu's heading.
	(_banner.get_parent().get_parent() as Control).visible = not open


## The key names in the control hint, such as "A" or "Space".
func hint_keys() -> Array[String]:
	return _hints.keys()


func _on_device_changed(kind: InputDeviceTracker.Kind) -> void:
	_hints.show_play_hints(kind, _can_fire)
	if visible:
		show_hint()


func _on_cogs_changed(value: int) -> void:
	if not _cogs.text.is_empty() and value > 0:
		_cog_glyph.advance(not _is_reduced_motion())
	_cogs.text = str(value)


func _on_time_changed(value: int) -> void:
	_time.text = tr("Time %d") % value
	var low := value <= LOW_TIME_SECONDS
	if low == _time_is_low:
		return
	_time_is_low = low
	# Color is never the only cue: the digits also grow.
	_time.theme_type_variation = UiTheme.LABEL_HUD_LOW if low else UiTheme.LABEL_HUD
	_time_plaque.theme_type_variation = UiTheme.PANEL_PLAQUE_LOW if low else UiTheme.PANEL_PLAQUE
	if low and not _is_reduced_motion():
		_time_plaque.offset_transform_scale = Vector2.ONE * LOW_TIME_TICK_SCALE
		var tick := create_tween()
		tick.tween_property(_time_plaque, "offset_transform_scale", Vector2.ONE, LOW_TIME_TICK_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _is_reduced_motion() -> bool:
	return _settings != null and _settings.reduced_motion


func _add_plaque(parent: Control) -> Label:
	var plaque := PanelContainer.new()
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.theme_type_variation = UiTheme.PANEL_PLAQUE
	plaque.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(plaque)
	var label := Label.new()
	label.theme_type_variation = UiTheme.LABEL_HUD
	plaque.add_child(label)
	return label
