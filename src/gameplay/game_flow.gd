class_name GameFlow
extends RefCounted
## Top-level game states. Requests not listed in TRANSITIONS are refused.

signal state_changed(state: State, previous: State)

enum State { TITLE, PLAYING, PAUSED, LIFE_LOST, LEVEL_CLEAR, GAME_OVER }
enum Trigger { START, PAUSE, RESUME, QUIT, DIE, RESPAWN, OUT_OF_LIVES, CLEAR }

const TRANSITIONS := {
	State.TITLE: { Trigger.START: State.PLAYING },
	State.PLAYING: {
		Trigger.PAUSE: State.PAUSED,
		Trigger.DIE: State.LIFE_LOST,
		Trigger.CLEAR: State.LEVEL_CLEAR,
	},
	State.PAUSED: {
		Trigger.RESUME: State.PLAYING,
		Trigger.START: State.PLAYING,
		Trigger.QUIT: State.TITLE,
	},
	State.LIFE_LOST: {
		Trigger.RESPAWN: State.PLAYING,
		Trigger.OUT_OF_LIVES: State.GAME_OVER,
	},
	State.LEVEL_CLEAR: { Trigger.START: State.PLAYING, Trigger.QUIT: State.TITLE },
	State.GAME_OVER: { Trigger.START: State.PLAYING, Trigger.QUIT: State.TITLE },
}

var state: State = State.TITLE


## Attempts a transition. Returns false, with no change, if it is not allowed.
func fire(trigger: Trigger) -> bool:
	var allowed: Dictionary = TRANSITIONS[state]
	if not allowed.has(trigger):
		return false
	var previous := state
	state = allowed[trigger]
	state_changed.emit(state, previous)
	return true
