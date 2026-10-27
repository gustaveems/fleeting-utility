extends "res://tools/lib/verify_harness.gd"
## Ticket-18 probe: the promises. Focus+ calls on day 3 with Pro (after the friend);
## declined, it asks again on day 5; the trial slows the drug; three days in the "month"
## is over and both ways out cost (keep: the lease's decay rate; cancel: a tolerance worse
## than before); the wall screen follows each step; it all survives a save and a renewed
## lease keeps the scar. Dialogue runs at 10x.
##
## Run: godot --headless --path . -s tools/probe_promises.gd

const SPEED := 10.0

var _p: Promises
var _days: DayCycle
var _runner: DialogueRunner
var _screen: AdScreen


func _title() -> String:
	return "PROMISES PROBE"


func _run() -> void:
	_p = ws.find_child("Promises", true, false) as Promises
	_days = ws.find_child("DayCycle", true, false) as DayCycle
	_runner = ws.find_child("DialogueRunner", true, false) as DialogueRunner
	_screen = ws.find_child("AdScreen", true, false) as AdScreen
	var act := ws.find_child("ActOne", true, false) as ActOne
	var hc := ws.find_child("HeadCall", true, false) as HeadCall
	check("promises are wired", _p != null and _days != null and _screen != null)
	if _p == null or _screen == null:
		return
	var data := _p.state_data
	_p.care = "enrolled"  # Corporate Care has its own probe; keep its offer out of here
	var base := data.chemical_depletion_rate
	check("the wall screen sells the brand", PromisesScript.SCREEN_IDLE.has(_screen.headline))
	check(
		"the screen hangs in the room",
		_screen.get_parent() == ws.find_child("Apartment", true, false)
	)
	Engine.time_scale = SPEED

	section("day 2: nothing yet")
	await _morning(2, [])
	check("no offer before day 3", _p.pro == "" and not _runner.choices.has("pro"))

	section("day 3: the offer, after the friend")
	var callers: Array[String] = []
	hc.line_shown.connect(
		func(_i: int):
			if hc.get_child(0).visible:
				callers.append(str(hc._caller.text))
	)
	await _morning(3, [1, 1])  # the friend's co-sign: ask; Pro: not now
	check(
		"the friend called first, then Focus+ (a head call)",
		(
			callers.has(NightZeroScript.FRIEND)
			and callers.has(ActOneScript.FOCUS_CARE)
			and callers.find(NightZeroScript.FRIEND) < callers.find(ActOneScript.FOCUS_CARE)
		)
	)
	check("declined", _p.pro == "declined" and data.chemical_depletion_rate == base)
	check("the screen keeps pitching", _screen.headline.begins_with("FOCUS+ PRO\nStill free"))
	check("the corporation's choice isn't a favour", not act.favours.has("pro"))

	section("day 5: it asks again; the trial")
	await _morning(4, [1])  # the friend's crate: no
	check("no offer on day 4", _p.pro == "declined")
	await _morning(5, [0])
	check("accepted the second time", _p.pro == "trial" and _p.pro_day == 5)
	check(
		"the drug wears off slower (%.4f → %.4f)" % [base, data.chemical_depletion_rate],
		is_equal_approx(data.chemical_depletion_rate, base * Promises.PRO_SCALE)
	)
	check("the screen: free until day 8", _screen.headline.ends_with("Free until day 8"))

	section("a save mid-trial")
	var snap := _p.snapshot()
	_p.restore({})
	check("a fresh game has the base rate", is_equal_approx(data.chemical_depletion_rate, base))
	_p.restore(snap)
	check(
		"the trial survives a save",
		_p.pro == "trial" and is_equal_approx(data.chemical_depletion_rate, base * 0.75)
	)
	var persistence := ws.find_child("Persistence", true, false) as Persistence
	check("the save carries it", persistence.snapshot().get("promises", {}) == snap)

	section("day 8: the month is over (cancel)")
	await _morning(7, [])
	check("not due on day 7", _p.pro == "trial")
	await _morning(8, [1])
	check(
		"cancelled: worse than before Pro (%.4f)" % data.chemical_depletion_rate,
		(
			_p.pro == "cancelled"
			and is_equal_approx(data.chemical_depletion_rate, base * Promises.CANCELLED_SCALE)
		)
	)
	check("the screen misses him", _screen.headline.begins_with("WE MISS YOU"))
	check("nothing more to offer", _p.due_call(9).is_empty())

	section("the other way out (keep)")
	_p.restore({"pro": "trial", "pro_day": 2, "depletion_scale": Promises.PRO_SCALE})
	var rate := _p.entropy_data.entropy_growth_rate
	await _morning(5, [0])
	check(
		"kept: billed to the lease (decay ×%.2f)" % (_p.entropy_data.entropy_growth_rate / rate),
		(
			_p.pro == "kept"
			and is_equal_approx(_p.entropy_data.entropy_growth_rate, rate * Promises.BILLED_RATE)
		)
	)
	check(
		"and he keeps the slower dose",
		is_equal_approx(data.chemical_depletion_rate, base * Promises.PRO_SCALE)
	)

	section("a renewed lease")
	_p.reset_cycle()
	check(
		"the scar stays",
		_p.pro == "kept" and is_equal_approx(data.chemical_depletion_rate, base * 0.75)
	)
	_p.restore({"pro": "refused", "depletion_scale": 1.0})
	_p.reset_cycle()
	check("a refused offer comes round again", _p.pro == "" and not _p.due_call(3).is_empty())
	Engine.time_scale = 1.0


## Wake on `day`, answer choices with `picks` in order, wait for all talk to end.
func _morning(day: int, picks: Array) -> void:
	_days.restore(day)
	_days.morning.emit(day)
	await wait(Promises.CALL_DELAY + 0.5)
	var i := 0
	for n in 4000:
		if _runner.awaiting_choice and i < picks.size():
			_runner.choices_ui.choose(int(picks[i]))
			i += 1
		if _runner.is_idle() and not _p.calling:
			return
		await process_frame
