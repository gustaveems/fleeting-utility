extends "res://tools/lib/verify_harness.gd"
## Playtest 2026-10-30: "two moments the camera moves at the speed of light". Plays the
## film and measures the camera's speed (m/s of film time) and turn rate (°/s), shot by
## shot; nothing may whip past what a crane or a drone could do.
##
## Run: godot --headless --path . -s tools/probe_prologue_camera.gd

const SPEED := 4.0
## Faster than this, in film time, reads as a jump (the train itself runs ~20 m/s).
const MAX_MOVE := 60.0
const MAX_TURN := 120.0


func _scene_path() -> String:
	return "res://scenes/prologue.tscn"


func _title() -> String:
	return "PROLOGUE CAMERA PROBE"


func _run() -> void:
	var p := current_scene as Prologue
	var camera := p.find_child("FilmCamera", false, false) as Camera3D
	var shots := PrologueScript.shots()
	var peaks := {}
	var last := camera.global_transform
	var last_shot := -1
	Engine.time_scale = SPEED
	while current_scene == p and not p.is_finished:
		await process_frame
		if not is_instance_valid(p) or p.is_finished:
			break
		var dt := p.get_process_delta_time()
		var xf := camera.global_transform
		var cut: bool = (
			p.shot_index != last_shot
			and (p.shot_index == 0 or bool(shots[p.shot_index].get("cut", false)))
		)
		if dt > 0.0 and not cut and last_shot >= 0:
			var move := xf.origin.distance_to(last.origin) / dt
			var dot := clampf(xf.basis.z.normalized().dot(last.basis.z.normalized()), -1.0, 1.0)
			var turn := rad_to_deg(acos(dot)) / dt
			var name := str(shots[p.shot_index]["name"])
			var peak: Array = peaks.get(name, [0.0, 0.0, 0.0])
			if move > peak[0]:
				peak[0] = move
				peak[2] = p.shot_time
			peak[1] = maxf(peak[1], turn)
			peaks[name] = peak
		last = xf
		last_shot = p.shot_index
	Engine.time_scale = 1.0
	for s in shots:
		var name := str(s["name"])
		var peak: Array = peaks.get(name, [0.0, 0.0, 0.0])
		check(
			"%s: %.0f m/s (at %.1f s), %.0f °/s" % [name, peak[0], peak[2], peak[1]],
			peak[0] <= MAX_MOVE and peak[1] <= MAX_TURN
		)
