extends "res://tools/lib/verify_harness.gd"
## Playtest 2026-10-30: "as a completely new player you feel quite lost". The line under
## the meters says what he could do next, from the systems' state, and keeps quiet while
## anything else talks.
##
## Run: godot --headless --path . -s tools/probe_next_step.gd


func _title() -> String:
	return "NEXT STEP PROBE"


func _run() -> void:
	section("the policy")
	var s := NextStepHint.suggest
	check("quiet while something else talks", s.call({"busy": true, "crashed": true}) == "")
	check("the dream first", s.call({"in_dream": true}) == NextStepHint.HINT_DREAM)
	check(
		"overloaded with a pill waiting: take it",
		s.call({"crashed": true, "pill_ready": true}) == NextStepHint.HINT_CRASH_PILL
	)
	check(
		"overloaded, nothing to take: the metro",
		s.call({"crashed": true, "metro": true}) == NextStepHint.HINT_CRASH_METRO
	)
	check(
		"wearing off: cook",
		s.call({"chemical": 0.2, "can_cook": true, "painted_today": true}) == NextStepHint.HINT_LOW
	)
	check("a new day: paint", s.call({"chemical": 0.9}) == NextStepHint.HINT_PAINT)
	check(
		"painted: sleep",
		s.call({"chemical": 0.9, "painted_today": true}) == NextStepHint.HINT_SLEEP
	)
	check(
		"the betrayal threshold: the door",
		s.call({"unbearable": true, "invited": true}) == NextStepHint.HINT_UNBEARABLE
	)

	section("in the game")
	var hint := node("NextStepHint") as NextStepHint
	check("the hint is on the HUD", hint != null)
	if hint == null:
		return
	var sm := node("PlayerStateMachine") as PlayerStateMachine
	sm.state_data.chemical_level = 0.9
	sm.state_data.sensory_overload = 0.0
	var dialogue := node("DialogueRunner") as DialogueRunner
	dialogue.clear_queue()
	if dialogue.is_running:
		dialogue.cancel()
	await wait(1.0)
	var label := hint.find_child("NextStep", true, false) as Label
	check("it shows a step (%s)" % label.text, label.text.begins_with("NEXT"))
	# Crashed, short of a compulsion (which has its own prompt, and the hint keeps quiet).
	sm.state_data.sensory_overload = 55.0
	sm.state_data.chemical_level = 0.5
	await wait(0.7)
	check("and changes when he crashes (%s)" % label.text, label.text.contains("overloaded"))
