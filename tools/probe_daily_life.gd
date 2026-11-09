extends "res://tools/lib/verify_harness.gd"
## The small daily things (docs/STORY.md 8a–c): the paper under the door comes on its
## mornings and reads once, the radio plays once a day and eases him and dies with the
## ransack, LeaseLink logs his calls and has no signal in the valley, the day card shows
## the day, and all of it comes back from a save.
##
## Run: godot --headless --path . -s tools/probe_daily_life.gd


func _title() -> String:
	return "DAILY LIFE PROBE"


func _run() -> void:
	var daily := ws.find_child("DailyLife", true, false) as DailyLife
	var envelope := ws.find_child("NoticeEnvelope", true, false) as NoticeEnvelope
	var panel := ws.find_child("NoticePanel", true, false) as NoticePanel
	var radio := ws.find_child("RadioSet", true, false) as RadioSet
	var phone := ws.find_child("LeasePhone", true, false) as LeasePhone
	var card := ws.find_child("DayCard", true, false) as DayCard
	var days := ws.find_child("DayCycle", true, false) as DayCycle
	var runner := ws.find_child("DialogueRunner", true, false) as DialogueRunner
	var head := ws.find_child("HeadCall", true, false) as HeadCall
	var ransacked := ws.find_child("RansackedStateManager", true, false) as RansackedStateManager
	var player := ws.find_child("Player", true, false) as PlayerMovement
	var sm := ws.find_child("PlayerStateMachine", true, false) as PlayerStateMachine
	var dream := ws.find_child("DreamscapeManager", true, false) as DreamscapeManager
	var hint := ws.find_child("NextStepHint", true, false) as NextStepHint

	section("the paper under the door")
	check("nothing there on day 1", not daily.has_notice() and not envelope.is_showing())
	days.morning.emit(3)
	check("a notice comes on its morning", daily.has_notice() and envelope.is_showing())
	check("the hint points at it", hint.facts()["notice"] == true)
	check("it can be read", envelope.try_interact())
	check("the paper is up, and he stands still", panel.is_open and player.input_locked)
	check("it's gone from the floor", not envelope.is_showing() and not daily.has_notice())
	panel.close()
	check("put down, he moves again", not player.input_locked)
	days.morning.emit(5)
	check("no notice on a quiet morning", not daily.has_notice())
	days.morning.emit(4)
	check("the flyer shows the shoes", "HERITAGE" in str(daily.notice()[0]))
	daily.read_notice()

	section("the radio")
	days.restore(2)
	runner.clear_queue()  # the mornings above started the day's calls
	runner.cancel()
	head.stop()
	await wait(0.3)
	sm.state_data.sensory_overload = 20.0
	check("it plays", radio.can_interact() and radio.try_interact())
	check(
		"it eases him",
		is_equal_approx(sm.state_data.sensory_overload, 20.0 - DailyLife.RADIO_RELIEF)
	)
	await wait(0.2)
	check("the bulletin is on air", head.current_line().size() > 0)
	head.stop()
	runner.cancel()
	await wait(0.2)
	check("once a day", not radio.can_interact())
	check("and it says so", radio.current_prompt() == DailyLifeScript.RADIO_DONE)
	days.restore(3)
	check("a new day, a new bulletin", radio.can_interact())

	section("LeaseLink")
	head.play([["FRIEND", "Probe call.", 0.2]], true)
	await wait(0.05)
	check("a call goes in the log", str(daily.call_log[-1][2]) == "Probe call.")
	await wait(0.3)
	phone.toggle()
	check("P opens it, he stands still", phone.is_open and player.input_locked)
	check("it shows the day", "DAY 3" in phone.header_text())
	check("and the call", "Probe call." in phone.log_text())
	phone.toggle()
	check("P closes it", not phone.is_open and not player.input_locked)
	sm.state_data.sensory_overload = 0.0
	dream.transition_to_dreamscape()
	for n in 100:
		if dream.in_dreamscape() and not dream.is_busy():
			break
		await wait(0.1)
	phone.toggle()
	check("no signal in the valley", "NO SIGNAL" in phone.header_text())
	phone.toggle()

	section("the day card")
	card.show_day(7)
	check("it names the day", card.text() == "DAY 7")

	section("after the ransack, and in the save")
	ransacked.is_ransacked = true
	check("the radio is dead", not radio.can_interact())
	check("and says why", radio.current_prompt() == DailyLifeScript.RADIO_DEAD)
	days.morning.emit(9)
	check("the incident report comes", "INCIDENT" in str(daily.notice()[1]))
	var saved := daily.snapshot()
	daily.read_notice()
	daily.restore(saved)
	check("a saved notice comes back", daily.has_notice() and envelope.is_showing())
	check("and the log", not daily.call_log.is_empty())
	ransacked.is_ransacked = false
	daily.reset_cycle()
	check("a renewal clears the floor", not daily.has_notice())
	days.morning.emit(2)
	check("the same paper comes again", "SECOND NOTICE" in str(daily.notice()[1]))
