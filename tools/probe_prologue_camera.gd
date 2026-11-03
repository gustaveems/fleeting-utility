extends "res://tools/lib/verify_harness.gd"
## Playtest 2026-10-30: "two moments the camera moves at the speed of light". Plays the
## film and measures the camera's speed (m/s of film time) and turn rate (°/s), shot by
## shot; nothing may whip past what a crane or a drone could do.
## Playtest 2026-11-03: "the camera clips in and out of the train in the starting shots".
## Outside the shots that fly through his carriage on purpose, the camera never enters a
## carriage (its body plus a margin, the nose included).
##
## Run: godot --headless --path . -s tools/probe_prologue_camera.gd

const SPEED := 4.0
## Faster than this, in film time, reads as a jump (the train itself runs ~20 m/s).
const MAX_MOVE := 60.0
const MAX_TURN := 120.0
## A carriage's half extents, local (x across, y from the rail up, z along), plus margin.
const CAR_HALF := Vector3(1.6 + 0.4, 3.4 + 0.4, Prologue.CARRIAGE_LENGTH * 0.5 + 2.6)


func _scene_path() -> String:
	return "res://scenes/prologue.tscn"


func _title() -> String:
	return "PROLOGUE CAMERA PROBE"


func _run() -> void:
	var p := current_scene as Prologue
	var camera := p.find_child("FilmCamera", false, false) as Camera3D
	var shots := PrologueScript.shots()
	var peaks := {}
	var inside := {}
	var cars: Array[Node3D] = []
	for n in p.get_children():
		if str(n.name).begins_with("Carriage_"):
			cars.append(n)
	var last := camera.global_transform
	var last_shot := -1
	var last_time := 0.0
	Engine.time_scale = SPEED
	while current_scene == p and not p.is_finished:
		await process_frame
		if not is_instance_valid(p) or p.is_finished:
			break
		# Film time this frame (the engine's delta jittered against what the film moved).
		var dt := p.shot_time - last_time if p.shot_index == last_shot else 0.0
		last_time = p.shot_time
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
		var shot: Dictionary = shots[p.shot_index]
		var through: bool = (
			shot["mode"] == PrologueScript.Mode.INTERIOR or shot.get("interior", false)
		)
		# (Not while the warm-up shows each stage behind black before the film.)
		if not through and p._warmup.is_empty():
			for car in cars:
				var local := car.global_transform.affine_inverse() * xf.origin
				if (
					absf(local.x) < CAR_HALF.x
					and local.y > -0.4
					and local.y < CAR_HALF.y
					and absf(local.z) < CAR_HALF.z
				):
					inside[str(shot["name"])] = "%s at %.1f s" % [car.name, p.shot_time]
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
	check("the camera never enters the train by accident %s" % inside, inside.is_empty())
