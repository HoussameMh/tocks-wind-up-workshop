class_name PowerState
extends RefCounted
## Tock's form and temporary invulnerability. Implements design/game-brief.md.
##
## States:
##   SMALL  - starting form; a hit is fatal.
##   COILED - Coil Spring collected; a hit returns to SMALL.
##   BROKEN - out of the current life; only reset() leaves it.

enum Form { SMALL, COILED, BROKEN }
enum Event { PICKUP, HIT }
enum HitResult { IGNORED, SHRUNK, FATAL }

const TRANSITIONS := {
	Form.SMALL: { Event.PICKUP: Form.COILED, Event.HIT: Form.BROKEN },
	Form.COILED: { Event.PICKUP: Form.COILED, Event.HIT: Form.SMALL },
	Form.BROKEN: {},
}

var form: Form = Form.SMALL
var invulnerable_left := 0.0

var _invulnerable_seconds := 0.0


func _init(invulnerable_seconds: float) -> void:
	_invulnerable_seconds = invulnerable_seconds


## Advances the invulnerability timer.
func tick(delta: float) -> void:
	invulnerable_left = maxf(invulnerable_left - delta, 0.0)


func is_invulnerable() -> bool:
	return invulnerable_left > 0.0


## Applies a Coil Spring. Returns true if the form changed.
func apply_pickup() -> bool:
	var next: Variant = TRANSITIONS[form].get(Event.PICKUP)
	if next == null or next == form:
		return false
	form = next
	return true


## Applies a hit, honoring invulnerability.
func apply_hit() -> HitResult:
	if is_invulnerable() or form == Form.BROKEN:
		return HitResult.IGNORED
	form = TRANSITIONS[form][Event.HIT]
	if form == Form.BROKEN:
		return HitResult.FATAL
	invulnerable_left = _invulnerable_seconds
	return HitResult.SHRUNK


## Returns to the starting form for a new life.
func reset() -> void:
	form = Form.SMALL
	invulnerable_left = 0.0
