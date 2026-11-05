class_name RunState
extends RefCounted
## Lives, cogs, score and timer for one run. Holds no references to UI: the HUD
## listens to these signals. Implements design/game-brief.md.

signal cogs_changed(cogs: int)
signal lives_changed(lives: int)
signal score_changed(score: int)
signal time_changed(seconds_left: int)
signal extra_life_gained

var cogs := 0
var lives := 0
var score := 0
var time_left := 0.0

var _starting_lives := 0
var _level_seconds := 0.0
var _cogs_per_life := 0
var _score_per_cog := 0
var _score_per_stomp := 0
var _score_per_crate := 0
var _score_per_second_left := 0
var _shown_seconds := -1


func _init(tuning: Tuning) -> void:
	_starting_lives = int(tuning.num("run", "starting_lives"))
	_level_seconds = tuning.num("run", "level_seconds")
	_cogs_per_life = int(tuning.num("run", "cogs_per_life"))
	_score_per_cog = int(tuning.num("run", "score_per_cog"))
	_score_per_stomp = int(tuning.num("run", "score_per_stomp"))
	_score_per_crate = int(tuning.num("run", "score_per_crate"))
	_score_per_second_left = int(tuning.num("run", "score_per_second_left"))
	reset()


## Starts a new run and notifies listeners of every value.
func reset() -> void:
	cogs = 0
	lives = _starting_lives
	score = 0
	time_left = _level_seconds
	_shown_seconds = -1
	cogs_changed.emit(cogs)
	lives_changed.emit(lives)
	score_changed.emit(score)
	_emit_time()


## Adds one cog and its score. Every cogs_per_life cogs grants a life.
func add_cog() -> void:
	cogs += 1
	cogs_changed.emit(cogs)
	_add_score(_score_per_cog)
	if cogs % _cogs_per_life == 0:
		add_life()


func add_stomp() -> void:
	_add_score(_score_per_stomp)


func add_crate() -> void:
	_add_score(_score_per_crate)


func add_life() -> void:
	lives += 1
	lives_changed.emit(lives)
	extra_life_gained.emit()


## Removes a life. Returns true while lives remain.
func lose_life() -> bool:
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	return lives > 0


## Restores the full timer for a new attempt after a life is lost.
func restart_timer() -> void:
	time_left = _level_seconds
	_emit_time()


## Counts down. Returns true on the tick the timer reaches zero.
func tick(delta: float) -> bool:
	if time_left <= 0.0:
		return false
	time_left = maxf(time_left - delta, 0.0)
	_emit_time()
	return time_left <= 0.0


## Converts remaining time into score at the end of the level.
func bank_time_bonus() -> void:
	_add_score(int(ceilf(time_left)) * _score_per_second_left)


func _add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func _emit_time() -> void:
	var seconds := int(ceilf(time_left))
	if seconds != _shown_seconds:
		_shown_seconds = seconds
		time_changed.emit(seconds)
