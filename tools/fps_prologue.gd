extends "res://tools/lib/verify_harness.gd"
## Windowed frame-rate probe for the prologue: plays it at real speed (optionally from shot
## N: `-- from=N`) and logs the average and worst FPS per shot.
##
## Run: godot --path . -s tools/fps_prologue.gd -- from=0


func _scene_path() -> String:
	return "res://scenes/prologue.tscn"


func _title() -> String:
	return "PROLOGUE FPS"


func _run() -> void:
	var p := current_scene as Prologue
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var first := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("from="):
			first = int(arg.substr(5))
	if first > 0:
		p._start_shot(first)
	var shot := p.shot_index
	var frames := 0
	var time := 0.0
	var worst := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	while current_scene == p and not p.is_finished:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1e6
		last = now
		frames += 1
		time += dt
		worst = maxf(worst, dt)
		if p.shot_index != shot:
			print(
				(
					"FPS %-18s avg %5.1f  worst frame %5.0f ms"
					% [
						PrologueScript.shots()[shot]["name"],
						frames / maxf(time, 0.001),
						worst * 1000.0
					]
				)
			)
			shot = p.shot_index
			frames = 0
			time = 0.0
			worst = 0.0
	check("the film finished", true)
