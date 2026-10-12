extends "res://tools/lib/verify_harness.gd"
## GameFlow arc probe: drive every narrative transition through the managers' public
## APIs and assert the phase sequence GameFlow publishes.
##
## Run: godot --headless --path . -s tools/probe_game_flow.gd

var _seen: Array[String] = []


func _title() -> String:
	return "GAME FLOW PROBE"


func _run() -> void:
	var flow := node("GameFlow") as GameFlow
	var dm := node("DreamscapeManager") as DreamscapeManager
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
	check("boots in WORKSPACE", flow.phase == GameFlow.Phase.WORKSPACE)

	section("calm dream and return")
	ambulance.interception_delay = 999.0  # keep the climax out of the calm dream
	await dm.transition_to_dreamscape()
	check("DREAMSCAPE", flow.phase == GameFlow.Phase.DREAMSCAPE)
	await dm.return_to_workspace()
	check("back to WORKSPACE", flow.phase == GameFlow.Phase.WORKSPACE)

	section("walk, betrayal, hesitation")
	park.transition_to_park()
	check("PARK_WALK", flow.phase == GameFlow.Phase.PARK_WALK)
	park.transition_to_apartment()
	check("RANSACKED", flow.phase == GameFlow.Phase.RANSACKED)
	hesitation.initiate_hesitation()
	check("HESITATION", flow.phase == GameFlow.Phase.HESITATION)
	await visions.visions_ended
	check("visions end -> RANSACKED", flow.phase == GameFlow.Phase.RANSACKED)

	section("climax and scarred reset")
	ambulance.interception_delay = 1.0
	ambulance.escalation_seconds = 0.5
	endgame.clinical_pause_seconds = 0.5
	await dm.transition_to_dreamscape()
	await dm.forced_return_completed
	check("CLINICAL after the forced return", flow.phase == GameFlow.Phase.CLINICAL)
	await endgame.loop_reset
	check("SCARRED after the loop reset", flow.phase == GameFlow.Phase.SCARRED)
	check("one loop completed", flow.loops_completed == 1)

	var expected: Array[String] = [
		"DREAMSCAPE",
		"WORKSPACE",
		"PARK_WALK",
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
