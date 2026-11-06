class_name PowerState
extends RefCounted
## Tock's form and temporary invulnerability. Implements design/game-brief.md and the form
## table in design/expansion-spec.md section 3: each hit removes the top item.
##
## States:
##   SMALL   - starting form; a hit is fatal.
##   COILED  - Coil Spring collected; a hit returns to SMALL.
##   BLASTER - coiled body plus Bolt Blaster; a hit returns to COILED. To make a hit in BLASTER
##             drop further, change the one Event.HIT cell below (the spec marks it as open).
##   BROKEN  - out of the current life; only reset() leaves it.

enum Form { SMALL, COILED, BLASTER, BROKEN }
enum Event { COIL_PICKUP, BOLT_PICKUP, HIT }
enum HitResult { IGNORED, SHRUNK, FATAL }

const TRANSITIONS := {
	Form.SMALL: { Event.COIL_PICKUP: Form.COILED, Event.BOLT_PICKUP: Form.BLASTER, Event.HIT: Form.BROKEN },
	Form.COILED: { Event.COIL_PICKUP: Form.COILED, Event.BOLT_PICKUP: Form.BLASTER, Event.HIT: Form.SMALL },
	Form.BLASTER: { Event.COIL_PICKUP: Form.BLASTER, Event.BOLT_PICKUP: Form.BLASTER, Event.HIT: Form.COILED },
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


## True in every form with the coiled body: taller jump, larger collider, breaks crates.
func has_coil_body() -> bool:
	return form == Form.COILED or form == Form.BLASTER


## Applies a Coil Spring. Returns true if the form changed.
func apply_pickup() -> bool:
	return _apply_pickup_event(Event.COIL_PICKUP)


## Applies a Bolt Blaster. Returns true if the form changed.
func apply_bolt_pickup() -> bool:
	return _apply_pickup_event(Event.BOLT_PICKUP)


## Applies a hit, honoring invulnerability.
func apply_hit() -> HitResult:
	if is_invulnerable() or form == Form.BROKEN:
		return HitResult.IGNORED
	form = TRANSITIONS[form][Event.HIT]
	if form == Form.BROKEN:
		return HitResult.FATAL
	invulnerable_left = _invulnerable_seconds
	return HitResult.SHRUNK


## Sets the form Tock enters a new level with. A broken Tock enters small.
func restore(carried: Form) -> void:
	form = Form.SMALL if carried == Form.BROKEN else carried
	invulnerable_left = 0.0


## Returns to the starting form for a new life.
func reset() -> void:
	form = Form.SMALL
	invulnerable_left = 0.0


func _apply_pickup_event(event: Event) -> bool:
	var next: Variant = TRANSITIONS[form].get(event)
	if next == null or next == form:
		return false
	form = next
	return true
