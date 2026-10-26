extends "res://tools/lib/verify_harness.gd"
## The full playthrough, end to end, from the main menu: New Game → the prologue (skipped)
## → the lease → Night Zero's move-in → the evening (car, dinner, gift, walk, metro) →
## home → Act I's days (the friend's calls and favours, the neighbour, a metro ride, the
## supply running dry) → the park → the ransack → the hesitation and the visions → the
## ambulance → clinical → the end card → renew → the second cycle's stone in the window.
##
## Each system has its own probe; this one proves they hand over to each other without
## a break. It follows the real scene changes (current_scene), runs dialogue fast, and
## answers every choice with the first option.
##
## Run: godot --headless --path . -s tools/probe_full_run.gd

const FAST := 10.0


func _scene_path() -> String:
	return "res://scenes/boot.tscn"


func _title() -> String:
	return "FULL RUN PROBE"


func _timeout_seconds() -> float:
	return 600.0


func _run() -> void:
	section("the menu → New Game → the prologue")
	await wait(2.5)
	var new_game := _find("Button_NewGame") as Button
	check("main menu", new_game != null)
	if new_game == null:
		return
	new_game.pressed.emit()
	await _wait_for("Prologue")
	check("New Game plays the prologue", _scene() == "Prologue")
	await wait(0.5)
	Input.action_press(InputActionData.ACTION_INTERACT)
	await wait(1.3)
	Input.action_release(InputActionData.ACTION_INTERACT)
	await _wait_for("Workspace")
	check("skipping lands in the game", _scene() == "Workspace")

	section("the lease")
	await wait(0.5)
	var lease := _n("LeaseSigning") as LeaseSigning
	check("the lease is on screen", lease != null and lease.is_open)
	Input.action_press(InputActionData.ACTION_INTERACT)
	await wait(LeaseSigning.HOLD_SECONDS + 0.4)
	Input.action_release(InputActionData.ACTION_INTERACT)
	await wait(0.3)
	check("signed", lease.is_signed)

	section("Night Zero: the move-in")
	var nz := _n("NightZero") as NightZero
	var player := _n("Player") as PlayerMovement
	check("the friend is in, the boxes by the door", nz.is_running and nz.boxes.size() == 3)
	var zone := NightZero.DROP_ZONE
	for box in nz.boxes:
		box.try_interact()
		await wait(0.1)
		player.global_position = nz.to_global(
			Vector3(zone.get_center().x + 0.3, 0, zone.get_center().y)
		)
		nz.drop_carried()
		await wait(0.1)
	check("three boxes stacked", nz.placed == 3)
	Engine.time_scale = FAST
	await _wait_for("Evening", 400)
	Engine.time_scale = 1.0
	check("the invitation leads to the evening", _scene() == "Evening")

	section("the evening")
	var eve := current_scene as Evening
	await wait(0.3)
	eve.skip_film()
	await wait(0.3)
	Engine.time_scale = FAST
	for i in 4000:
		if eve.segment not in ["dinner", "gift"]:
			break
		if eve.runner.awaiting_choice:
			eve.runner.choices_ui.choose(0)
		await process_frame
	Engine.time_scale = 1.0
	check(
		"dinner and the gift played (%d choices)" % eve.runner.choices.size(),
		eve.runner.choices.size() == 5
	)
	check("then he walks", eve.segment == "walk")
	eve.player.global_position = eve.layout.world(EveningLayout.BEATS["station"])
	await wait(0.5)
	eve.skip_film()
	await _wait_for("Workspace")
	check("home", _scene() == "Workspace")
	await wait(0.5)
	nz = _n("NightZero") as NightZero
	var stacked := 0
	for c in nz.get_children():
		if c is MovingBox and (c as MovingBox).placed:
			stacked += 1
	check("the boxes are where he left them", stacked == 3)

	section("Act I: the days")
	player = _n("Player") as PlayerMovement  # a new game scene since the evening
	var act := _n("ActOne") as ActOne
	var days := _n("DayCycle") as DayCycle
	var runner := _n("DialogueRunner") as DialogueRunner
	var dm := _n("DreamscapeManager") as DreamscapeManager
	var cot := _n("Cot") as Cot
	var sm := _n("PlayerStateMachine") as PlayerStateMachine
	dm.auto_return_seconds = 1.0
	for d in range(2, 8):
		_calm(sm)
		check("day %d: he can sleep" % (d - 1), cot.try_interact())
		await dm.transition_completed  # the night dream
		await dm.transition_completed  # morning
		await wait(ActOne.CALL_DELAY + 0.3)
		Engine.time_scale = FAST
		await _talk(runner)
		Engine.time_scale = 1.0
		check("it is day %d" % d, days.day == d)
		print("  [pace] morning of day %d: entropy %.0f" % [d, sm.entropy_data.entropy])
		if d == 5:
			await _ride(runner)
	check(
		"the friend called on days 2, 3, 4, 6",
		(
			act.calls_done.has(2)
			and act.calls_done.has(3)
			and act.calls_done.has(4)
			and act.calls_done.has(6)
		)
	)
	check(
		"favours given: the co-sign and the crate",
		act.favours.get("cosign") == "gave" and act.favours.get("crate") == "gave"
	)
	check("the neighbour said hello", act.neighbour_said.has("hello"))
	var metro := _n("MetroRide") as MetroRide
	check("a metro ride on day 5", metro.rides_taken == 1)

	section("Act II: the supply runs dry")
	var grid := act.spatial_grid
	for x in grid.grid_width:
		for y in grid.grid_depth:
			grid.remove_item(Vector2i(x, y))
	await process_frame
	act.bench_station.interacted.emit()
	await process_frame
	await process_frame
	Engine.time_scale = FAST
	await _talk(runner)
	Engine.time_scale = 1.0
	check("the enclosure; the friend fronts him", act.enclosure_told and act.in_debt)

	section("the park, the ransack")
	var park := _n("CorporateParkManager") as CorporateParkManager
	var flow := _n("GameFlow") as GameFlow
	var door := _n("ApartmentDoor") as ApartmentDoor
	sm.entropy_data.entropy = 75.0
	_calm(sm)
	door._on_interacted()
	await process_frame
	runner.choices_ui.choose(0)  # the park
	await wait(0.3)
	check("into the park", flow.phase == GameFlow.Phase.PARK_WALK)
	park.transition_to_apartment()
	await wait(0.5)
	var ransacked := _n("RansackedStateManager") as RansackedStateManager
	check("ransacked", ransacked.is_ransacked)
	check("the crate went with it, and the debt", act._crate == null and not act.in_debt)
	check("the neighbour came", act.neighbour_said.has("ransack"))
	Engine.time_scale = FAST
	await _talk(runner)
	Engine.time_scale = 1.0

	# Forced detox: the stash is gone, he collapses into a calm dream and wakes in the wreck.
	for i in 300:
		if flow.phase == GameFlow.Phase.RANSACKED and not dm.in_dreamscape() and not dm.is_busy():
			break
		await wait(0.1)
	check("the detox dream returns him to the ruined room", flow.phase == GameFlow.Phase.RANSACKED)
	_calm(sm)

	section("the hesitation, the visions, the climax")
	var hesitation := _n("HesitationController") as HesitationController
	var visions := _n("DualVisionController") as DualVisionController
	var ambulance := _n("AmbulanceInterception") as AmbulanceInterception
	var endgame := _n("EndgameLoopManager") as EndgameLoopManager
	var card := _n("EndCard") as EndCard
	ambulance.interception_delay = 0.5
	ambulance.escalation_seconds = 0.5
	endgame.clinical_pause_seconds = 0.3
	card.show_delay = 0.2
	hesitation.initiate_hesitation()
	await visions.visions_ended
	check("the visions arm the ambulance", ambulance.armed)
	sm.state_data.chemical_level = 0.0
	sm.state_data.sensory_overload = 0.0
	await wait(0.1)
	sm.state_data.sensory_overload = 100.0
	await dm.transition_completed
	await dm.forced_return_completed
	check("intercepted: clinical", flow.phase == GameFlow.Phase.CLINICAL)
	var clinical := _n("ClinicalDressing") as Node3D
	check("the corporate medics stand over him", clinical != null and clinical.visible)
	await endgame.loop_reset
	await wait(0.6)
	check("the end card", card.is_open)

	section("renew: the second cycle")
	card.renew()
	await wait(0.3)
	check("cycle 2", flow.loops_completed == 1 and flow.phase == GameFlow.Phase.WORKSPACE)
	check("the friend is gone for good", act.friend_gone)
	days.restore(days.day + 1)
	metro.last_ride_day = -1
	sm.entropy_data.entropy = 30.0
	metro.start_ride()
	await wait(0.3)
	check("the stone in the Heritage window", metro.stone_seen)
	Engine.time_scale = FAST
	for i in 2000:
		if not metro.is_riding:
			break
		await process_frame
	Engine.time_scale = 1.0
	check("home again", not metro.is_riding)


