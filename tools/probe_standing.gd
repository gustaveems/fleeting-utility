extends "res://tools/lib/verify_harness.gd"
## Ticket-24 probe: the status loop. His standing sinks every morning, faster each day;
## the crowd invites him on days 3, 5, 8; the door goes up to the rooftop; medicated he
## lands the smooth lines (fitting in lifts him), off the drug they turn into stumbles;
## the rooftop is a world of its own (Rule 2) and he comes home after; each invitation
## once; the wall screen shows the standing; it survives a save; after the betrayal the
## invitations stop.
##
## Run: godot --headless --path . -s tools/probe_standing.gd

const SPEED := 10.0

var _s: Standing
var _days: DayCycle
var _runner: DialogueRunner
## Every option offered during a night (the choice panel's labels).
var _offered: Array[String] = []


func _title() -> String:
	return "STANDING PROBE"


func _run() -> void:
	_s = ws.find_child("Standing", true, false) as Standing
	_days = ws.find_child("DayCycle", true, false) as DayCycle
	_runner = ws.find_child("DialogueRunner", true, false) as DialogueRunner
	var door := ws.find_child("ApartmentDoor", true, false) as ApartmentDoor
	var lounge := ws.find_child("RooftopLounge", true, false) as RooftopLounge
	var apartment := ws.find_child("Apartment", true, false) as WorldRoot
	var screen := ws.find_child("AdScreen", true, false) as AdScreen
	var act := ws.find_child("ActOne", true, false) as ActOne
	var promises := ws.find_child("Promises", true, false) as Promises
	check("wired", _s != null and door.standing == _s and lounge != null)
	if _s == null:
		return
	promises.pro = "refused"
	promises.care = "enrolled"
	act.friend_gone = false
	check("the rooftop sleeps until a night out", not lounge.visible and live_shapes(lounge) == 0)
	Engine.time_scale = SPEED

	section("everyone else advances")
	var start := _s.standing
	await _morning(2)
	var first := start - _s.standing
	await _morning(3)
	var second := (start - first) - _s.standing
	check(
		"it sinks every morning (−%.1f, then −%.1f)" % [first, second],
		first > 0.0 and second > first
	)
	check(
		"the wall screen shows it",
		screen._standing_label.text == StandingScript.SCREEN % int(round(_s.standing))
	)

	section("day 3: Vesna's rooftop (medicated)")
	check("an invitation tonight", _s.invitation() == 0)
	check("the door goes out", door.can_interact() and door.current_prompt().contains("Go out"))
	_medicate(true)
	var before := _s.standing
	door._on_interacted()
	await process_frame
	check("the door asks", _runner.awaiting_choice)
	_runner.choices_ui.choose(0)  # Vesna's rooftop (first in the menu)
	await wait(0.3)
	check(
		"up on the roof (the room asleep)",
		_s.is_out and lounge.visible and not apartment.visible and live_shapes(apartment) == 0
	)
	await _night([0, 0])  # fit in, twice
	check("the smooth lines were there", _offered.size() > 0 and not _has("The what?"))
	check(
		"fitting in lifted him (+%.0f)" % (_s.standing - before),
		is_equal_approx(_s.standing, before + 2.0 * StandingScript.DELTA["fit"])
	)
	check("home after", not _s.is_out and apartment.visible and not lounge.visible)
	check("each invitation once", _s.invitation() == -1)

	section("day 5: Okon's launch (off the drug)")
	await _morning(5)
	check("an invitation tonight", _s.invitation() == 1)
	_medicate(false)
	before = _s.standing
	_s.go_out()
	await wait(0.3)
	_offered.clear()
	await _night([0, 0])
	check("off the drug, the smooth line is a stumble", _has("No. Not really."))
	check(
		"stumbling cost him (%.0f)" % (_s.standing - before),
		is_equal_approx(_s.standing, before + 2.0 * StandingScript.DELTA["stumble"])
	)

	section("a save; the betrayal")
	var snap := _s.snapshot()
	_s.restore({})
	check("a fresh game", _s.standing == Standing.START and _s.attended.is_empty())
	_s.restore(snap)
	check("the save keeps it", is_equal_approx(_s.standing, float(snap["standing"])))
	var persistence := ws.find_child("Persistence", true, false) as Persistence
	check("in the save file", persistence.snapshot().has("standing"))
	act.friend_gone = true
	_s.reset_cycle()
	_days.restore(8)
	check("after the betrayal, no more invitations", _s.invitation() == -1)
	before = _s.standing
	await _morning(9)
	check("and it keeps sinking", _s.standing < before)
	Engine.time_scale = 1.0


func _has(text: String) -> bool:
	for o in _offered:
		if o.contains(text):
			return true
	return false


func _medicate(on: bool) -> void:
	_s.state_data.chemical_level = 0.8 if on else 0.1
	_s.state_data.sensory_overload = 0.0


func _morning(day: int) -> void:
	_days.restore(day)
	_days.morning.emit(day)
	await wait(Standing.CALL_DELAY + 0.3)
	for n in 3000:
		if _runner.awaiting_choice:
			_runner.choices_ui.choose(0)
		if _runner.is_idle():
			break
		await process_frame
	_medicate(true)


func _night(picks: Array) -> void:
	var i := 0
	for n in 6000:
		if _runner.awaiting_choice and i < picks.size():
			for l: Label in _runner.choices_ui._labels:
				_offered.append(l.text)
			_runner.choices_ui.choose(int(picks[i]))
			i += 1
		if not _s.is_out:
			return
		await process_frame
