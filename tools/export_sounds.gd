extends SceneTree
## Export every cue in the procedural SoundBank to tools/out/sounds/<name>.wav, so the
## placeholders can be auditioned (or handed to a sound designer as a brief).
##
## Run: godot --headless --path . -s tools/export_sounds.gd

const OUT_DIR := "res://tools/out/sounds/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var bank := ProceduralAudio.default_bank()
	for cue_name in bank.cues:
		var stream := bank.cues[cue_name].stream as AudioStreamWAV
		if stream == null:
			continue
		var path := OUT_DIR + String(cue_name) + ".wav"
		var err := stream.save_to_wav(path)
		print("%s  %.2fs  err=%d" % [path, stream.get_length(), err])
	quit()
