class_name UiSettings
extends RefCounted
## Player preferences, kept between sessions. These are not game state.
## Graphics quality and fullscreen follow design/release-spec.md section 3.
##
## Usage:
##   var settings := UiSettings.load_from(UiSettings.DEFAULT_PATH, UiSettings.QUALITY_HIGH)
##   settings.changed.connect(_apply_motion_setting)
##   settings.toggle_reduced_motion()

## A preference changed.
signal changed

const DEFAULT_PATH := "user://ui_settings.cfg"
const SECTION := "accessibility"
const KEY_REDUCED_MOTION := "reduced_motion"
const GRAPHICS_SECTION := "graphics"
const KEY_QUALITY := "quality"
const KEY_FULLSCREEN := "fullscreen"
const QUALITY_LOW := "low"
const QUALITY_HIGH := "high"

## While true, sway, drift, ticks, motes, films and particle effects are off.
var reduced_motion := false
## QUALITY_LOW or QUALITY_HIGH.
var graphics_quality := QUALITY_LOW
var fullscreen := false

var _path := ""


## Reads saved preferences. A missing or unreadable file gives the defaults, with
## default_quality as the graphics quality.
static func load_from(path: String, default_quality := QUALITY_LOW) -> UiSettings:
	var settings := UiSettings.new()
	settings._path = path
	settings.graphics_quality = default_quality
	var file := ConfigFile.new()
	if file.load(path) == OK:
		settings.reduced_motion = bool(file.get_value(SECTION, KEY_REDUCED_MOTION, false))
		var quality := str(file.get_value(GRAPHICS_SECTION, KEY_QUALITY, default_quality))
		settings.graphics_quality = quality if quality in [QUALITY_LOW, QUALITY_HIGH] else default_quality
		settings.fullscreen = bool(file.get_value(GRAPHICS_SECTION, KEY_FULLSCREEN, false))
	return settings


## Flips reduced motion and saves it.
func toggle_reduced_motion() -> void:
	reduced_motion = not reduced_motion
	_save()


## Switches between low and high graphics quality and saves it.
func toggle_graphics_quality() -> void:
	graphics_quality = QUALITY_HIGH if graphics_quality == QUALITY_LOW else QUALITY_LOW
	_save()


## Flips fullscreen and saves it.
func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	_save()


func _save() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY_REDUCED_MOTION, reduced_motion)
	file.set_value(GRAPHICS_SECTION, KEY_QUALITY, graphics_quality)
	file.set_value(GRAPHICS_SECTION, KEY_FULLSCREEN, fullscreen)
	var result := file.save(_path)
	if result != OK:
		push_warning("Could not save %s: %s" % [_path, error_string(result)])
	changed.emit()
