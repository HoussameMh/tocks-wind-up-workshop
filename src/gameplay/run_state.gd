class_name RunState
extends RefCounted
## Lives, cogs, score and timer for one run across the campaign. Holds no references to UI: the
## HUD listens to these signals. Implements design/game-brief.md and design/expansion-spec.md
## section 2, whose level-entry snapshot stops retries from farming score or cogs.

signal cogs_changed(cogs: int)
signal lives_changed(lives: int)
signal score_changed(score: int)
signal time_changed(seconds_left: int)
signal extra_life_gained

var cogs := 0
var lives := 0
var score := 0
var time_left := 0.0
## Cogs collected in the current level; cogs spans the whole run.
var level_cogs := 0
## Times a Game Over was retried this run.
var rewinds := 0

var _entry_cogs := 0
var _entry_score := 0
var _time_banked := false
var _default_seconds := 0.0
var _score_per_life_at_win := 0
var _score_no_rewind := 0
var _starting_lives := 0
var _level_seconds := 0.0
var _cogs_per_life := 0
var _score_per_cog := 0
var _score_per_stomp := 0
var _score_per_crate := 0
var _score_per_second_left := 0
var _score_spare_power := 0
var _shown_seconds := -1


func _init(tuning: Tuning) -> void:
	_starting_lives = int(tuning.num("run", "starting_lives"))
	_default_seconds = tuning.num("run", "level_seconds")
	_score_per_life_at_win = int(tuning.num("score", "per_life_at_win"))
	_score_no_rewind = int(tuning.num("score", "no_rewind"))
	_cogs_per_life = int(tuning.num("run", "cogs_per_life"))
	_score_per_cog = int(tuning.num("run", "score_per_cog"))
	_score_per_stomp = int(tuning.num("run", "score_per_stomp"))
	_score_per_crate = int(tuning.num("run", "score_per_crate"))
	_score_per_second_left = int(tuning.num("run", "score_per_second_left"))
	_score_spare_power = int(tuning.num("score", "spare_power"))
	reset()


## Starts a new run and notifies listeners of every value.
func reset() -> void:
	cogs = 0
	lives = _starting_lives
	score = 0
	rewinds = 0
	cogs_changed.emit(cogs)
	lives_changed.emit(lives)
	score_changed.emit(score)
	enter_level(_default_seconds)


## Starts a level: run totals carry over, and they become what a Game Over retry returns to.
func enter_level(seconds: float) -> void:
	_level_seconds = seconds
	level_cogs = 0
	_entry_cogs = cogs
	_entry_score = score
	_time_banked = false
	time_left = seconds
	_shown_seconds = -1
	_emit_time()


## Goes back to how the current level began, with full lives, and counts the rewind.
func rewind_to_level_entry() -> void:
	cogs = _entry_cogs
	score = _entry_score
	lives = _starting_lives
	rewinds += 1
	cogs_changed.emit(cogs)
	lives_changed.emit(lives)
	score_changed.emit(score)
	enter_level(_level_seconds)


## Pays for lives left at the end of the run, plus a bonus if no Game Over was ever retried.
func bank_victory_bonus() -> void:
	_add_score(lives * _score_per_life_at_win + (_score_no_rewind if rewinds == 0 else 0))


## Adds one cog and its score. Every cogs_per_life cogs grants a life.
func add_cog() -> void:
	cogs += 1
	level_cogs += 1
	cogs_changed.emit(cogs)
	_add_score(_score_per_cog)
	if cogs % _cogs_per_life == 0:
		add_life()


func add_stomp() -> void:
	_add_score(_score_per_stomp)


func add_crate() -> void:
	_add_score(_score_per_crate)


## Adds score an enemy reported. Enemies read their own values from tuning.
func add_score(points: int) -> void:
	_add_score(points)


## A power-up collected with nothing left to upgrade.
func add_spare_power() -> void:
	_add_score(_score_spare_power)


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
	if time_left <= 0.0 or _time_banked:
		return false
	time_left = maxf(time_left - delta, 0.0)
	_emit_time()
	return time_left <= 0.0


## Converts remaining time into score once per level, and stops the clock.
func bank_time_bonus() -> void:
	if _time_banked:
		return
	_time_banked = true
	_add_score(int(ceilf(time_left)) * _score_per_second_left)


func _add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func _emit_time() -> void:
	var seconds := int(ceilf(time_left))
	if seconds != _shown_seconds:
		_shown_seconds = seconds
		time_changed.emit(seconds)
