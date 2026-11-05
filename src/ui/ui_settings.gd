class_name UiSettings
extends RefCounted
## Player interface preferences, kept between sessions. These are not game state.
##
## Usage:
##   var settings := UiSettings.load_from(UiSettings.DEFAULT_PATH)
##   settings.changed.connect(_apply_motion_setting)
##   settings.toggle_reduced_motion()

## A preference changed.
signal changed

const DEFAULT_PATH := "user://ui_settings.cfg"
const SECTION := "accessibility"
const KEY_REDUCED_MOTION := "reduced_motion"

## While true, sway, drift, ticks and motes are off.
var reduced_motion := false

var _path := ""


## Reads saved preferences. A missing or unreadable file gives the defaults.
static func load_from(path: String) -> UiSettings:
	var settings := UiSettings.new()
	settings._path = path
	var file := ConfigFile.new()
	if file.load(path) == OK:
		settings.reduced_motion = bool(file.get_value(SECTION, KEY_REDUCED_MOTION, false))
	return settings


## Flips reduced motion and saves it.
func toggle_reduced_motion() -> void:
	reduced_motion = not reduced_motion
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY_REDUCED_MOTION, reduced_motion)
	var result := file.save(_path)
	if result != OK:
		push_warning("Could not save %s: %s" % [_path, error_string(result)])
	changed.emit()
