class_name Progress
extends RefCounted
## What a player has achieved, kept between sessions: unlocked levels, best times, golden gears
## found and the best full-run score. Implements design/release-spec.md sections 3 and 4.
##
## Usage:
##   var progress := Progress.load_from(Progress.DEFAULT_PATH, campaign_size)
##   var result := progress.record_clear(level_index, elapsed_seconds, gears_found)
##   if result.new_best_time: ...
##
## An empty path keeps everything in memory, which tests and tools use so they never touch a
## player's save.

## Something was recorded.
signal changed

const DEFAULT_PATH := "user://progress.cfg"
const SECTION := "progress"
const LEVEL_SECTION := "level_%d"
## No best time yet.
const NO_TIME := -1.0


## What one cleared level changed, for the clear screen.
class ClearResult:
	extends RefCounted
	var new_best_time := false
	var best_time := NO_TIME
	## Gears found on this level across every clear, including this one.
	var gears_found := 0


var campaign_won := false
var best_run_score := 0

var _path := ""
var _campaign_size := 1
var _unlocked := 1
## Level index -> best time in seconds.
var _best_times: Dictionary = {}
## Level index -> Array[int] of golden gear indices found.
var _gears: Dictionary = {}


## Reads saved progress. A missing or unreadable file gives a new player.
static func load_from(path: String, campaign_size: int) -> Progress:
	var progress := Progress.new()
	progress._path = path
	progress._campaign_size = maxi(campaign_size, 1)
	if path.is_empty():
		return progress
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return progress
	progress._unlocked = clampi(int(file.get_value(SECTION, "unlocked", 1)), 1, progress._campaign_size)
	progress.campaign_won = bool(file.get_value(SECTION, "campaign_won", false))
	progress.best_run_score = maxi(int(file.get_value(SECTION, "best_run_score", 0)), 0)
	for index in progress._campaign_size:
		var section := LEVEL_SECTION % index
		var time := float(file.get_value(section, "best_time", NO_TIME))
		if time > 0.0:
			progress._best_times[index] = time
		var found: Array[int] = []
		for value: Variant in file.get_value(section, "gears", []):
			if (value is int or value is float) and int(value) >= 0 and not found.has(int(value)):
				found.append(int(value))
		if not found.is_empty():
			progress._gears[index] = found
	return progress


## Number of levels open in the level select, from 1.
func unlocked_count() -> int:
	return _unlocked


## True when level index (from 0) can be chosen.
func is_unlocked(index: int) -> bool:
	return index >= 0 and index < _unlocked


## Best time for a level in seconds, or NO_TIME.
func best_time(index: int) -> float:
	return float(_best_times.get(index, NO_TIME))


## Indices of the golden gears found on a level.
func gears_found(index: int) -> Array[int]:
	var found: Array[int] = []
	found.assign(_gears.get(index, []))
	return found


## Total golden gears found across the campaign.
func total_gears_found() -> int:
	var total := 0
	for found: Array in _gears.values():
		total += found.size()
	return total


## Records a cleared level: opens the next, keeps the better time and banks the gears.
func record_clear(index: int, elapsed: float, gears: Array[int]) -> ClearResult:
	var result := ClearResult.new()
	if index < 0 or index >= _campaign_size:
		return result
	_unlocked = maxi(_unlocked, mini(index + 2, _campaign_size))
	var previous := best_time(index)
	if elapsed > 0.0 and (previous < 0.0 or elapsed < previous):
		_best_times[index] = elapsed
		result.new_best_time = true
	result.best_time = best_time(index)
	var found := gears_found(index)
	for gear in gears:
		if gear >= 0 and not found.has(gear):
			found.append(gear)
	found.sort()
	if not found.is_empty():
		_gears[index] = found
	result.gears_found = found.size()
	_save()
	return result


## Records a won campaign. A run that started on level 1 can set the best run score.
## Returns true when the score is a new best.
func record_victory(score: int, started_on_first_level: bool) -> bool:
	campaign_won = true
	var new_best := started_on_first_level and score > best_run_score
	if new_best:
		best_run_score = score
	_save()
	return new_best


func _save() -> void:
	changed.emit()
	if _path.is_empty():
		return
	var file := ConfigFile.new()
	file.set_value(SECTION, "unlocked", _unlocked)
	file.set_value(SECTION, "campaign_won", campaign_won)
	file.set_value(SECTION, "best_run_score", best_run_score)
	for index in _campaign_size:
		var section := LEVEL_SECTION % index
		if _best_times.has(index):
			file.set_value(section, "best_time", _best_times[index])
		if _gears.has(index):
			file.set_value(section, "gears", _gears[index])
	var result := file.save(_path)
	if result != OK:
		push_warning("Could not save %s: %s" % [_path, error_string(result)])
