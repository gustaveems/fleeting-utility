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
	Engine.time_scale = SPEED
	for i in shots.size():
		while p.shot_index < i and not p.is_finished:
			await process_frame
		var shot: Dictionary = shots[i]
		var gaze: Dictionary = shot.get("gaze", {})
		var at := 0.55
		if not gaze.is_empty():
			at = (float(gaze["from"]) + float(gaze["to"])) * 0.5
		var marks: Array[float] = [at]
		match str(shot["name"]):
			"curb_wait":
				marks = [0.25, 0.44, 0.8, 0.98]  # waiting, the car, the crowd sets off
			"avenue_walk":
				marks = [0.06, 0.3, 0.6, 0.67, 0.7, 0.74, 0.8]  # crowd, avenue, the fight
		for k in marks.size():
			while p.shot_index == i and p.shot_time < float(shot["dur"]) * marks[k]:
				await process_frame
			Engine.time_scale = 0.0001
			var suffix := "" if marks.size() == 1 else "_%d" % k
			await capture("prologue_%02d_%s%s.png" % [i + 1, shot["name"], suffix])
			Engine.time_scale = SPEED
	Engine.time_scale = 1.0
	p.finish()
