extends "res://tools/lib/verify_harness.gd"
## Ticket-19 probe: self-belief, hidden and felt. Relapses erode it and bring the next
## compulsion sooner; off the drug the easel is slower and harsher as it falls, and at the
## bottom he won't paint without it (on the drug he always will); a canvas finished off
## the drug gives a little back; the neighbour, then the friend, notice; it survives a
## save; a renewed lease restores some, less each cycle.
##
## Run: godot --headless --path . -s tools/probe_self_belief.gd

var _b: SelfBelief
var _easel: Easel
var _data: PlayerStateData
var _runner: DialogueRunner
var _days: DayCycle


func _title() -> String:
	return "SELF-BELIEF PROBE"


func _run() -> void:
	_b = ws.find_child("SelfBelief", true, false) as SelfBelief
	_easel = ws.find_child("Easel", true, false) as Easel
	_runner = ws.find_child("DialogueRunner", true, false) as DialogueRunner
	_days = ws.find_child("DayCycle", true, false) as DayCycle
	var soothing := ws.find_child("SelfSoothingController", true, false) as SelfSoothingController
	check("self-belief is wired", _b != null and _easel != null and _easel.self_belief == _b)
	if _b == null:
		return
	_data = _b.state_data
	(ws.find_child("Promises", true, false) as Promises).pro = "refused"  # no offers here

	section("Day 1: sure")
	check("it starts whole", _b.value == SelfBelief.START and _b.stage() == 0)
	check("the easel says paint", _b.paint_prompt() == "[E] Hold to paint")
	check("relapses at 80", is_equal_approx(soothing.compulsion_threshold, 80.0))
	_off_drug()
	var sure_time := _easel._paint_seconds()

	section("relapses erode it")
	for i in 3:
		soothing._enter_compulsion()
		await process_frame
		soothing._exit_compulsion()
		await process_frame
	check(
		"three relapses (%.2f)" % _b.value,
		_b.relapses == 3 and is_equal_approx(_b.value, 1.0 - 3 * SelfBelief.RELAPSE_COST)
	)
	check("doubting: the easel says try", _b.stage() == 1 and _b.paint_prompt().contains("try"))
	check(
		"the next relapse comes sooner (threshold %.1f)" % soothing.compulsion_threshold,
		soothing.compulsion_threshold < 80.0 and soothing.compulsion_threshold > 65.0
	)

	section("off the drug, the easel feels it")
	_off_drug()
	check(
		"slower hands (%.1f s → %.1f s)" % [sure_time, _easel._paint_seconds()],
		_easel._paint_seconds() > sure_time * 1.3
	)
	check("a harsher verdict", _b.verdict_penalty() > 0.1)
	_on_drug()
	check(
		"on the drug he is sharp: untouched",
		(
			is_equal_approx(_easel._paint_seconds(), Easel.BASE_PAINT_SECONDS)
			and _b.verdict_penalty() == 0.0
		)
	)

	section("a canvas finished off the drug gives a little back")
	var before := _b.value
	_off_drug()
	_easel.work_finished.emit(Easel.VERDICT_LOW)
	check("+%.2f" % (_b.value - before), is_equal_approx(_b.value, before + 0.05))
	before = _b.value
	_on_drug()
	_easel.work_finished.emit(Easel.VERDICT_MID)
	check("one finished on the drug gives nothing", _b.value == before)

	section("people notice")
	await _morning(9)
	check("the neighbour hears it first", _b.said.has("tired") and not _b.said.has("flat"))
	_b.set_value(0.1)
	var callers: Array[String] = []
	var hc := ws.find_child("HeadCall", true, false) as HeadCall
	hc.line_shown.connect(
		func(_i: int):
			if hc.get_child(0).visible:
				callers.append(str(hc._caller.text))
	)
	await _morning(10)
	check("hollow: the friend calls", _b.said.has("flat") and callers.has(NightZeroScript.FRIEND))

	section("the bottom: not without it")
	check("relapses at 66.5 now", soothing.compulsion_threshold < 67.0)
	_off_drug()
	check("he won't paint off the drug", not _easel.can_interact())
	check("and says so", _easel.blocked_prompt() == SelfBeliefScript.REFUSE)
	_on_drug()
	check("on the drug he will", _easel.can_interact())

	section("a save, and a renewed lease")
	var snap := _b.snapshot()
	_b.restore({})
	check("a fresh game is whole", _b.value == SelfBelief.START)
	_b.restore(snap)
	check(
		"the save keeps it",
		is_equal_approx(_b.value, 0.1) and _b.relapses == 3 and _b.said.has("flat")
	)
	var persistence := ws.find_child("Persistence", true, false) as Persistence
	check("in the save file", persistence.snapshot().has("self_belief"))
	_b.reset_cycle()
	check("renewed: some of it back", is_equal_approx(_b.value, 1.0 - SelfBelief.CYCLE_SCAR))
	_b.reset_cycle()
	check("less each cycle", is_equal_approx(_b.value, 1.0 - 2 * SelfBelief.CYCLE_SCAR))
	check("people can notice again", _b.said.is_empty())


func _off_drug() -> void:
	_data.chemical_level = 0.1
	_data.sensory_overload = 0.0


func _on_drug() -> void:
	_data.chemical_level = 0.5
	_data.sensory_overload = 0.0


func _morning(day: int) -> void:
	Engine.time_scale = 10.0
	_days.restore(day)
	_days.morning.emit(day)
	await wait(SelfBelief.NOTICE_DELAY + 0.5)
	for n in 3000:
		if _runner.is_idle():
			break
		await process_frame
	Engine.time_scale = 1.0
