extends "res://tools/lib/verify_harness.gd"
## Ticket-16 Phase 2 probe: Night Zero's evening, played through. The car film, the
## dinner's choices (all honest: the verdict leans honest), the gift refused, the walk
## (a beat's thought, then the station), the metro, and home: the workspace with the
## moved-in boxes and the gift in his bag. Runs dialogue at 10x.
##
## Run: godot --headless --path . -s tools/probe_evening.gd

const SPEED := 10.0
## The choices to make, in order: work, home, shoes (honest), ride (walk), gift (refuse).
const PICKS: Array[int] = [0, 0, 0, 0, 1]


func _scene_path() -> String:
	return "res://scenes/evening.tscn"


func _title() -> String:
	return "EVENING PROBE"


func _run() -> void:
	var e := current_scene as Evening
	check("the evening boots", e != null)
	if e == null:
		return
	var seen: Array[String] = [e.segment]
	e.segment_started.connect(func(s: String): seen.append(s))
	await wait(0.2)
	check("it opens on the car", e.segment == "car")
	check("he is a passenger (no control)", e.player.input_locked)
	e.skip_film()
	await wait(0.3)
	check("then dinner", e.segment == "dinner")

	section("dinner and the gift")
	Engine.time_scale = SPEED
	var picks := 0
	while e.segment in ["dinner", "gift"] and picks <= PICKS.size():
		if e.runner.awaiting_choice and picks < PICKS.size():
			e.runner.choices_ui.choose(PICKS[picks])
			picks += 1
		await process_frame
	Engine.time_scale = 1.0
	check("five choices were offered (%d)" % picks, picks == PICKS.size())
	check(
		"the night leaned honest (%d vs %d)" % [e.runner.honest, e.runner.fit],
		e.runner.honest > e.runner.fit
	)
	check("he refused the gift", Evening.gift_refused)
	check("the friend has gone", e.friend == null)

	section("the walk")
	await wait(0.2)
	check("now he walks", e.segment == "walk" and not e.player.input_locked)
	e.player.global_position = e.layout.world(EveningLayout.BEATS["shoot"])
	await wait(0.4)
	check("passing the shoot, he thinks", e.runner.is_running)
	e.player.global_position = e.layout.world(EveningLayout.BEATS["station"])
	await wait(0.4)
	check("the station ends the walk", e.segment == "metro")
	e.skip_film()
	await _wait_for("Workspace")
	check("the evening order", seen == ["car", "dinner", "gift", "walk", "metro", "home"])

	section("home")
	var ws_scene := current_scene
	check("home: the game", ws_scene != null and ws_scene.name == "Workspace")
	var nz := ws_scene.find_child("NightZero", true, false) as NightZero
	var boxes := 0
	for c in nz.get_children():
		if c is MovingBox and (c as MovingBox).placed:
			boxes += 1
	check("the boxes are where he stacked them (%d)" % boxes, boxes == NightZero.BOX_COUNT)
	check("the return was consumed", not Evening.returning)


func _wait_for(scene_name: String) -> void:
	for i in 60:
		if current_scene != null and current_scene.name == scene_name:
			await wait(0.5)
			return
		await wait(0.1)
