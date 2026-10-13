extends "res://tools/lib/verify_harness.gd"
## Ticket-10 audio probe: the bus graph, the per-phase soundscape, world-paused beds,
## the body's rhythms, the crash filter, the ambulance siren and the stings.
##
## Headless uses the Dummy audio driver, which still advances playback, so `playing`
## and pause state are meaningful here (verified 4.7.2).
##
## Run: godot --headless --path . -s tools/probe_audio.gd

var _audio: AudioDirector
var _beats := 0


func _title() -> String:
	return "AUDIO PROBE"


func _run() -> void:
	_audio = node("AudioDirector") as AudioDirector
	var sm := node("PlayerStateMachine") as PlayerStateMachine
	var dm := node("DreamscapeManager") as DreamscapeManager
	var park := node("CorporateParkManager") as CorporateParkManager
	var hesitation := node("HesitationController") as HesitationController
	var visions := node("DualVisionController") as DualVisionController
	var ambulance := node("AmbulanceInterception") as AmbulanceInterception
	var endgame := node("EndgameLoopManager") as EndgameLoopManager
	var soothing := node("SelfSoothingController") as SelfSoothingController
	var trivial := node("Apartment/TrivialObject") as TrivialObject
	check("AudioDirector present", _audio != null)
	if _audio == null:
		return
	_audio.heart().beat.connect(func(_i: int): _beats += 1)

	section("bus graph")
	for bus in [AudioBuses.WORLD, AudioBuses.AMBIENCE, AudioBuses.SFX, AudioBuses.UI]:
		check("bus %s exists" % bus, AudioBuses.index(bus) != -1)
	check("Ambience -> World", _send(AudioBuses.AMBIENCE) == AudioBuses.WORLD)
	check("SFX -> World", _send(AudioBuses.SFX) == AudioBuses.WORLD)
	check("UI bypasses World", _send(AudioBuses.UI) == AudioBuses.MASTER)
	var world := AudioBuses.index(AudioBuses.WORLD)
	check_property_exists(AudioServer.get_bus_effect(world, 0), &"cutoff_hz")
	check_property_exists(AudioServer.get_bus_effect(world, 1), &"drive")

	section("workspace soundscape")
	sm.state_data.chemical_level = 0.6
	sm.state_data.sensory_overload = 0.0
	await wait(0.2)
	check("room tone audible", _audio.bed_audible(SoundBank.ROOM_TONE))
	check("no clinical hum", not _audio.bed_audible(SoundBank.FLUORESCENT_HUM))
	check("valley paused while its world is inactive", not _audio.bed_audible(SoundBank.VALLEY_AIR))
	check("park paused while its world is inactive", not _audio.bed_audible(SoundBank.PARK_AIR))

	section("crash muffles the world, not the UI")
	var lowpass := AudioServer.get_bus_effect(world, 0) as AudioEffectLowPassFilter
	var open_cutoff := lowpass.cutoff_hz
	sm.state_data.chemical_level = 0.6
	sm.state_data.sensory_overload = 100.0
	await wait(1.0)
	check(
		"low-pass closed under crash (%.0f -> %.0f Hz)" % [open_cutoff, lowpass.cutoff_hz],
		lowpass.cutoff_hz < open_cutoff * 0.2
	)
	sm.state_data.sensory_overload = 0.0
	await wait(1.5)
	check("low-pass reopens (%.0f Hz)" % lowpass.cutoff_hz, lowpass.cutoff_hz > 10000.0)

	section("compulsion pulse and taps")
	soothing._enter_compulsion()
	_beats = 0
	# Chemical just above 0: at 0 the meter floods to 100 and a real collapse dream
	# would start mid-test.
	sm.state_data.chemical_level = 0.05
	sm.state_data.sensory_overload = 98.0
	await wait(1.0)
	check("pulse beating during compulsion (%d beats)" % _beats, _beats >= 2)
	check("tempo tracks overload (%.0f bpm)" % _audio.heart().bpm, _audio.heart().bpm > 140.0)
	trivial.soothe(1.0)
	check("a soothe taps", _audio.last_one_shot == SoundBank.TAP)
	soothing._exit_compulsion()
	sm.state_data.chemical_level = 0.6
	sm.state_data.sensory_overload = 0.0
	check("pulse stops with the compulsion", not _audio.heart().is_running)

	section("dream: the apartment falls silent, the valley speaks")
	ambulance.interception_delay = 1.0
	ambulance.escalation_seconds = 1.0
	endgame.clinical_pause_seconds = 0.5
	dm.auto_return_seconds = 999.0
	await dm.transition_to_dreamscape()
	await wait(0.2)
	check("valley air audible", _audio.bed_audible(SoundBank.VALLEY_AIR))
	check("room tone paused", not _audio.bed_audible(SoundBank.ROOM_TONE))
	check("dream is serene: low-pass open", lowpass.cutoff_hz > 10000.0)
	await dm.return_to_workspace()
	await wait(0.2)
	check("room tone back", _audio.bed_audible(SoundBank.ROOM_TONE))
	check("valley paused again", not _audio.bed_audible(SoundBank.VALLEY_AIR))
	var ambience := AudioBuses.index(AudioBuses.AMBIENCE)
	var duck := AudioServer.get_bus_effect(ambience, AudioBuses.AMBIENCE_DUCK) as AudioEffectAmplify
	check("ambience un-ducked", duck.volume_db > -1.0)
	check(
		"player's bus volume untouched by the duck",
		is_zero_approx(AudioServer.get_bus_volume_db(ambience))
	)

	section("walk and ransack")
	park.transition_to_park()
	await wait(0.1)
	check("park air audible on the walk", _audio.bed_audible(SoundBank.PARK_AIR))
	park.transition_to_apartment()
	await wait(2.0)
	check("cold draft in the ransacked room", _audio.bed_audible(SoundBank.COLD_DRAFT))
	var shoes := node("Apartment/LuxuryShoes") as LuxuryShoes
	(shoes.get_node("ProximityArea") as Interactable).try_interact()
	check("betrayal sting", _audio.last_one_shot == SoundBank.BETRAYAL_STING)

	section("hesitation: rumble and a climbing heartbeat")
	_beats = 0
	hesitation.initiate_hesitation()
	await wait(0.5)
	check("rumble audible", _audio.bed_audible(SoundBank.RUMBLE))
	var bpm_early := _audio.heart().bpm
	await wait(3.0)
	check(
		"heartbeat climbs (%.0f -> %.0f bpm)" % [bpm_early, _audio.heart().bpm],
		_audio.heart().bpm > bpm_early + 10.0
	)
	await visions.visions_ended
	await wait(0.5)
	check("heartbeat stops after the visions", not _audio.heart().is_running)
	check("rumble gone after the visions", _audio.bed_level(SoundBank.RUMBLE) == 0.0)
	(
		(node("DreamscapeValley/Statue_0/StatueNarrative_0") as StatueNarrative)
		. statue_truth_revealed
		. emit("x")
	)
	check("statue sting", _audio.last_one_shot == SoundBank.STATUE_STING)

	section("climax: siren, jolt, clinical hum hard cut")
	sm.state_data.chemical_level = 0.0
	sm.state_data.sensory_overload = 0.0
	await wait(0.1)
	sm.state_data.sensory_overload = 100.0
	await dm.transition_completed
	await ambulance.interception_started
	await wait(0.1)
	check("siren sounding during the interception", _audio.siren_playing())
	await dm.forced_return_completed
	check("siren cut at the jolt", not _audio.siren_playing())
	check("defib hit", _audio.last_one_shot == SoundBank.DEFIB)
	check("clinical hum on at once", _audio.bed_audible(SoundBank.FLUORESCENT_HUM))
	check("room tone cut", not _audio.bed_audible(SoundBank.ROOM_TONE))
	await endgame.loop_reset
	check("lease chime on the loop reset", _audio.last_one_shot == SoundBank.CHIME)


func _send(bus: StringName) -> StringName:
	return AudioServer.get_bus_send(AudioBuses.index(bus))
