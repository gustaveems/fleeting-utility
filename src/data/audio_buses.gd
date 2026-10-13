class_name AudioBuses
extends RefCounted
## DATA — the audio bus graph, registered at runtime (like InputActionData), so a bare
## checkout runs without a hand-edited default_bus_layout.tres.
##
##   Master ◀── Music
##          ◀── UI
##          ◀── World ◀── Ambience
##                    ◀── SFX
##
## World carries everything diegetic and holds the CRASH effects: a low-pass (index 0)
## and a distortion (index 1), both driven by AudioDirector from sensory overload. UI
## and Music bypass them, so menus and prompts stay clean while the world smears.
## Bus VOLUMES belong to the player (GameSettings, T13). Game-driven level changes use
## effects (crash low-pass/overdrive on World, the dream duck on Ambience).

const MASTER := &"Master"
const WORLD := &"World"
const AMBIENCE := &"Ambience"
const SFX := &"SFX"
const MUSIC := &"Music"
const UI := &"UI"

const WORLD_LOWPASS := 0
const WORLD_DISTORTION := 1

## Ambience effect index 0: an Amplify that AudioDirector ducks during dream fades.
## Ducking lives in an effect, not the bus volume, because the bus volume is the
## player's setting (T13).
const AMBIENCE_DUCK := 0

## Low-pass cutoff with no crash: above hearing, i.e. transparent.
const OPEN_CUTOFF_HZ := 20000.0


## Idempotent: buses that already exist (e.g. from a .tres layout) are left alone.
static func register() -> void:
	_ensure(WORLD, MASTER)
	_ensure(AMBIENCE, WORLD)
	_ensure(SFX, WORLD)
	_ensure(MUSIC, MASTER)
	_ensure(UI, MASTER)
	var world := AudioServer.get_bus_index(WORLD)
	if AudioServer.get_bus_effect_count(world) == 0:
		var lowpass := AudioEffectLowPassFilter.new()
		lowpass.cutoff_hz = OPEN_CUTOFF_HZ
		AudioServer.add_bus_effect(world, lowpass, WORLD_LOWPASS)
		var distortion := AudioEffectDistortion.new()
		distortion.mode = AudioEffectDistortion.MODE_OVERDRIVE
		distortion.drive = 0.0
		AudioServer.add_bus_effect(world, distortion, WORLD_DISTORTION)
		AudioServer.set_bus_effect_enabled(world, WORLD_DISTORTION, false)
	var ambience := AudioServer.get_bus_index(AMBIENCE)
	if AudioServer.get_bus_effect_count(ambience) == 0:
		AudioServer.add_bus_effect(ambience, AudioEffectAmplify.new(), AMBIENCE_DUCK)


static func index(bus: StringName) -> int:
	return AudioServer.get_bus_index(bus)


static func _ensure(bus: StringName, send: StringName) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, send)
