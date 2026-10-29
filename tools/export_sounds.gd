extends SceneTree
## Export the sounds made in code to tools/out/sounds/, to audition them: every cue in the
## procedural placeholder bank, the real bank's synthesised beds (the carriage, the party),
## and every voice (VoiceSynth) as heard in the game, e.g. voice_FRIEND_call.wav.
## Recordings (Kenney, Cyberwave) are files already; listen to those where they are.
##
## Run: godot --headless --path . -s tools/export_sounds.gd

const OUT_DIR := "res://tools/out/sounds/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var bank := ProceduralAudio.default_bank()
	for cue_name in bank.cues:
		_save(String(cue_name), bank.cues[cue_name].stream)
	var real := RealSounds.bank()
	for cue_name in real.cues:
		var stream: AudioStream = real.cues[cue_name].stream
		var made := (
			stream is AudioStreamWAV and (stream as AudioStreamWAV).mix_rate == VoiceSynth.MIX_RATE
		)
		if made:  # synthesised here (the recordings are files already)
			_save(String(cue_name), stream)
	for v: Array in VoiceSynth.GAME_VOICES + VoiceSynth.FILM_VOICES:
		var tag := "call" if v[1] else "room"
		_save(
			"voice_%s_%s" % [str(v[0]).replace(" ", "_").replace("+", ""), tag],
			VoiceSynth.voice(v[0], v[1])
		)
	quit()


func _save(file_name: String, stream: AudioStream) -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return
	var path := OUT_DIR + file_name + ".wav"
	var err := wav.save_to_wav(path)
	print("%s  %.2fs  err=%d" % [path, wav.get_length(), err])
