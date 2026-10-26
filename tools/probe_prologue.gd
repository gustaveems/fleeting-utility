extends "res://tools/lib/verify_harness.gd"
## Ticket-15 Phase A probe: the prologue film plays its shots in order, fully cinematic
## (no first person), the train only moves forward, all three framed beats fire, the
## metro shot shakes, the walk goes up to the top view and back to third person 3 m
## before the corner, and both the full run and a skip land in the game. Runs at 8x.
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
		"fifteen shots, ~2 min (%.0f s)" % PrologueScript.total_duration(),
		script.size() == 15 and absf(PrologueScript.total_duration() - 119.0) < 8.0
	)
	check(
		"the train stops at the end of the line (%.1f m)" % p.route_length(),
		absf(p.route_length() - PrologueScript.END_OF_LINE) < 2.0
	)
	var speeds: Array[int] = []
	for s in script:
		var span: Array = s["d"]
		if s["mode"] != PrologueScript.Mode.INTERIOR and float(span[1]) > float(span[0]):
			speeds.append(roundi((float(span[1]) - float(span[0])) / float(s["dur"])))
	check(
		"the train runs steadily wherever it is seen: one ~20 m/s (%s)" % str(speeds),
		speeds.min() >= 18 and speeds.max() <= 22
	)
	check("first shot already running", p.shot_index == 0)
	_shots_seen.append(str(script[0]["name"]))
	_modes_seen.append(int(script[0]["mode"]))
	var avenue := p.find_child("Avenue", false, false) as PrologueAvenue
	var camera := p.find_child("FilmCamera", false, false) as Camera3D
	# Camera beats: the metro shake (max roll), the top view height, and how far he is
	# from the corner when third person returns.
	var cam := {"roll": 0.0, "top_y": 0.0, "back_at": -1.0}
	p.shot_started.connect(
		func(_i: int, n: String, m: PrologueScript.Mode):
			_shots_seen.append(n)
			_modes_seen.append(int(m))
			if n == "corner_walk":
				var corner := PrologueAvenue.PATH[PrologueAvenue.CORNER]
				cam["back_at"] = avenue.hero.global_position.distance_to(corner)
	)
	p.gaze_started.connect(func(t: String): _gazes.append(t))
	check("the avenue exists", avenue != null)
	var crossings := [0]
	avenue.suit_crossed.connect(func(): crossings[0] += 1)
	var walked := [0.0]
	var end := [Vector3.ZERO]
	# Street beats: where he is when the car passes and when the fight starts.
	var street := {"car_hero": Vector3.ZERO, "fight_hero": Vector3.ZERO, "crowd": false}
	avenue.car_passed.connect(func(): street["car_hero"] = avenue.hero.global_position)
	avenue.altercation_started.connect(func(): street["fight_hero"] = avenue.hero.global_position)
	var people := 0
	for c in avenue.get_children():
		if c is StreetFigure:
			people += 1
	check("the street is packed (%d people)" % people, people >= 70)
	var kit_pieces := 0
	for c in avenue.get_children():
		if c is MultiMeshInstance3D and str(c.name).begins_with("Kit_"):
			kit_pieces += (c as MultiMeshInstance3D).multimesh.instance_count
	if DirAccess.dir_exists_absolute(CityKit.DIR):
		check("the street has real facades (%d kit modules)" % kit_pieces, kit_pieces > 800)
	check("gaze targets exist", p.gaze_target_position("campaign") != Vector3.ZERO)
	var board := p.find_child("Billboard_%d" % PrologueScript.CAMPAIGN_BILLBOARD, true, false)
	var wears := false
	if board != null:
		for c in board.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).material_override is ShaderMaterial:
				var shader := ((c as MeshInstance3D).material_override as ShaderMaterial).shader
				wears = shader != null and shader.code == CampaignArt.SHADER
	check("the campaign board shows the campaign (the valley, sold)", wears)
	check("colossus head target exists", p.gaze_target_position("colossus") != Vector3.ZERO)

	section("the full film")
	Engine.time_scale = SPEED
	while current_scene == p and not p.is_finished:
		if p.train_distance < _last_d - 0.01 and p.shot_time > 0.05:
			_monotonic = false
		_last_d = p.train_distance
		walked[0] = avenue.progress
		end[0] = avenue.hero.global_position
		street["crowd"] = street["crowd"] or avenue.crowd_arrived()
		var shot_name := str(script[p.shot_index]["name"])
		if shot_name == "metro_interior":
			cam["roll"] = maxf(cam["roll"], absf(camera.global_transform.basis.x.y))
		if shot_name == "avenue_top" and p.shot_time > 4.0:
			cam["top_y"] = maxf(cam["top_y"], camera.global_position.y)
		await process_frame
	Engine.time_scale = 1.0
	var names: Array[String] = []
	for s in script:
		names.append(str(s["name"]))
	check("every shot, in order (%s)" % str(_shots_seen), _shots_seen == names)
	check(
		"fully cinematic: fixed, travelling, train-riding and interior cameras",
		(
			_modes_seen.has(PrologueScript.Mode.EXT_FIXED)
			and _modes_seen.has(PrologueScript.Mode.EXT_PATH)
			and _modes_seen.has(PrologueScript.Mode.EXT_FOLLOW)
			and _modes_seen.has(PrologueScript.Mode.INTERIOR)
		)
	)
	check("the metro shot shakes (roll %.3f)" % cam["roll"], cam["roll"] > 0.004)
	check("the train only moves forward", _monotonic)
	check(
		"the walk glides up to a top view over the street (%.1f m)" % cam["top_y"],
		_modes_seen.has(PrologueScript.Mode.TOP_TRACK) and cam["top_y"] > 15.0
	)
	check(
		"third person returns 3 m before the corner (%.2f m)" % cam["back_at"],
		absf(cam["back_at"] - PrologueScript.BACK_BEFORE_CORNER) < 0.4
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
		"he crosses the whole street; the car rides past behind him (%s)" % str(street["car_hero"]),
		(street["car_hero"] as Vector3).x > PrologueAvenue.CAR_X + 2.0
	)
	check("the group of ten crosses to the metro platform", street["crowd"])
	var fight_hero: Vector3 = street["fight_hero"]
	check(
		"the fight starts at the corner, before he turns into his street (%s)" % str(fight_hero),
		fight_hero != Vector3.ZERO and fight_hero.z > -111.0 and fight_hero.x < 440.0
	)
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
