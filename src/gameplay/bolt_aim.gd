class_name BoltAim
extends RefCounted
## The rule that picks what a bolt flies at: you face it, and height is handled for you.
## Pure math, so it can be tested without a scene. Implements design/expansion-spec.md section 3.

## Returned by score() for anything the rules do not allow.
const OUT_OF_CONE := -1.0

var range_max := 0.0
var yaw_max_degrees := 0.0
var dy_min := 0.0
var dy_max := 0.0


func _init(tuning: Tuning) -> void:
	range_max = tuning.num("blaster", "aim_range")
	yaw_max_degrees = tuning.num("blaster", "aim_yaw_degrees")
	dy_min = tuning.num("blaster", "aim_dy_min")
	dy_max = tuning.num("blaster", "aim_dy_max")


## Lower is better, OUT_OF_CONE if not allowed. Distance and yaw are horizontal only, and
## height difference is measured from Tock's feet. score_scale is below 1 for favored targets.
func score(feet: Vector3, direction: Vector3, point: Vector3, score_scale := 1.0) -> float:
	var dy := point.y - feet.y
	if dy < dy_min or dy > dy_max:
		return OUT_OF_CONE
	var flat := Vector2(point.x - feet.x, point.z - feet.z)
	var distance := flat.length()
	if distance > range_max:
		return OUT_OF_CONE
	var yaw_degrees := 0.0
	if distance > 0.0:
		yaw_degrees = absf(rad_to_deg(Vector2(direction.x, direction.z).angle_to(flat)))
	if yaw_degrees > yaw_max_degrees:
		return OUT_OF_CONE
	return (yaw_degrees / yaw_max_degrees + distance / range_max) * score_scale
