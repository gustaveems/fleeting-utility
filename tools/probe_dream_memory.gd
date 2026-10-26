extends "res://tools/lib/verify_harness.gd"
## Ticket-20 probe: forgetting and confession. "[E] Remember" writes half a sentence,
## unwrites it ("It's gone."), then the flash home, and a short countdown can't cut it
## off; after three lost memories the next dream opens at a colossus's feet, locks him,
## asks, and every answer is a confession; once a cycle, never with the ambulance armed;
## the dual visions give the lost sentences back whole; it survives a save and a renewal.
##
## Run: godot --headless --path . -s tools/probe_dream_memory.gd

const SPEED := 4.0

var _dm: DreamscapeManager
var _mem: DreamMemory
var _text: DreamText
var _sm: PlayerStateMachine


func _title() -> String:
	return "DREAM MEMORY PROBE"


func _timeout_seconds() -> float:
	return 300.0


func _run() -> void:
	_dm = ws.find_child("DreamscapeManager", true, false) as DreamscapeManager
	_mem = ws.find_child("DreamMemory", true, false) as DreamMemory
	_text = ws.find_child("DreamText", true, false) as DreamText
	_sm = ws.find_child("PlayerStateMachine", true, false) as PlayerStateMachine
	var player := ws.find_child("Player", true, false) as PlayerMovement
	var runner := ws.find_child("DialogueRunner", true, false) as DialogueRunner
	var valley := ws.find_child("DreamscapeValley", true, false) as DreamscapeEnvironment
	check("wired", _mem != null and _text != null and _dm.dream_memory == _mem)
	if _mem == null:
		return
	Engine.time_scale = SPEED
	_dm.auto_return_seconds = 2.0  # shorter than a reach: it must not cut one off

	section("forgetting: the sentence unwrites itself")
	await _dream()
	var anchor := valley.memory_anchors[0]
	_dm._remember(anchor)
	var start := str(DreamMemoryScript.FRAGMENTS[0][0])
	await wait(DreamMemoryScript.WRITE_SECONDS + DreamMemoryScript.HOLD_SECONDS * 0.5)
	check('half a sentence ("%s")' % _text.shown, _text.shown == start + "—")
	check("he can't walk off mid-reach", player.input_locked)
	await wait(DreamMemoryScript.HOLD_SECONDS * 0.5 + DreamMemoryScript.ERASE_SECONDS * 0.6)
	check(
		'unwritten from the end ("%s")' % _text.shown,
		_text.shown.length() < start.length() and start.begins_with(_text.shown.trim_suffix("—"))
	)
	await wait(DreamMemoryScript.ERASE_SECONDS * 0.4 + DreamMemoryScript.GONE_SECONDS * 0.4)
	check('"It\'s gone."', _text.shown == DreamMemoryScript.GONE)
	await _dm.transition_completed
	check("then home (the countdown waited)", not _dm.in_dreamscape())
	check("one memory lost", _mem.lost == [0] and _mem.lost_this_cycle == 1)

	section("three lost: the confession is due")
	for i in 2:
		await _dream()
		_dm._remember(valley.memory_anchors[i + 1])
		await _dm.transition_completed
	check("a different fragment each time", _mem.lost == [0, 1, 2])
	check("the confession is due", _mem.confession_due and not _mem.confessed)

	section("the confession, at a colossus's feet")
	_dm.auto_return_seconds = 30.0
	var tag := [""]
	_mem.confession_ended.connect(func(t: String): tag[0] = t, CONNECT_ONE_SHOT)
	await _dream()
	var statue := DreamscapeEnvironment.STATUE_POSITIONS[DreamMemory.STATUE_INDEX]
	var flat := Vector2(player.global_position.x, player.global_position.z)
	check(
		"he comes to before the colossus (%.0f m)" % flat.distance_to(Vector2(statue.x, statue.z)),
		flat.distance_to(Vector2(statue.x, statue.z)) < 20.0
	)
	check(
		"looking up at it",
		player.facing_direction().dot((statue - player.global_position).normalized()) > 0.9
	)
	check("he can't move", _mem.is_confessing and player.input_locked)
	for n in 4000:
		if runner.awaiting_choice:
			break
		await process_frame
	check('"Could you have stood there?"', runner.awaiting_choice)
	var labels: Array[String] = []
	for o: Dictionary in DreamMemoryScript.CONFESSION[2]["choose"]["options"]:
		labels.append(str(o["text"]))
	check("every answer is a no", labels.size() == 3 and not labels.has("Yes."))
	runner.choices_ui.choose(1)
	await _dm.transition_completed
	check("then he wakes", not _dm.in_dreamscape() and not player.input_locked)
	check('confessed ("watch")', _mem.confessed and tag[0] == "watch" and not _mem.confession_due)

	section("once a cycle; never in the climax")
	await _dream()
	check("no second confession", not _mem.is_confessing)
	await _home()
	_mem.restore({"lost": [0, 1, 2], "lost_this_cycle": 3, "confession_due": true})
	var amb := ws.find_child("AmbulanceInterception", true, false) as AmbulanceInterception
	amb.armed = true
	await _dream()
	check("not with the ambulance armed", not _mem.is_confessing)
	amb.armed = false
	amb.interception_delay = 999.0
	await _home()

	section("the visions: the meaning stays")
	var dv := ws.find_child("DualVisionController", true, false) as DualVisionController
	var seen: Array[String] = []
	dv.valley_phase_active.connect(
		func(on: bool):
			if on:
				seen.append.call_deferred(_text.shown)
	)
	dv.start_visions()
	await dv.visions_ended
	await process_frame
	var whole := "%s %s" % DreamMemoryScript.FRAGMENTS[0]
	check('the first lost sentence, whole ("%s")' % whole, seen.has(whole))
	check("every lost sentence comes back", seen.has("%s %s" % DreamMemoryScript.FRAGMENTS[2]))

	section("a save, a renewal")
	var snap := _mem.snapshot()
	_mem.restore({})
	_mem.restore(snap)
	check("the save keeps it", _mem.lost == [0, 1, 2] and _mem.confession_due)
	var persistence := ws.find_child("Persistence", true, false) as Persistence
	check("in the save file", persistence.snapshot().has("dream_memory"))
	_mem.reset_cycle()
	check(
		"renewed: he can confess again; what he lost stays lost",
		not _mem.confessed and _mem.lost_this_cycle == 0 and _mem.lost.size() == 3
	)
	Engine.time_scale = 1.0


func _calm() -> void:
	_sm.state_data.chemical_level = 0.8
	_sm.state_data.sensory_overload = 0.0


func _dream() -> void:
	_calm()
	_dm.transition_to_dreamscape()
	await _dm.transition_completed
	_calm()


func _home() -> void:
	_dm.return_to_workspace()
	await _dm.transition_completed
	_calm()
