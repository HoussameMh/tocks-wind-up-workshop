class_name UiTheme
extends RefCounted
## The palette, fonts, scrims and one shared Theme for every menu and HUD control.
## Implements design/art/art-bible.md section 6.
##
## Usage:
##   root_control.theme = UiTheme.theme()
##   label.theme_type_variation = UiTheme.LABEL_BODY

const INK := Color("140d08")
const WALNUT := Color("2a1a10")
const WALNUT_HOVER := Color("3a2416")
const BRASS_HIGHLIGHT := Color("ffe9a8")
const BRASS_FACE := Color("e3a42c")
const BRASS_DEEP := Color("8f5a16")
const BRASS_SHADE := Color("b9761a")
const BRASS_GLINT := Color("fff4cf")
const CREAM := Color("f6e7c8")
const MUTED := Color("bfae93")
const SIGNAL_RED := Color("d8452f")

## Theme type variations. Controls choose one of these instead of overriding single values.
const BUTTON_FOCUSED := &"FocusedButton"
const LABEL_BODY := &"BodyLabel"
const LABEL_SCORE := &"ScoreLabel"
const LABEL_HUD := &"HudLabel"
const LABEL_HUD_LOW := &"HudLowLabel"
const LABEL_HINT_KEY := &"HintKeyLabel"
const LABEL_HINT_TEXT := &"HintTextLabel"
const PANEL_PLAQUE := &"PlaquePanel"
const PANEL_PLAQUE_LOW := &"PlaqueLowPanel"
const PANEL_HINT_CHIP := &"HintChipPanel"

const BUTTON_FONT_SIZE := 24
const BUTTON_CORNER_RADIUS := 3
const BUTTON_BORDER := 2
const BUTTON_MARGIN_LEFT := 20.0
const BUTTON_MARGIN_RIGHT := 14.0
const BUTTON_SHADOW_SIZE := 6
const BUTTON_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.5)
const BUTTON_NORMAL_ALPHA := 0.88

const BODY_FONT_SIZE := 20
const SCORE_FONT_SIZE := 34
const HUD_FONT_SIZE := 28
const HUD_LOW_FONT_SIZE := 34
const HINT_FONT_SIZE := 17
const PLAQUE_ALPHA := 0.6
## Stronger than the bible's 0.6: signal red was hard to read in front of the bright window.
const PLAQUE_LOW_ALPHA := 0.88
const TEXT_SHADOW_COLOR := Color(0.078, 0.051, 0.031, 0.85)
const TEXT_SHADOW_OFFSET := 2

const TITLE_EMBOLDEN := 0.9
const TITLE_GLYPH_SPACING := 3
const HUD_EMBOLDEN := 0.5

const SCRIM_ALPHA := 0.85
## The left scrim is fully clear from this fraction of the screen width.
const SCRIM_END := 0.55
const SCRIM_TEXTURE_WIDTH := 128
const VIGNETTE_ALPHA := 0.45
## Radial position where the vignette starts to darken; 1.0 is the corner.
const VIGNETTE_START := 0.6
const VIGNETTE_TEXTURE_SIZE := 128

static var _theme: Theme
static var _display_font: FontVariation
static var _hud_font: FontVariation
static var _left_scrim: GradientTexture2D
static var _vignette: GradientTexture2D


## The one shared Theme. Built once, because the UI never changes it at run time.
static func theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme


## Emboldened, spaced default font for the logo and screen headings.
static func display_font() -> FontVariation:
	if _display_font == null:
		_display_font = FontVariation.new()
		_display_font.base_font = ThemeDB.fallback_font
		_display_font.variation_embolden = TITLE_EMBOLDEN
		_display_font.spacing_glyph = TITLE_GLYPH_SPACING
	return _display_font


## Emboldened default font for HUD numbers.
static func hud_font() -> FontVariation:
	if _hud_font == null:
		_hud_font = FontVariation.new()
		_hud_font.base_font = ThemeDB.fallback_font
		_hud_font.variation_embolden = HUD_EMBOLDEN
	return _hud_font


## Ink darkening the left side of the screen behind the menu column.
static func left_scrim() -> GradientTexture2D:
	if _left_scrim == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(INK, SCRIM_ALPHA))
		gradient.set_color(1, Color(INK, 0.0))
		gradient.set_offset(1, SCRIM_END)
		_left_scrim = GradientTexture2D.new()
		_left_scrim.gradient = gradient
		_left_scrim.width = SCRIM_TEXTURE_WIDTH
		_left_scrim.height = 1
		_left_scrim.fill_from = Vector2.ZERO
		_left_scrim.fill_to = Vector2.RIGHT
	return _left_scrim


## Ink darkening the corners of the title screen.
static func vignette() -> GradientTexture2D:
	if _vignette == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(INK, 0.0))
		gradient.set_offset(0, VIGNETTE_START)
		gradient.set_color(1, Color(INK, VIGNETTE_ALPHA))
		_vignette = GradientTexture2D.new()
		_vignette.gradient = gradient
		_vignette.width = VIGNETTE_TEXTURE_SIZE
		_vignette.height = VIGNETTE_TEXTURE_SIZE
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.5)
		_vignette.fill_to = Vector2.ONE
	return _vignette


