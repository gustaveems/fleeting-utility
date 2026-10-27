extends "res://tools/lib/verify_harness.gd"
## Ticket-23 probe: Corporate Care. Offered when he wakes from his first collapse;
## declined, it asks once more after the ransack; enrolled, collapse wakes are gentler and
## the climax's clinic shows his consent; refused, no one comes: a slow fade to black,
## "No one came.", he wakes in the room (no clinic), the scars still land and the card
## says "No one came. He woke anyway."; it survives a save and a renewal.
##
## Run: godot --headless --path . -s tools/probe_care.gd

const SPEED := 4.0

var _p: Promises
var _dm: DreamscapeManager
var _sm: PlayerStateMachine
var _runner: DialogueRunner


func _title() -> String:
	return "CARE PROBE"


func _timeout_seconds() -> float:
	return 400.0


func _run() -> void:
	_p = ws.find_child("Promises", true, false) as Promises
	_dm = ws.find_child("DreamscapeManager", true, false) as DreamscapeManager
	_sm = ws.find_child("PlayerStateMachine", true, false) as PlayerStateMachine
	_runner = ws.find_child("DialogueRunner", true, false) as DialogueRunner
	var amb := ws.find_child("AmbulanceInterception", true, false) as AmbulanceInterception
	var endgame := ws.find_child("EndgameLoopManager", true, false) as EndgameLoopManager
	var card := ws.find_child("EndCard", true, false) as EndCard
	var flow := ws.find_child("GameFlow", true, false) as GameFlow
	var atmo := ws.find_child("AtmosphereController", true, false) as AtmosphereController
	var ransacked := ws.find_child("RansackedStateManager", true, false) as RansackedStateManager
	var hc := ws.find_child("HeadCall", true, false) as HeadCall
	check("wired", _p != null and amb.care == _p and endgame.care == _p and card.care == _p)
	_p.pro = "refused"  # no Pro offers here
	_dm.auto_return_seconds = 1.0
	amb.interception_delay = 0.5
	amb.escalation_seconds = 0.5
	endgame.clinical_pause_seconds = 0.3
	card.show_delay = 0.2
	Engine.time_scale = SPEED

	section('his first collapse: "We noticed you collapsed."')
	var callers: Array[String] = []
	hc.line_shown.connect(
		func(_i: int):
			if hc.get_child(0).visible:
				callers.append(str(hc._caller.text))
	)
	await _collapse()
	await _talk([1])  # no thanks
	check("Focus+ called after the wake", callers.has(ActOneScript.FOCUS_CARE))
	check("declined", _p.care == "declined" and not _p.is_care_enrolled())
	await _collapse()
	await _talk([])
	check("no second offer before the ransack", _p.care == "declined")

	section("after the ransack: the last chance")
	ransacked.is_ransacked = true
	ransacked.ransacked_applied.emit()
	await wait(Promises.CALL_DELAY + 0.3)
	await _talk([0])  # enrol
	check("enrolled (day %d)" % _p.care_day, _p.is_care_enrolled() and _p.care_day >= 1)
	check("the last chance is asked once", _p.care_last_offered)

	section("enrolled: gentler wakes")
	await _collapse()
	check(
		"overload lands at %.0f, not 50" % _sm.state_data.sensory_overload,
		_sm.state_data.sensory_overload <= Promises.CARE_WAKE_OVERLOAD + 1.0
	)
	check("with a moment of calm", _sm.state_data.relief_seconds > 0.0)
	await _talk([])

	section("the climax, covered: the clinic shows his consent")
	amb.arm()
	_dream()
	await _dm.forced_return_completed
	check("the ambulance came", flow.phase == GameFlow.Phase.CLINICAL)
	await wait(0.05)
	var msg := endgame._message_label.text if endgame._message_label != null else ""
	check('"enrolled day N · resuscitation included" (%s)' % msg, msg.contains("enrolled day"))
	await endgame.loop_reset
	await wait(0.4)
	check("the usual card", card.is_open and not card._subtitle.text.contains("No one came"))
	card.renew()
	await wait(0.3)
	check("a renewal keeps the enrolment", _p.is_care_enrolled())

	section("the climax, refused: no one comes")
	_p.care = "refused"
	var rate := _sm.entropy_data.entropy_growth_rate
	var intercepted := [false]
	amb.interception_started.connect(func(): intercepted[0] = true, CONNECT_ONE_SHOT)
	amb.arm()
	_dream()
	await _dm.quiet_return_started
	await wait(0.1)
	msg = endgame._message_label.text if endgame._message_label != null else ""
	check('"No one came."', msg == PromisesScript.ALONE)
	check("no siren, no strobe", not intercepted[0])
	await _dm.quiet_return_completed
	check("he wakes in the room, alone", flow.phase == GameFlow.Phase.ALONE)
	check("no clinic", not atmo.is_clinical_mode())
	var flavor := [""]
	endgame.loop_reset.connect(func(t: String): flavor[0] = t, CONNECT_ONE_SHOT)
	await endgame.loop_reset
	check('"No one came. He woke anyway."', flavor[0] == PromisesScript.ALONE_FLAVOR)
	check(
		"the scars still land (decay ×%.1f)" % (_sm.entropy_data.entropy_growth_rate / rate),
		_sm.entropy_data.entropy_growth_rate > rate * 1.4 and flow.phase == GameFlow.Phase.SCARRED
	)
	await wait(0.4)
	check(
		"the card says it",
		card.is_open and card._subtitle.text.begins_with(PromisesScript.ALONE_FLAVOR)
	)

	section("a save, a renewal, an interrupted offer")
	var snap := _p.snapshot()
	_p.restore({})
	_p.restore(snap)
	check("the save keeps it", _p.care == "refused" and _p.care_day == snap["care_day"])
	card.renew()
	await wait(0.3)
	check("renewed: he'll be asked again", _p.care == "" and not _p.care_last_offered)
	_p._offer_care()
	check("asking", _p.care == "asking")
	for n in 20:  # a ride cuts off everything said, the offer too
		if _runner.is_idle():
			break
		_runner.cancel()
		await wait(0.05)
	check("cut off before he answered: asked again next time", _p.care == "")
	Engine.time_scale = 1.0


## Knock him out (the collapse condition), dream, and let the calm return bring him back.
func _collapse() -> void:
	_sm.state_data.chemical_level = 0.0
	_sm.state_data.sensory_overload = 100.0
	await _dm.transition_completed  # in
	_sm.state_data.chemical_level = 0.8
	await _dm.transition_completed  # out


func _dream() -> void:
	_sm.state_data.chemical_level = 0.8
	_sm.state_data.sensory_overload = 0.0
	_dm.auto_return_seconds = 30.0
	_dm.transition_to_dreamscape()


## Answer choices with `picks` in order; wait for all talk to end.
func _talk(picks: Array) -> void:
	await wait(Promises.CALL_DELAY + 0.3)
	var i := 0
	for n in 4000:
		if _runner.awaiting_choice and i < picks.size():
			_runner.choices_ui.choose(int(picks[i]))
			i += 1
		if _runner.is_idle():
			break
		await process_frame
	_sm.state_data.chemical_level = 0.8
	_sm.state_data.sensory_overload = 0.0
	_dm.auto_return_seconds = 1.0
