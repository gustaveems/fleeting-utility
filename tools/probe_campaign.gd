extends "res://tools/lib/verify_harness.gd"
## Ticket-21 probe: the campaign's new image. The friend borrows a canvas; the morning
## after "it SOLD" the Heritage campaign wears it, polished (same seed, brighter,
## coherent, no smear); on the metro it slides past with the city, in the park it hangs
## by the path; the first sighting plays "That's mine." and a choice (asking the
## friend costs self-belief; the ride and the walk wait for the talk); it survives a save.
##
## Run: godot --headless --path . -s tools/probe_campaign.gd

const SPEED := 10.0

var _c: CampaignImage
var _act: ActOne
var _days: DayCycle
var _runner: DialogueRunner


func _title() -> String:
	return "CAMPAIGN PROBE"


func _run() -> void:
	_c = ws.find_child("CampaignImage", true, false) as CampaignImage
	_act = ws.find_child("ActOne", true, false) as ActOne
	_days = ws.find_child("DayCycle", true, false) as DayCycle
	_runner = ws.find_child("DialogueRunner", true, false) as DialogueRunner
	var metro := ws.find_child("MetroRide", true, false) as MetroRide
	var park := ws.find_child("CorporateParkManager", true, false) as CorporateParkManager
	var belief := ws.find_child("SelfBelief", true, false) as SelfBelief
	check(
		"wired: a board on the train and one in the park",
		_c != null and _c.carriage_board != null and _c.park_board != null
	)
	if _c == null:
		return
	check("both hidden", not _c.carriage_board.visible and not _c.park_board.visible)
	(ws.find_child("Promises", true, false) as Promises).pro = "refused"
	_calm()
	Engine.time_scale = SPEED

	section("the friend borrows a canvas, and sells it")
	_days.restore(5)
	var canvas := {"seed": 7.0, "vividness": 0.3, "smear": 0.4, "flatness": 0.0, "coherence": 0.3}
	_act.easel.restore({"skill": 0.2, "works": [canvas]})
	_act.easel.work_finished.emit("Closer. Still wrong.")
	await _settle([0])
	check("lent", is_equal_approx(float(_act.lent_work.get("seed", 0.0)), 7.0))
	await _morning(7)
	check("it SOLD; the campaign goes up tomorrow", _act.sold_told and _c.live_from_day == 8)
	check("not up yet", not _c.is_live())

	section("day 8: on the metro")
	_days.restore(8)
	metro.last_ride_day = -1
	_calm()
	metro.start_ride()
	await wait(0.3)
	var board := _c.carriage_board
	check("his canvas slides past the window", board.visible)
	check(
		"polished: the same canvas, the flaws gone",
		(
			is_equal_approx(float(board.shown["seed"]), 7.0)
			and float(board.shown["vividness"]) >= CampaignBoard.POLISH_VIVIDNESS
			and float(board.shown["smear"]) == 0.0
			and float(board.shown["coherence"]) >= CampaignBoard.POLISH_COHERENCE
		)
	)
	var before := belief.value
	var ended_with := [""]
	metro.ride_ended.connect(func(): ended_with[0] = _c.reaction, CONNECT_ONE_SHOT)
	for n in 6000:
		if _runner.awaiting_choice:
			_runner.choices_ui.choose(0)  # call the friend about it
		if not metro.is_riding:
			break
		await process_frame
	check('"That\'s mine." (seen)', _c.was_seen)
	check("he called the friend", _c.reaction == "asked")
	check(
		"asking cost him (%.2f → %.2f)" % [before, belief.value],
		is_equal_approx(belief.value, before - CampaignImage.ASK_COST)
	)
	check("the ride waited for the talk", ended_with[0] == "asked")

	section("it stays up; seen once")
	_days.restore(9)
	metro.last_ride_day = -1
	_calm()
	metro.start_ride()
	await wait(CampaignImage.SEEN_DELAY + 0.5)
	check("still there", board.visible)
	check("no second sighting", not _runner_has_choice())
	for n in 4000:
		if not metro.is_riding:
			break
		await process_frame

	section("in the park (letting it go)")
	_c.restore({"live_from_day": 8})
	park.park_duration = 0.5
	_calm()
	park.transition_to_park()
	await wait(0.3)
	check("on a billboard by the park's path", _c.park_board.visible)
	before = belief.value
	var cut := [false]
	for n in 6000:
		if _runner.awaiting_choice:
			_runner.choices_ui.choose(1)  # let it go
		if _runner.is_running and not park.is_in_park():
			cut[0] = true
		if _c.reaction == "silent" and _runner.is_idle():
			break
		await process_frame
	check("let it go", _c.reaction == "silent" and belief.value == before)
	check("the walk waited for the talk", not cut[0])

	section("a save")
	var snap := _c.snapshot()
	_c.restore({})
	check("a fresh game has no campaign", not _c.is_live())
	_c.restore(snap)
	check("the save keeps it", _c.is_live() and _c.was_seen and _c.reaction == "silent")
	var persistence := ws.find_child("Persistence", true, false) as Persistence
	var save := persistence.snapshot()
	check(
		"in the save file, with the canvas",
		save.has("campaign") and save["act_one"].has("lent_work")
	)
	Engine.time_scale = 1.0


func _runner_has_choice() -> bool:
	return _runner.awaiting_choice


func _calm() -> void:
	var data := _act.easel.state_data
	data.chemical_level = 0.8
	data.sensory_overload = 0.0


func _morning(day: int) -> void:
	_days.restore(day)
	_days.morning.emit(day)
	await wait(ActOne.CALL_DELAY + 0.5)
	await _settle([])


func _settle(picks: Array) -> void:
	var i := 0
	for n in 3000:
		if _runner.awaiting_choice and i < picks.size():
			_runner.choices_ui.choose(int(picks[i]))
			i += 1
		if _runner.is_idle():
			return
		await process_frame
