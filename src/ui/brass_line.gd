class_name BrassLine
extends Control
## One line of cast-brass display text: shadow, edge and highlight layers behind a shaded face.
## Can replace the first letter O with a cog, which is what makes the title a logo.
## Implements the title treatment in design/art/art-bible.md section 6.
##
## Usage:
##   var line := BrassLine.new()
##   column.add_child(line)
##   line.configure(tr("TOCK'S"), 64, true)

## Height of the capital letters, as a fraction of the font size (Open Sans).
const CAP_HEIGHT := 0.72
## Empty space under the capitals, as a fraction of the font size.
const LINE_GAP := 0.34
const SHADOW_OFFSET := Vector2(0.0, 6.0)
const EDGE_OFFSET := Vector2(0.0, 3.0)
const HIGHLIGHT_OFFSET := Vector2(0.0, -1.0)
const COG_SCALE := 1.08
## Space beside the cog, as a fraction of the font size.
const COG_GAP := 0.05
const MIN_FONT_SIZE := 28
const COG_LETTER := "O"
const FACE_SHADER_CODE := """
shader_type canvas_item;
// Vertical cast-brass ramp across the capital letters.
uniform float cap_height = 64.0;
varying float line_y;

void vertex() {
	line_y = VERTEX.y;
}

void fragment() {
	float t = clamp(line_y / cap_height, 0.0, 1.0);
	vec3 top = vec3(1.0, 0.914, 0.659);
	vec3 middle = vec3(0.89, 0.643, 0.173);
	vec3 bottom = vec3(0.725, 0.463, 0.102);
	COLOR.rgb = t < 0.5 ? mix(top, middle, t * 2.0) : mix(middle, bottom, (t - 0.5) * 2.0);
}
"""

static var _face_shader: Shader

## Largest width in pixels. Longer translated text uses a smaller size. 0 means no limit.
var max_width := 0.0

var _font_size := 64
var _runs: Array = []
var _cap := 0.0
var _face: Control
var _face_material: ShaderMaterial
var _cog: CogGlyph


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_material = ShaderMaterial.new()
	_face_material.shader = _shared_shader()
	_face = Control.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.material = _face_material
	_face.draw.connect(_draw_face)
	add_child(_face)


## Sets the text. With use_cog, the first letter O becomes a drawn cog.
func configure(text: String, font_size: int, use_cog := false) -> void:
	var parts := text.split(COG_LETTER, true, 1) if use_cog else PackedStringArray([text])
	_font_size = _fitted_size(parts, font_size)
	_cap = _font_size * CAP_HEIGHT
	_runs.clear()
	var font := UiTheme.display_font()
	var x := 0.0
	var has_cog := parts.size() > 1
	_runs.append([parts[0], x])
	x += font.get_string_size(parts[0], HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	if has_cog:
		_place_cog(x)
		x += _cog_advance()
		_runs.append([parts[1], x])
		x += font.get_string_size(parts[1], HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	elif _cog != null:
		_cog.visible = false
	custom_minimum_size = Vector2(x, _cap + _font_size * LINE_GAP)
	_face.size = custom_minimum_size
	_face_material.set_shader_parameter(&"cap_height", _cap)
	_face.queue_redraw()
	queue_redraw()


## Advances the logo cog by one tooth. Does nothing on a line without a cog.
func tick_cog() -> void:
	if _cog != null and _cog.visible:
		_cog.advance()


func _draw() -> void:
	_draw_layer(self, SHADOW_OFFSET, UiTheme.INK)
	_draw_layer(self, EDGE_OFFSET, UiTheme.BRASS_DEEP)
	_draw_layer(self, HIGHLIGHT_OFFSET, UiTheme.BRASS_GLINT)


func _draw_face() -> void:
	_draw_layer(_face, Vector2.ZERO, UiTheme.BRASS_FACE)


func _draw_layer(canvas: CanvasItem, offset: Vector2, color: Color) -> void:
	var font := UiTheme.display_font()
	for run: Array in _runs:
		var at := Vector2(run[1] as float, _cap) + offset
		canvas.draw_string(font, at, run[0], HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, color)


func _place_cog(x: float) -> void:
	if _cog == null:
		_cog = CogGlyph.new()
		_cog.layers = [
			[SHADOW_OFFSET, UiTheme.INK, UiTheme.INK],
			[EDGE_OFFSET, UiTheme.BRASS_DEEP, UiTheme.BRASS_DEEP],
			[HIGHLIGHT_OFFSET, UiTheme.BRASS_GLINT, UiTheme.BRASS_GLINT],
			[Vector2.ZERO, UiTheme.BRASS_HIGHLIGHT, UiTheme.BRASS_SHADE],
		]
		add_child(_cog)
	var side := _cap * COG_SCALE
	_cog.visible = true
	_cog.size = Vector2(side, side)
	_cog.position = Vector2(x + _font_size * COG_GAP, (_cap - side) * 0.5)


func _cog_advance() -> float:
	return _cap * COG_SCALE + _font_size * COG_GAP * 2.0


func _fitted_size(parts: PackedStringArray, wanted: int) -> int:
	if max_width <= 0.0:
		return wanted
	var font := UiTheme.display_font()
	var fitted := wanted
	while fitted > MIN_FONT_SIZE:
		var width := 0.0
		for part in parts:
			width += font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
		if parts.size() > 1:
			width += fitted * (CAP_HEIGHT * COG_SCALE + COG_GAP * 2.0)
		if width <= max_width:
			break
		fitted -= 2
	return fitted


static func _shared_shader() -> Shader:
	if _face_shader == null:
		_face_shader = Shader.new()
		_face_shader.code = FACE_SHADER_CODE
	return _face_shader
