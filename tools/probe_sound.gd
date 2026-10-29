extends "res://tools/lib/verify_harness.gd"
## Ticket-28 probe: Phase D's sound. The real bank (recordings where they exist, synthesis,
## the placeholders behind); a footstep per stride, by surface; under every line a voice
## in the speaker's voice, phone-band on a call that opens and closes with a tone, his
## thoughts silent; the carriage's and the rooftop's beds in their worlds; the dream's
## music, gone back in the room.
##
## Run: godot --headless --path . -s tools/probe_sound.gd

var _a: AudioDirector


func _title() -> String:
	return "SOUND PROBE"


func _run() -> void:
	_a = ws.find_child("AudioDirector", true, false) as AudioDirector
	var player := ws.find_child("Player", true, false) as PlayerMovement
	var hc := ws.find_child("HeadCall", true, false) as HeadCall
	check("the real bank", _a != null and _a.bank == RealSounds.bank())
	var steps := _a.bank.cue(SoundBank.STEP_TILE)
	var have_kenney := ResourceLoader.exists(RealSounds.KENNEY + "impact/footstep_concrete_000.ogg")
	check(
		"footsteps: several takes (Kenney)",
		not have_kenney or (steps != null and steps.stream is AudioStreamRandomizer)
	)
	check("every new cue answers", _all_cues())

	section("footsteps")
	var sm := ws.find_child("PlayerStateMachine", true, false) as PlayerStateMachine
	sm.state_data.chemical_level = 0.8
	_a.last_one_shot = &""
	player.global_position = Vector3(-1, 0, 0)
	await wait(0.2)
	for k in 12:
		player.global_position += Vector3(0.08, 0, 0)
		await process_frame
	check("a step on the tiles", _a.last_one_shot == SoundBank.STEP_TILE)
	_a.last_one_shot = &""
	player.global_position += Vector3(5.0, 0, 0)  # a teleport is not a stride
	await process_frame
	check("no step for a teleport", _a.last_one_shot == &"")

	section("voices")
	player.global_position = Vector3.ZERO  # back inside the room (the clamp would nudge him)
	await wait(0.3)
	_a.last_one_shot = &""
	hc.play([[NightZeroScript.FRIEND, "Morning, resident!", 0.6]], true)
	await process_frame
	var voice := _a.find_child("Voice", true, false) as AudioStreamPlayer
	check("a call opens with a tone", _a.last_one_shot == SoundBank.CALL_OPEN)
	check("the friend's voice, in his head (UI bus)", voice.playing and voice.bus == AudioBuses.UI)
	hc.stop()
	await process_frame
	check("and closes with one", _a.last_one_shot == SoundBank.CALL_CLOSE and not voice.playing)
	hc.play([[NightZeroScript.THOUGHT, "Smile.", 0.5]], false)
	await process_frame
	check("his thoughts are silent", not voice.playing)
	hc.stop()
	hc.play([[ActOneScript.NEIGHBOUR, "(through the wall) Hello?", 0.6]], false)
	await process_frame
	check("the neighbour, in the room (SFX bus)", voice.playing and voice.bus == AudioBuses.SFX)
	hc.stop()

	section("worlds and music")
	var metro := ws.find_child("MetroRide", true, false) as MetroRide
	metro.start_ride()
	await wait(0.3)
	check("the carriage on its rails", _a.bed_audible(SoundBank.CARRIAGE))
	metro.end_ride()
	await wait(0.3)
	check("and silent at home", not _a.bed_audible(SoundBank.CARRIAGE))
	var dm := ws.find_child("DreamscapeManager", true, false) as DreamscapeManager
	dm.transition_to_dreamscape()
	await dm.transition_completed
	var music := _a.find_child("Music", true, false) as AudioStreamPlayer
	check("the dream has its music", music.playing)
	dm.return_to_workspace()
	await dm.transition_completed
	await wait(AudioDirector.SLOW_FADE_SECONDS + 0.5)
	check("gone back in the room", not music.playing)


func _all_cues() -> bool:
	for c in [
		SoundBank.CARRIAGE,
		SoundBank.PARTY,
		SoundBank.STEP_GRASS,
		SoundBank.CALL_OPEN,
		SoundBank.CALL_CLOSE,
		SoundBank.GLASS,
		SoundBank.DOOR,
	]:
		var cue := _a.bank.cue(c)
		if cue == null or cue.stream == null:
			print("    missing cue ", c)
			return false
	return true
