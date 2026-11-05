class_name JumpAssist
extends RefCounted
## Forgiving jump timing: coyote time after leaving a ledge, and a buffer for
## pressing jump just before landing.

var _coyote_seconds := 0.0
var _buffer_seconds := 0.0
var _coyote_left := 0.0
var _buffer_left := 0.0


func _init(coyote_seconds: float, buffer_seconds: float) -> void:
	_coyote_seconds = coyote_seconds
	_buffer_seconds = buffer_seconds


## Call once per physics tick.
func tick(delta: float, on_floor: bool) -> void:
	_coyote_left = _coyote_seconds if on_floor else maxf(_coyote_left - delta, 0.0)
	_buffer_left = maxf(_buffer_left - delta, 0.0)


## Records a jump press.
func press() -> void:
	_buffer_left = _buffer_seconds


## Returns true once when a buffered press can become a jump, then clears both timers.
func consume_jump() -> bool:
	if _buffer_left <= 0.0 or _coyote_left <= 0.0:
		return false
	_buffer_left = 0.0
	_coyote_left = 0.0
	return true


## Clears coyote time, for example when launched off the ground by another force.
func cancel_coyote() -> void:
	_coyote_left = 0.0


## Launch speed needed to reach a height under constant gravity.
static func launch_speed(height: float, gravity: float) -> float:
	return sqrt(2.0 * gravity * height)
