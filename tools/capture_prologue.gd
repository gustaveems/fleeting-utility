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
		while p.shot_index == i and p.shot_time < float(shot["dur"]) * at:
			await process_frame
		Engine.time_scale = 0.0001
		await capture("prologue_%02d_%s.png" % [i + 1, shot["name"]])
		Engine.time_scale = SPEED
	Engine.time_scale = 1.0
	p.finish()
