class_name Tuning
extends RefCounted
## Read-only access to assets/data/gameplay_tuning.json.
##
## Usage:
##   var tuning := Tuning.load_from(Tuning.DEFAULT_PATH)
##   var speed := tuning.num("player", "walk_speed")

const DEFAULT_PATH := "res://assets/data/gameplay_tuning.json"

var _data: Dictionary = {}


## Loads a tuning file. Returns an empty Tuning and logs an error if it is invalid.
static func load_from(path: String) -> Tuning:
	var tuning := Tuning.new()
	tuning._data = load_json(path)
	return tuning


## Parses a JSON object from disk. Logs an error and returns {} on failure.
static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Data file is missing or empty: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Data file is not a JSON object: %s" % path)
		return {}
	return parsed


## Returns a numeric value. A missing key logs an error rather than guessing a default.
func num(section_name: String, key: String) -> float:
	var section_data: Dictionary = _data.get(section_name, {})
	if not section_data.has(key):
		push_error("Missing tuning value: %s.%s" % [section_name, key])
		return 0.0
	return float(section_data[key])
