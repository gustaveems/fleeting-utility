extends "res://tools/lib/verify_harness.gd"
## Windowed: one frame from the middle of each prologue shot → tools/out/prologue_NN.png
## (plus a frame at each gaze moment's peak). For reviewing the previs.
## Run: godot --path . -s tools/capture_prologue.gd

const SPEED := 4.0


func _scene_path() -> String:
	return "res://scenes/prologue.tscn"


func _title() -> String:
	return "CAPTURE PROLOGUE"


func _run() -> void:
	var p := current_scene as Prologue
	var shots := PrologueScript.shots()
	# macOS stops drawing a covered window, freezing the captures: keep it on top.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	# `-- from=N` starts at shot N (a short run is less likely to be paused by the OS).
	var first := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("from="):
			first = int(arg.substr(5))
	if first > 0:
		p._start_shot(first)
	Engine.time_scale = SPEED
	for i in range(first, shots.size()):
		while p.shot_index < i and not p.is_finished:
			await process_frame
		var shot: Dictionary = shots[i]
		# Shots glide, so catch each one early (mid-glide), middle and late.
		var marks: Array[float] = [0.15, 0.55, 0.92]
		match str(shot["name"]):
			"curb_wait":
				marks = [0.25, 0.44, 0.8, 0.98]  # waiting, the car, the crowd sets off
			"corner_walk":
				marks = [0.05, 0.2, 0.3, 0.4, 0.6]  # back behind him, the fight, the turn
			"his_door":
				marks = [0.55]
		for k in marks.size():
			while p.shot_index == i and p.shot_time < float(shot["dur"]) * marks[k]:
				await process_frame
			Engine.time_scale = 0.0001
			var suffix := "" if marks.size() == 1 else "_%d" % k
			await capture("prologue_%02d_%s%s.png" % [i + 1, shot["name"], suffix])
			Engine.time_scale = SPEED
	Engine.time_scale = 1.0
	p.finish()
