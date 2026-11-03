extends "res://tools/lib/verify_harness.gd"
## Playtest 2026-11-03: he took the metro overloaded, collapsed on the train, dreamed with
## the carriage still running (the city flying past the valley), and woke boxed into a
## strip of his room (the dream had saved the carriage's aisle as "home"). An outing he
## collapses on brings him home first, then he goes under; he wakes free in his room.
## The rooftop night is the same kind of outing.
##
## Run: godot --headless --path . -s tools/probe_outing_collapse.gd

var _manager: DreamscapeManager
var _player: PlayerMovement
var _data: PlayerStateData


func _title() -> String:
	return "OUTING COLLAPSE PROBE"


func _run() -> void:
	_manager = node("DreamscapeManager") as DreamscapeManager
	_player = node("Player") as PlayerMovement
	_data = (node("PlayerStateMachine") as PlayerStateMachine).state_data
	var dialogue := node("DialogueRunner") as DialogueRunner
	dialogue.clear_queue()
	if dialogue.is_running:
		dialogue.cancel()
	await wait(0.3)
	var room := _player.room_half_extents
	var apartment := node("Apartment") as WorldRoot

	section("collapsing on the metro")
	var metro := node("MetroRide") as MetroRide
	var carriage := node("MetroCarriage") as MetroCarriage
	metro.start_ride()
	await wait(0.5)
	check("riding", metro.is_riding and carriage.visible)
	await _collapse()
	check("he goes under", _manager.in_dreamscape())
	check("the ride is over", not metro.is_riding)
	check("no carriage in the dream", not carriage.visible)
	check("no apartment in the dream", not apartment.visible)
	await _wake()
	check(
		"he wakes free in his room (%s, was %s)" % [_player.room_half_extents, room],
		_player.room_half_extents.is_equal_approx(room)
	)
	check("the room is back", apartment.visible and not carriage.visible)
	await wait(metro.LINGER + 1.0)
	check("the ride's leftovers change nothing", apartment.visible and not _manager.in_dreamscape())

	section("collapsing on the rooftop")
	var standing := node("Standing") as Standing
	var lounge := node("RooftopLounge") as RooftopLounge
	var day := node("DayCycle") as DayCycle
	day.day = int(StandingScript.EVENTS[0][0])
	standing.attended.clear()
	if standing.invitation() < 0:
		check("an invitation tonight (skipped: none on day %d)" % day.day, true)
		return
	standing.go_out()
	await wait(0.5)
	check("out", standing.is_out and lounge.visible)
	await _collapse()
	check("he goes under", _manager.in_dreamscape())
	check("the night is over", not standing.is_out and not lounge.visible)
	await _wake()
	check(
		"he wakes free in his room (%s)" % _player.room_half_extents,
		_player.room_half_extents.is_equal_approx(room)
	)


func _collapse() -> void:
	_data.chemical_level = 0.0
	_data.sensory_overload = 100.0
	for i in 60:
		if _manager.in_dreamscape() and not _manager.is_busy():
			return
		await wait(0.2)


func _wake() -> void:
	# A dose before he wakes, or, still withdrawn, he collapses again within seconds.
	_data.chemical_level = 1.0
	_manager.return_to_workspace()
	for i in 60:
		if not _manager.in_dreamscape() and not _manager.is_busy():
			break
		await wait(0.2)
	_data.sensory_overload = 0.0
	await wait(0.3)
