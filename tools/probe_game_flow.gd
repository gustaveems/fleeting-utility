extends "res://tools/lib/verify_harness.gd"
## Narrative-arc probe (MASTER_BRIEF order): drive every transition and assert the phase
## sequence GameFlow publishes, plus the gates that keep the arc in order.
##
##   calm collapse dreams (no ambulance) → walk → ransacked → (calm dreams) →
##   hesitation + dual visions (arms the climax) → collapse dream → ambulance →
##   clinical → scarred reset
##
## Run: godot --headless --path . -s tools/probe_game_flow.gd

var _seen: Array[String] = []
var _intercepted := 0


func _title() -> String:
	return "GAME FLOW PROBE"


func _run() -> void:
	var flow := node("GameFlow") as GameFlow
	var dm := node("DreamscapeManager") as DreamscapeManager
	var sm := node("PlayerStateMachine") as PlayerStateMachine
	var park := node("CorporateParkManager") as CorporateParkManager
	var hesitation := node("HesitationController") as HesitationController
	var visions := node("DualVisionController") as DualVisionController
	var ambulance := node("AmbulanceInterception") as AmbulanceInterception
	var endgame := node("EndgameLoopManager") as EndgameLoopManager
	check("GameFlow present", flow != null)
	if flow == null:
		return
	flow.phase_changed.connect(
		func(_from: GameFlow.Phase, to: GameFlow.Phase): _seen.append(GameFlow.Phase.keys()[to])
	)
	ambulance.interception_started.connect(func(): _intercepted += 1)
	ambulance.interception_delay = 1.0
	ambulance.escalation_seconds = 0.5
	endgame.clinical_pause_seconds = 0.5
	dm.auto_return_seconds = 2.0
	check("boots in WORKSPACE", flow.phase == GameFlow.Phase.WORKSPACE)
	check("ambulance starts disarmed", not ambulance.armed)

	section("early collapses are calm dreams, and can recur")
	await _collapse_into_dream(sm, dm)
	check("collapse -> DREAMSCAPE", flow.phase == GameFlow.Phase.DREAMSCAPE)
	await dm.transition_completed  # auto-return after 2 s
	check("calm return -> WORKSPACE", flow.phase == GameFlow.Phase.WORKSPACE)
	check("no ambulance in an early dream", _intercepted == 0)
	await _collapse_into_dream(sm, dm)
	check("a second collapse still dreams", dm.in_dreamscape())
	await dm.transition_completed
	_settle_meters(sm)

	section("walk and betrayal")
	park.transition_to_park()
	check("PARK_WALK", flow.phase == GameFlow.Phase.PARK_WALK)
	park.transition_to_apartment()
	check("RANSACKED", flow.phase == GameFlow.Phase.RANSACKED)
	check("the walk is spent for this cycle", park.walk_taken)

	section("forced detox: a calm dream returns to the ruined room")
	await _collapse_into_dream(sm, dm)
	await dm.transition_completed
	check("calm return -> RANSACKED", flow.phase == GameFlow.Phase.RANSACKED)
	check("still no ambulance", _intercepted == 0)
	_settle_meters(sm)

	section("hesitation and dual visions arm the climax")
	hesitation.initiate_hesitation()
	check("HESITATION", flow.phase == GameFlow.Phase.HESITATION)
	await visions.visions_ended
	check("visions end -> RANSACKED", flow.phase == GameFlow.Phase.RANSACKED)
	check("ambulance armed", ambulance.armed)

	section("the climax")
	await _collapse_into_dream(sm, dm)
	await dm.forced_return_completed
	check("ambulance intercepted exactly once", _intercepted == 1)
	check("CLINICAL after the forced return", flow.phase == GameFlow.Phase.CLINICAL)
	await endgame.loop_reset
	check("SCARRED after the loop reset", flow.phase == GameFlow.Phase.SCARRED)
	check("one loop completed", flow.loops_completed == 1)
	check("ambulance disarmed after firing", not ambulance.armed)

	var expected: Array[String] = [
		"DREAMSCAPE",
		"WORKSPACE",
		"DREAMSCAPE",
		"WORKSPACE",
		"PARK_WALK",
		"RANSACKED",
		"DREAMSCAPE",
		"RANSACKED",
		"HESITATION",
		"RANSACKED",
		"DREAMSCAPE",
		"INTERCEPTION",
		"CLINICAL",
		"SCARRED",
	]
	check("exact phase sequence %s" % str(_seen), _seen == expected)
	check("snapshot carries phase", flow.snapshot().get("phase") == "SCARRED")


## Pin the meters at the knockout condition; the state machine triggers the dream.
## The collapse is a rising-edge trigger, so the meter must first sit below the pin
## (in play, soothing a compulsion does this) before pinning it re-arms.
func _collapse_into_dream(sm: PlayerStateMachine, dm: DreamscapeManager) -> void:
	sm.state_data.chemical_level = 0.0
	sm.state_data.sensory_overload = 0.0
	await wait(0.1)
	sm.state_data.sensory_overload = 100.0
	await dm.transition_completed


## Calm the meters so no compulsion or collapse fires mid-section.
func _settle_meters(sm: PlayerStateMachine) -> void:
	sm.state_data.chemical_level = 0.6
	sm.state_data.sensory_overload = 0.0
