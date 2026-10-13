class_name SettingsStore
extends RefCounted
## LOGIC — player settings (volumes, accessibility, display), kept apart from the save
## game: wiping a save never resets your settings. ConfigFile at `path`.
##
## T13's settings menu reads and writes through this. Sections and keys are the menu's
## to define, e.g. ("audio", "World_db"), ("accessibility", "motion_scale").

## Tests point this elsewhere.
static var path: String = "user://settings.cfg"

var _config := ConfigFile.new()


func load() -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return _config.load(path)


func save() -> Error:
	return _config.save(path)


func get_value(section: StringName, key: StringName, default: Variant) -> Variant:
	return _config.get_value(section, key, default)


func set_value(section: StringName, key: StringName, value: Variant) -> void:
	_config.set_value(section, key, value)