static func _build_theme() -> Theme:
	var built := Theme.new()
	_add_button_styles(built)
	built.set_color(&"font_color", &"Label", CREAM)
	built.set_color(&"font_shadow_color", &"Label", TEXT_SHADOW_COLOR)
	built.set_constant(&"shadow_offset_x", &"Label", 0)
	built.set_constant(&"shadow_offset_y", &"Label", TEXT_SHADOW_OFFSET)
	_add_label(built, LABEL_BODY, BODY_FONT_SIZE, CREAM, null)
	_add_label(built, LABEL_SCORE, SCORE_FONT_SIZE, CREAM, hud_font())
	_add_label(built, LABEL_HUD, HUD_FONT_SIZE, CREAM, hud_font())
	_add_label(built, LABEL_HUD_LOW, HUD_LOW_FONT_SIZE, SIGNAL_RED, hud_font())
	_add_label(built, LABEL_HINT_KEY, HINT_FONT_SIZE, INK, null)
	built.set_color(&"font_shadow_color", LABEL_HINT_KEY, Color.TRANSPARENT)
	_add_label(built, LABEL_HINT_TEXT, HINT_FONT_SIZE, MUTED, null)
	built.set_type_variation(PANEL_PLAQUE, &"PanelContainer")
	built.set_stylebox(&"panel", PANEL_PLAQUE, _panel_box(Color(INK, PLAQUE_ALPHA), Vector2(14.0, 4.0)))
	built.set_type_variation(PANEL_PLAQUE_LOW, &"PanelContainer")
	built.set_stylebox(&"panel", PANEL_PLAQUE_LOW, _panel_box(Color(INK, PLAQUE_LOW_ALPHA), Vector2(14.0, 4.0)))
	built.set_type_variation(PANEL_HINT_CHIP, &"PanelContainer")
	built.set_stylebox(&"panel", PANEL_HINT_CHIP, _panel_box(BRASS_FACE, Vector2(8.0, 1.0)))
	return built


static func _add_button_styles(built: Theme) -> void:
	var normal := _button_box(Color(WALNUT, BUTTON_NORMAL_ALPHA), BRASS_DEEP)
	normal.shadow_color = BUTTON_SHADOW_COLOR
	normal.shadow_size = BUTTON_SHADOW_SIZE
	var hover := _button_box(WALNUT_HOVER, BRASS_FACE)
	var focused := _button_box(BRASS_FACE, BRASS_HIGHLIGHT)
	var pressed := _button_box(BRASS_DEEP, BRASS_HIGHLIGHT)
	built.set_font_size(&"font_size", &"Button", BUTTON_FONT_SIZE)
	built.set_stylebox(&"normal", &"Button", normal)
	built.set_stylebox(&"hover", &"Button", hover)
	built.set_stylebox(&"pressed", &"Button", pressed)
	built.set_stylebox(&"hover_pressed", &"Button", pressed)
	built.set_stylebox(&"disabled", &"Button", normal)
	# The engine paints the focus box over the state box, which would hide "pressed".
	# ClockButton switches to the FocusedButton variation instead, so this one stays empty.
	built.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	built.set_color(&"font_color", &"Button", CREAM)
	built.set_color(&"font_focus_color", &"Button", CREAM)
	built.set_color(&"font_hover_color", &"Button", BRASS_HIGHLIGHT)
	built.set_color(&"font_pressed_color", &"Button", INK)
	built.set_color(&"font_hover_pressed_color", &"Button", INK)
	built.set_color(&"font_disabled_color", &"Button", MUTED)
	built.set_type_variation(BUTTON_FOCUSED, &"Button")
	built.set_stylebox(&"normal", BUTTON_FOCUSED, focused)
	built.set_stylebox(&"hover", BUTTON_FOCUSED, focused)
	for color_name: StringName in [&"font_color", &"font_focus_color", &"font_hover_color"]:
		built.set_color(color_name, BUTTON_FOCUSED, INK)


static func _add_label(built: Theme, type: StringName, size: int, color: Color, font: Font) -> void:
	built.set_type_variation(type, &"Label")
	built.set_font_size(&"font_size", type, size)
	built.set_color(&"font_color", type, color)
	if font != null:
		built.set_font(&"font", type, font)


static func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(BUTTON_BORDER)
	box.set_corner_radius_all(BUTTON_CORNER_RADIUS)
	box.content_margin_left = BUTTON_MARGIN_LEFT
	box.content_margin_right = BUTTON_MARGIN_RIGHT
	return box


static func _panel_box(fill: Color, padding: Vector2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(BUTTON_CORNER_RADIUS)
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y
	box.content_margin_bottom = padding.y
	return box
