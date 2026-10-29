class_name RealSounds
extends RefCounted
## PRESENTATION — the game's real sound bank (Phase D; Ticket-28). Recordings where they
## exist on disk, synthesis where it does better, the placeholder bank as the fallback:
##
##   Kenney CC0 audio (assets/third_party/kenney_audio, via the asset pipeline)
##       footsteps by surface, taps, the door, glass, the brush, UI: errors, the call's
##       line opening and closing, the morning chime
##   Cyberwave (Fab, assets/third_party/fab/cyberwave_audio; never redistributed)
##       the decay drone, the rumble, the stings, the party's music, the score
##   VoiceSynth (code)
##       the carriage on its rails, the party's murmur (and the voices: AudioDirector)
##
## Missing files fall back cue by cue to ProceduralAudio's placeholders, so the game sounds
## (simpler) without either pack.

const KENNEY := "res://assets/third_party/kenney_audio/"
const WAVE := "res://assets/third_party/fab/cyberwave_audio/Cyberwave/"

static var _bank: SoundBank


static func bank() -> SoundBank:
	if _bank != null:
		return _bank
	var b := SoundBank.new()
	b.fallback = ProceduralAudio.default_bank()
	var amb := AudioBuses.AMBIENCE
	var sfx := AudioBuses.SFX
	var ui := AudioBuses.UI
	var music := AudioBuses.MUSIC
	var cues := {
		SoundBank.STEP_TILE: [_family("impact/footstep_concrete_00%d", 5), sfx, -20.0],
		SoundBank.STEP_GRASS: [_family("impact/footstep_grass_00%d", 5), sfx, -18.0],
		SoundBank.STEP_WOOD: [_family("impact/footstep_wood_00%d", 5), sfx, -20.0],
		SoundBank.STEP_CONCRETE: [_family("impact/footstep_concrete_00%d", 5), sfx, -18.0],
		SoundBank.STEP_CARPET: [_family("impact/footstep_carpet_00%d", 5), sfx, -16.0],
		SoundBank.TAP: [_family("impact/impactGeneric_light_00%d", 5), sfx, -12.0],
		SoundBank.DENIED: [_family("interface/error_00%d", 8, 1), ui, -14.0],
		SoundBank.CALL_OPEN: [_one(KENNEY + "interface/maximize_006.ogg"), ui, -14.0],
		SoundBank.CALL_CLOSE: [_one(KENNEY + "interface/minimize_006.ogg"), ui, -16.0],
		SoundBank.CHIME: [_one(KENNEY + "interface/confirmation_002.ogg"), sfx, -14.0],
		SoundBank.GLASS: [_family("impact/impactGlass_light_00%d", 5), amb, -22.0],
		SoundBank.DOOR: [_one(KENNEY + "rpg/doorOpen_1.ogg"), sfx, -10.0],
		SoundBank.BRUSH: [_family("rpg/cloth%d", 4, 1), sfx, -18.0],
		SoundBank.DEFIB: [_one(KENNEY + "impact/impactPunch_heavy_004.ogg"), sfx, 0.0],
		SoundBank.STATUE_STING: [_one(WAVE + "FX/FX - Fx Verber Higt.wav"), sfx, -8.0],
		SoundBank.BETRAYAL_STING: [_one(WAVE + "FX/FX - Fx Verber Low.wav"), sfx, -4.0],
		SoundBank.DECAY_DRONE: [_loop(WAVE + "Sub Bass/Sub Bass - Strc Sub Dplr.wav"), amb, -14.0],
		SoundBank.RUMBLE: [_loop(WAVE + "Ambient/Ambient - Amb Sub Dplr.wav"), amb, -6.0],
		SoundBank.CARRIAGE: [VoiceSynth.carriage(), amb, -8.0],
		SoundBank.PARTY: [VoiceSynth.walla(), amb, -12.0],
		SoundBank.PARTY_MUSIC: [_loop(WAVE + "Cyber/Cyber - Cyber.wav"), amb, -20.0],
		SoundBank.MUSIC_DREAM: [_loop(WAVE + "Sound/Sound - Synth Pad.wav"), music, -16.0],
		SoundBank.MUSIC_REVEAL: [_one(WAVE + "Cinematic/Cinematic - Omegon.wav"), music, -10.0],
		SoundBank.MUSIC_END:
		[_loop(WAVE + "Sub Bass/Sub Bass - Scarlet Sub Dplr.wav"), music, -14.0],
	}
	for cue_name: StringName in cues:
		var spec: Array = cues[cue_name]
		if spec[0] != null:
			b.cues[cue_name] = SoundCue.make(spec[0], spec[1], spec[2])
	_bank = b
	return b


## A numbered family as one randomized stream (a different take each play).
static func _family(pattern: String, count: int, first: int = 0) -> AudioStream:
	var r := AudioStreamRandomizer.new()
	r.random_pitch = 1.06
	r.random_volume_offset_db = 2.0
	var n := 0
	for i in count:
		var path := KENNEY + (pattern % (first + i)) + ".ogg"
		if ResourceLoader.exists(path):
			r.add_stream(n, load(path))
			n += 1
	return r if n > 0 else null


static func _one(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null


## A long recording as a loop (a copy: the imported resource stays as it is).
static func _loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = (load(path) as AudioStream).duplicate()
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)  # frames, whatever the compression
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s
