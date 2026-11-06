class_name BossRules
extends RefCounted
## Baron Rust's health, phases and weak-spot accounting, with no scene behind it so every number
## can be unit tested. Implements design/expansion-spec.md section 6.
##
## One window takes at most window_cap damage, and damage stops at each phase boundary. So a stomp
## (3) and three bolts (1 each) cost the Baron the same, and six clean windows win either way.

## Health a phase ends at. The fight has exactly these three phases.
const PHASE_FLOORS: Array[float] = [2.0 / 3.0, 1.0 / 3.0, 0.0]

var hp := 0
var max_hp := 0
var window_damage := 0

var _window_cap := 0


func _init(start_hp: int, cap: int) -> void:
	max_hp = start_hp
	hp = start_hp
	_window_cap = cap


## The current phase, from 0.
func phase() -> int:
	for i in PHASE_FLOORS.size():
		if hp > floor_of_phase(i):
			return i
	return PHASE_FLOORS.size() - 1


## Health at which a phase ends.
func floor_of_phase(index: int) -> int:
	return roundi(max_hp * PHASE_FLOORS[index])


## Health a phase starts at, which a retry returns to.
func start_of_phase(index: int) -> int:
	return max_hp if index == 0 else floor_of_phase(index - 1)


## Opens a new weak-spot window.
func open_window() -> void:
	window_damage = 0


## Applies damage within the window cap and the phase boundary. Returns the damage dealt.
func hit(damage: int) -> int:
	var dealt := mini(damage, _window_cap - window_damage)
	dealt = maxi(mini(dealt, hp - floor_of_phase(phase())), 0)
	hp -= dealt
	window_damage += dealt
	return dealt


## True once this window has given all it can.
func window_spent() -> bool:
	return window_damage >= _window_cap


## True when health stands exactly on a phase boundary, so the phase is over.
func at_phase_boundary() -> bool:
	for i in PHASE_FLOORS.size():
		if hp == floor_of_phase(i) and hp < max_hp:
			return true
	return false


## Puts health back to the start of the phase in progress.
func restart_phase(index: int) -> void:
	hp = start_of_phase(index)
	window_damage = 0


func is_defeated() -> bool:
	return hp <= 0