## ----- HELPERS ------------------------------------------------------------------------


func _scene() -> String:
	return current_scene.name if current_scene != null else ""


func _n(name: String) -> Node:
	return current_scene.find_child(name, true, false) if current_scene != null else null


func _find(name: String) -> Node:
	return root.find_child(name, true, false)


func _wait_for(scene_name: String, tries: int = 80) -> void:
	for i in tries:
		if _scene() == scene_name:
			await wait(0.3)
			return
		await wait(0.1)


## Let every queued line play out, answering choices with the first option.
func _talk(runner: DialogueRunner) -> void:
	for i in 6000:
		if runner.awaiting_choice:
			runner.choices_ui.choose(0)
		if runner.is_idle():
			return
		await process_frame


func _ride(runner: DialogueRunner) -> void:
	var metro := _n("MetroRide") as MetroRide
	var door := _n("ApartmentDoor") as ApartmentDoor
	var park_open := door._park_open()
	door._on_interacted()
	await process_frame
	runner.choices_ui.choose(1 if park_open else 0)  # the metro
	await wait(0.3)
	Engine.time_scale = FAST
	for i in 3000:
		if not metro.is_riding:
			break
		await process_frame
	Engine.time_scale = 1.0
	await _talk(runner)


## Keep him medicated so no collapse or compulsion interrupts a beat.
func _calm(sm: PlayerStateMachine) -> void:
	sm.state_data.chemical_level = 0.7
	sm.state_data.sensory_overload = 0.0
