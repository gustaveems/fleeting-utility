extends "res://tools/lib/verify_harness.gd"
## Windowed frames of Night Zero's evening, one per segment → tools/out/evening_*.png.
##
## Run: godot --path . -s tools/capture_evening.gd


func _scene_path() -> String:
	return "res://scenes/evening.tscn"


func _title() -> String:
	return "CAPTURE EVENING"


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var e := current_scene as Evening
	await wait(4.0)
	await capture("evening_1_car.png")
	e.skip_film()
	await wait(1.5)
	await capture("evening_2_dinner.png")
	Engine.time_scale = 10.0
	while e.segment in ["dinner", "gift"]:
		if e.runner.awaiting_choice:
			if e.segment == "gift":
				Engine.time_scale = 1.0
				await wait(0.3)
				await capture("evening_3_gift.png")
				Engine.time_scale = 10.0
			e.runner.choices_ui.choose(0)
		await process_frame
	Engine.time_scale = 1.0
	await wait(0.5)
	await capture("evening_4_walk_start.png")
	e.player.global_position = e.layout.world(Vector3(-4, 0, 30))
	await wait(1.0)
	await capture("evening_5_shoot.png")
	e.player.global_position = e.layout.world(Vector3(6, 0, -2))
	await wait(1.0)
	await capture("evening_6_window.png")
	e.player.global_position = e.layout.world(EveningLayout.BEATS["station"])
	await wait(2.0)
	await capture("evening_7_metro.png")
