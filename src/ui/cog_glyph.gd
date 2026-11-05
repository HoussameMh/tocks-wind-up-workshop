class_name CogGlyph
extends Control
## A gear drawn in code, used by the logo, the focused-button marker and the HUD.
## It advances one tooth at a time and never spins smoothly (art-bible section 6).
##
## Usage:
##   var cog := CogGlyph.new()
##   cog.custom_minimum_size = Vector2(24.0, 24.0)
##   cog.advance()

const TEETH := 8
const TOOTH_ANGLE := TAU / TEETH
const ROOT_RADIUS := 0.74
const HOLE_RADIUS := 0.26
const HOLE_SEGMENTS := 16
const EDGE_WIDTH := 1.0
## Fractions of one tooth's angle: where its flank starts and where its flat tip starts.
const FLANK_START := 0.31
const TIP_START := 0.17
const TICK_SECONDS := 0.2

## Drawn back to front. Each layer is [offset: Vector2, top: Color, bottom: Color].
var layers: Array = [[Vector2.ZERO, UiTheme.BRASS_HIGHLIGHT, UiTheme.BRASS_SHADE]]:
	set(value):
		layers = value
		queue_redraw()
var hole_color := UiTheme.INK:
	set(value):
		hole_color = value
		queue_redraw()

var _angle := 0.0
var _tween: Tween
var _outline := PackedVector2Array()
var _hole := PackedVector2Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline = _gear_outline()
	for i in HOLE_SEGMENTS:
		_hole.append(Vector2.from_angle(TAU * i / HOLE_SEGMENTS) * HOLE_RADIUS)


## Moves on by one tooth with a small overshoot, or straight there if animate is false.
func advance(animate := true) -> void:
	var goal := wrapf(_angle, 0.0, TAU) + TOOTH_ANGLE
	_angle = goal - TOOTH_ANGLE
	if _tween != null:
		_tween.kill()
	if not animate:
		_set_angle(goal)
		return
	_tween = create_tween()
	_tween.tween_method(_set_angle, _angle, goal, TICK_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_angle(value: float) -> void:
	_angle = value
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	var center := size * 0.5
	for layer: Array in layers:
		_draw_gear(center + (layer[0] as Vector2), radius, layer[1], layer[2])
	var hole := PackedVector2Array()
	for point in _hole:
		hole.append(center + point * radius)
	draw_colored_polygon(hole, hole_color)
	hole.append(hole[0])
	draw_polyline(hole, hole_color, EDGE_WIDTH, true)


func _draw_gear(center: Vector2, radius: float, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for point in _outline:
		var rotated := point.rotated(_angle)
		points.append(center + rotated * radius)
		colors.append(top.lerp(bottom, rotated.y * 0.5 + 0.5))
	draw_polygon(points, colors)
	# Polygons have no antialiasing, so a thin smooth line tidies the edge.
	points.append(points[0])
	colors.append(colors[0])
	draw_polyline_colors(points, colors, EDGE_WIDTH, true)


static func _gear_outline() -> PackedVector2Array:
	var outline := PackedVector2Array()
	for tooth in TEETH:
		var middle := tooth * TOOTH_ANGLE
		outline.append(Vector2.from_angle(middle - FLANK_START * TOOTH_ANGLE) * ROOT_RADIUS)
		outline.append(Vector2.from_angle(middle - TIP_START * TOOTH_ANGLE))
		outline.append(Vector2.from_angle(middle + TIP_START * TOOTH_ANGLE))
		outline.append(Vector2.from_angle(middle + FLANK_START * TOOTH_ANGLE) * ROOT_RADIUS)
		outline.append(Vector2.from_angle(middle + 0.5 * TOOTH_ANGLE) * ROOT_RADIUS)
	return outline
