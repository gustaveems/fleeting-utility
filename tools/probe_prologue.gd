extends "res://tools/lib/verify_harness.gd"
## Ticket-15 Phase A probe: the prologue film plays its shots in order, the train only
## moves forward, all three gaze moments fire, and both the full run and a skip land in
## the game. Runs at 8x speed.
##
## Run: godot --headless --path . -s tools/probe_prologue.gd

const SPEED := 8.0

var _shots_seen: Array[String] = []
var _modes_seen: Array[int] = []
var _gazes: Array[String] = []
var _monotonic := true
var _last_d := -1.0


func _scene_path() -> String:
	return "res://scenes/prologue.tscn"


func _title() -> String:
	return "PROLOGUE PROBE"


func _run() -> void:
	var p := current_scene as Prologue
	check("prologue scene boots", p != null)
	if p == null:
		return
	var script := PrologueScript.shots()
	check(
		"thirteen shots, ~2 min 20 (%.0f s)" % PrologueScript.total_duration(),
		script.size() == 13 and absf(PrologueScript.total_duration() - 139.0) < 8.0
	)
	check(
		"the train stops at the end of the line (%.1f m)" % p.route_length(),
		absf(p.route_length() - PrologueScript.END_OF_LINE) < 2.0
	)
	check("first shot already running", p.shot_index == 0)
	_shots_seen.append(str(script[0]["name"]))
	_modes_seen.append(int(script[0]["mode"]))
	p.shot_started.connect(
		func(_i: int, n: String, m: PrologueScript.Mode):
			_shots_seen.append(n)
			_modes_seen.append(int(m))
	)
	p.gaze_started.connect(func(t: String): _gazes.append(t))
	var avenue := p.find_child("Avenue", false, false) as PrologueAvenue
	check("the avenue exists", avenue != null)
	var crossings := [0]
	avenue.suit_crossed.connect(func(): crossings[0] += 1)
	var walked := [0.0]
	var end := [Vector3.ZERO]
	check("gaze targets exist", p.gaze_target_position("campaign") != Vector3.ZERO)
	check("colossus head target exists", p.gaze_target_position("colossus") != Vector3.ZERO)

	section("the full film")
	Engine.time_scale = SPEED
	while current_scene == p and not p.is_finished:
		if p.train_distance < _last_d - 0.01 and p.shot_time > 0.05:
			_monotonic = false
		_last_d = p.train_distance
		walked[0] = avenue.progress
		end[0] = avenue.hero.global_position
		await process_frame
	Engine.time_scale = 1.0
	var names: Array[String] = []
	for s in script:
		names.append(str(s["name"]))
	check("every shot, in order (%s)" % str(_shots_seen), _shots_seen == names)
	check(
		"POV mixes first person and external",
		_modes_seen.has(PrologueScript.Mode.FP) and _modes_seen.has(PrologueScript.Mode.EXT_FIXED)
	)
	check("the train only moves forward", _monotonic)
	check(
		"the walk mixes in third person and an aisle shot",
		(
			_modes_seen.has(PrologueScript.Mode.WALK_FOLLOW)
			and _modes_seen.has(PrologueScript.Mode.FP_AISLE)
		)
	)
	check("he walks all the way to his door (%.2f)" % walked[0], walked[0] >= 0.99)
	check(
		"he turned the corner to his complex (%s)" % str(end[0]),
		(
			end[0].x > PrologueAvenue.AVENUE_X + 15.0
			and end[0].distance_to(PrologueAvenue.PATH[-1]) < 0.5
		)
	)
	check(
		"he came down from the platform",
		PrologueAvenue.PATH[0].y > 5.0 and PrologueAvenue.PATH[-1].y < 0.5
	)
	check("suits cross his path twice (%d)" % crossings[0], crossings[0] == 2)
	check(
		"gaze moments: ad, lease, colossus (%s)" % str(_gazes),
		_gazes == ["campaign", "phone", "colossus"]
	)
	await _wait_for("Workspace")
	check("the film ends in the game", current_scene != null and current_scene.name == "Workspace")

	section("skipping")
	current_scene.queue_free()
	await process_frame
	var again := (load(_scene_path()) as PackedScene).instantiate()
	root.add_child(again)
	current_scene = again
	await wait(0.5)
	Input.action_press(InputActionData.ACTION_INTERACT)
	await wait(1.3)
	Input.action_release(InputActionData.ACTION_INTERACT)
	await _wait_for("Workspace")
	check(
		"holding E skips into the game", current_scene != null and current_scene.name == "Workspace"
	)


func _wait_for(scene_name: String) -> void:
	for i in 50:
		if current_scene != null and current_scene.name == scene_name:
			await wait(0.3)
			return
		await wait(0.1)
