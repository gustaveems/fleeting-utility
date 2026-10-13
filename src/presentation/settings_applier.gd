class_name SettingsApplier
extends Node
## PRESENTATION — applies GameSettings to the running game, at boot and live whenever a
## setting changes (pause-menu sliders take effect immediately).
##
##   audio volumes + fullscreen  → GameSettings.apply_engine()
##   motion / distortion          → ScreenEffects accessibility scales
##   meter palette                → CoreHud

@export var screen_effects: ScreenEffects
@export var core_hud: CoreHud

var settings: GameSettings


func _ready() -> void:
	settings = GameSettings.current()
	settings.changed.connect(apply)
	apply()


func apply() -> void:
	settings.apply_engine()
	if screen_effects != null:
		screen_effects.motion_scale = settings.motion_scale
		screen_effects.distortion_scale = settings.distortion_scale
	if core_hud != null:
		core_hud.set_meter_palette(settings.meter_palette)
