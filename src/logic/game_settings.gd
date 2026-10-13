class_name GameSettings
extends RefCounted
## LOGIC — the player's settings as typed values, persisted through SettingsStore.
##
## One shared instance per run (GameSettings.current()). The project deliberately has no
## autoloads, and settings outlive any one scene: the menu edits them, the game applies
## them. Anything that applies settings listens to `changed`.
##
##   audio          master / ambience / sfx / ui volume, linear 0..1 (bus dB derived)
##   accessibility  motion (tremor + shake) 0..1, distortion (CA + blur) 0..1,
##                  meter palette (DEFAULT, COLORBLIND, HIGH_CONTRAST)
##   display        fullscreen

signal changed

enum MeterPalette { DEFAULT, COLORBLIND, HIGH_CONTRAST }

## Buses with a volume slider, in menu order.
const VOLUME_BUSES: Array[StringName] = [
	AudioBuses.MASTER, AudioBuses.AMBIENCE, AudioBuses.SFX, AudioBuses.UI
]

static var _current: GameSettings

var volumes: Dictionary[StringName, float] = {}
var motion_scale: float = 1.0
var distortion_scale: float = 1.0
var meter_palette: MeterPalette = MeterPalette.DEFAULT
var fullscreen: bool = false

var _store := SettingsStore.new()


func _init() -> void:
	for bus in VOLUME_BUSES:
		volumes[bus] = 1.0


## The shared instance, loaded from disk on first use.
static func current() -> GameSettings:
	if _current == null:
		_current = GameSettings.new()
		_current.load_from_disk()
	return _current


## Forget the shared instance (tests, after pointing SettingsStore.path elsewhere).
static func reset_current() -> void:
	_current = null


func load_from_disk() -> void:
	if _store.load() != OK:
		return
	for bus in VOLUME_BUSES:
		volumes[bus] = clampf(float(_store.get_value(&"audio", bus, 1.0)), 0.0, 1.0)
	motion_scale = clampf(float(_store.get_value(&"accessibility", &"motion", 1.0)), 0.0, 1.0)
	distortion_scale = clampf(
		float(_store.get_value(&"accessibility", &"distortion", 1.0)), 0.0, 1.0
	)
	var palette := int(_store.get_value(&"accessibility", &"meter_palette", 0))
	meter_palette = clampi(palette, 0, MeterPalette.size() - 1) as MeterPalette
	fullscreen = bool(_store.get_value(&"display", &"fullscreen", false))


func save_to_disk() -> Error:
	for bus in VOLUME_BUSES:
		_store.set_value(&"audio", bus, volumes[bus])
	_store.set_value(&"accessibility", &"motion", motion_scale)
	_store.set_value(&"accessibility", &"distortion", distortion_scale)
	_store.set_value(&"accessibility", &"meter_palette", int(meter_palette))
	_store.set_value(&"display", &"fullscreen", fullscreen)
	return _store.save()


## Set one value, persist, and announce. The single write path for every control.
func set_volume(bus: StringName, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	_commit()


func set_motion_scale(value: float) -> void:
	motion_scale = clampf(value, 0.0, 1.0)
	_commit()


func set_distortion_scale(value: float) -> void:
	distortion_scale = clampf(value, 0.0, 1.0)
	_commit()


func set_meter_palette(value: MeterPalette) -> void:
	meter_palette = value
	_commit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_commit()


## Push the audio and display settings into the engine. Game-side consumers (post-FX,
## HUD) are applied by SettingsApplier.
func apply_engine() -> void:
	for bus in VOLUME_BUSES:
		var idx := AudioServer.get_bus_index(bus)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volumes[bus], 0.0001)))
			AudioServer.set_bus_mute(idx, volumes[bus] <= 0.001)
	if DisplayServer.get_name() != "headless":
		# Only toggle across the fullscreen boundary: never un-maximize a window the
		# player maximized themselves.
		var mode := DisplayServer.window_get_mode()
		var is_full := (
			mode == DisplayServer.WINDOW_MODE_FULLSCREEN
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		)
		if fullscreen and not is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fullscreen and is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _commit() -> void:
	save_to_disk()
	apply_engine()
	changed.emit()
