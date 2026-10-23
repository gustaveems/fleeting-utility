extends "res://tools/lib/verify_harness.gd"
## Ticket-17 probe: Act I's people. The friend calls on the mornings (a head call), each
## favour costs something (the co-sign raises the decay rate, the crate sits by the door
## and vanishes in the ransack), the borrowed painting leaves the wall and "sells" two
## mornings later; the neighbour says hello, notices the decay, comes after the ransack;
## the state survives a save; after a renewed lease the friend never calls again.
## Dialogue runs at 10x.
##
## Run: godot --headless --path . -s tools/probe_act_one.gd

const SPEED := 10.0

var _act: ActOne
var _days: DayCycle
var _runner: DialogueRunner


func _title() -> String:
	return "ACT ONE PROBE"


func _run() -> void:
	_act = ws.find_child("ActOne", true, false) as ActOne
	_days = ws.find_child("DayCycle", true, false) as DayCycle
	_runner = ws.find_child("DialogueRunner", true, false) as DialogueRunner
	var entropy := _act.entropy_data
	var hc := ws.find_child("HeadCall", true, false) as HeadCall
	check("Act I is wired", _act != null and _days != null and _runner != null)
	Engine.time_scale = SPEED

	section("day 2: the friend calls, the neighbour says hello")
	var saw_card := [false]
	hc.line_shown.connect(func(_i: int): saw_card[0] = saw_card[0] or hc.get_child(0).visible)
	await _morning(2, [])
	check("the friend called (a head call)", _act.calls_done.has(2) and saw_card[0])
	check("the neighbour introduced himself", _act.neighbour_said.has("hello"))

	section("day 3: co-sign 'a formality'")
	var rate := entropy.entropy_growth_rate
	await _morning(3, [0])
	check("co-signing raised the decay rate", entropy.entropy_growth_rate > rate * 1.1)

	section("day 4: the crate")
	await _morning(4, [0])
	check("a crate sits by the door", _act._crate != null and _act._crate.is_inside_tree())

	section("day 5: the painting")
	_days.restore(5)  # the friend asks from day 5
	_act.easel.restore({"skill": 0.2, "works": [{"seed": 7.0}]})
	_act.easel.work_finished.emit("Closer. Still wrong.")
	await _settle([0])
	check("the canvas left the wall", _act.easel.hung_works().is_empty() and _act.lent_on_day == 5)
	await _morning(7, [])
	check("two mornings later: it sold (for nothing)", _act.sold_told)

	section("Act II: the supply runs dry")
	var grid := _act.spatial_grid
	for x in grid.grid_width:
		for y in grid.grid_depth:
			grid.remove_item(Vector2i(x, y))
	await process_frame
	_act.bench_station.interacted.emit()
	await process_frame
	await process_frame
	check("running dry is the enclosure", _act.enclosure_told)
	await _settle([0])  # take the friend's front
	var compounds := 0
	for x in grid.grid_width:
		for y in grid.grid_depth:
			if grid.is_cell_occupied(Vector2i(x, y)):
				compounds += 1
	check(
		"the friend fronts two compounds (%d)" % compounds,
		compounds == ActOneScript.FRONT_COMPOUNDS
	)
	check("and he owes", _act.in_debt)

	section("decay and the ransack")
	entropy.entropy = 72.0
	entropy.entropy_changed.emit(72.0)
	await _settle([])
	check(
		"the neighbour noticed the decay",
		_act.neighbour_said.has("decay_40") and _act.neighbour_said.has("decay_70")
	)
	_act._on_phase(GameFlow.Phase.PARK_WALK, GameFlow.Phase.RANSACKED)
	await _settle([])
	check("the crate went with the ransack", _act._crate == null)
	check("the ransack collected the debt", not _act.in_debt)
	check("the neighbour came to the door", _act.neighbour_said.has("ransack"))

	section("7c: the metro across the city")
	var metro := ws.find_child("MetroRide", true, false) as MetroRide
	var door := ws.find_child("ApartmentDoor", true, false) as ApartmentDoor
	var carriage := ws.find_child("MetroCarriage", true, false) as MetroCarriage
	var apartment := ws.find_child("Apartment", true, false) as WorldRoot
	var data := (ws.find_child("PlayerStateMachine", true, false) as PlayerStateMachine).state_data
	entropy.entropy = 30.0
	_days.restore(7)
	data.sensory_overload = 60.0
	check("below the threshold the door is the metro", door.can_interact() and metro.available())
	door._on_interacted()
	await process_frame
	check("the door asks where to go", _runner.awaiting_choice)
	_runner.choices_ui.choose(0)  # the metro (the park isn't open yet)
	await wait(0.3)
	check(
		"he rides (the carriage, not the room)",
		metro.is_riding and carriage.visible and not apartment.visible
	)
	check("day 7's ads: the rich side spreading", metro.stage() == 2)
	var riding_overload := data.sensory_overload
	var home_overload := [-1.0]
	metro.ride_ended.connect(func(): home_overload[0] = data.sensory_overload, CONNECT_ONE_SHOT)
	for n in 600:
		if not metro.is_riding:
			break
		riding_overload = data.sensory_overload
		await process_frame
	await wait(0.3)
	check("home again", not metro.is_riding and apartment.visible and not carriage.visible)
	check(
		"getting out eased the overload (%.0f → %.0f)" % [riding_overload, home_overload[0]],
		(
			home_overload[0] >= 0.0
			and home_overload[0] <= riding_overload - MetroRide.OVERLOAD_RELIEF + 3.0
		)
	)
	check("one ride a day", not metro.available())

	section("18a: the stone in the window")
	check("no stone before the realisation", not metro.stone_seen)
	_act.game_flow.loops_completed = 1
	_days.restore(8)
	metro.start_ride()
	await wait(0.3)
	var window := carriage.find_child("HeritageWindow", true, false) as Node3D
	check(
		"after a loop: the train stops at the Heritage window",
		metro.stone_seen and window != null and window.visible
	)
	await _settle([])
	for n in 600:
		if not metro.is_riding:
			break
		await process_frame
	check("only once", not metro._stone_due())
	_act.game_flow.loops_completed = 0

	section("save, and a renewed lease")
	var snap := _act.snapshot()
	var metro_snap := metro.snapshot()
	_act.restore({})
	_act.restore(snap)
	metro.restore({})
	metro.restore(metro_snap)
	check("rides survive a save", metro.rides_taken == 2 and metro.stone_seen)
	check("the act survives a save", _act.sold_told and _act.favours.get("cosign") == "gave")
	_act.reset_cycle()
	await _morning(6, [])
	check("after the betrayal the friend never calls", not _act.calls_done.has(6))
	Engine.time_scale = 1.0


## Wake on `day` and answer any choices with `picks`, then wait for all talk to end.
func _morning(day: int, picks: Array) -> void:
	_days.restore(day)
	_days.morning.emit(day)
	await wait(ActOne.CALL_DELAY + 0.5)
	await _settle(picks)


func _settle(picks: Array) -> void:
	var i := 0
	for n in 3000:
		if _runner.awaiting_choice and i < picks.size():
			_runner.choices_ui.choose(int(picks[i]))
			i += 1
		if not _runner.is_running and _act._queue.is_empty():
			return
		await process_frame
