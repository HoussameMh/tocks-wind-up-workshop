class_name BossGauge
extends Control
## Baron Rust's health as pips in groups, one group per fight phase, so a player can see at a
## glance how close the next phase is. Filled against hollow, so color is never the only cue.
##
## Usage:
##   gauge.set_health(13, 18)

const PIP_SIZE := Vector2(12.0, 22.0)
const PIP_GAP := 3.0
const GROUP_GAP := 12.0
const PIPS_PER_GROUP := 6
const OUTLINE_WIDTH := 2.0
const FILLED := Color("ff7a1a")
const OUTLINE := Color("f4e8cf")

## Filled pips.
var hp := 0

var _max_hp := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Sets filled and total pips.
func set_health(value: int, max_value: int) -> void:
	hp = clampi(value, 0, max_value)
	_max_hp = max_value
	var groups := maxi(ceili(float(_max_hp) / PIPS_PER_GROUP), 1)
	var width := _max_hp * (PIP_SIZE.x + PIP_GAP) + (groups - 1) * GROUP_GAP
	custom_minimum_size = Vector2(width, PIP_SIZE.y)
	queue_redraw()


func _draw() -> void:
	var x := 0.0
	for i in _max_hp:
		if i > 0 and i % PIPS_PER_GROUP == 0:
			x += GROUP_GAP
		var pip := Rect2(Vector2(x, 0.0), PIP_SIZE)
		if i < hp:
			draw_rect(pip, FILLED)
		draw_rect(pip, OUTLINE, false, OUTLINE_WIDTH)
		x += PIP_SIZE.x + PIP_GAP
