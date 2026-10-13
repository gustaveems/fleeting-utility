extends "res://tools/lib/verify_harness.gd"
## Playtest regressions (2026-10-14): the first real playthrough was a loop. The drug
## could not be obtained, a compulsion re-fired within a second of ending, E gave no
## feedback, and the window beat had no window. Each section is one of those reports.
##
## Run: godot --headless --path . -s tools/probe_playability.gd

var _prompt: String = ""


func _title() -> String:
	return "PLAYABILITY PROBE"


func _run() -> void:
	var ic := node("InteractionController") as InteractionController
	ic.target_detected.connect(func(p: String): _prompt = p)
	ic.target_lost.connect(func(): _prompt = "")
	var sm := node("PlayerStateMachine") as PlayerStateMachine
	var data := sm.state_data
	var player := node("Player") as PlayerMovement

	section("the drug can be cooked and taken at the bench")
	var station := node("Apartment/BenchArea/CraftingBench/BenchStation") as Interactable
	check("bench has an interaction zone", station != null)
	if station == null:
		return
	data.chemical_level = 0.35
	data.sensory_overload = 0.0
	await _walk_to(player, station.global_position)
	check("cook prompt (got '%s')" % _prompt, _prompt.begins_with("[E] Cook"))
	check("cooking starts", station.try_interact())
	await wait(0.2)
	check("busy status while cooking (got '%s')" % _prompt, _prompt.contains("Cooking"))
	await wait(4.5)
	check("take prompt once cooked (got '%s')" % _prompt, _prompt.begins_with("[E] Take"))
	var before := data.chemical_level
	check("taking the pill", station.try_interact())
	check(
		"a dose raises the chemical (%.2f -> %.2f)" % [before, data.chemical_level],
		data.chemical_level > before + 0.4
	)
	station.try_interact()  # cook the second dose
	await wait(4.5)
	station.try_interact()  # take it
	await wait(0.2)
	check("supply runs out (got '%s')" % _prompt, _prompt.contains("Nothing left"))

	section("a soothed compulsion buys a window to act")
	var soothing := node("SelfSoothingController") as SelfSoothingController
	await _walk_to(player, Vector3.ZERO)
	data.chemical_level = 0.0
	data.sensory_overload = 90.0
	await wait(0.2)
	check("compulsion fires in withdrawal", soothing.is_in_compulsion())
	check("compulsion tells you what to do (got '%s')" % _prompt, _prompt.contains("Soothe"))
	data.sensory_overload = 45.0  # soothed below the recovery threshold
	await wait(0.2)
	check("compulsion ended", not soothing.is_in_compulsion())
	await wait(5.0)
	check(
		"no relapse within 5 s (overload %.0f)" % data.sensory_overload,
		not soothing.is_in_compulsion()
	)
	check("free to move in the window", not player.input_locked)

	section("the door explains itself")
	var entropy := sm.entropy_data
	entropy.entropy = 40.0
	await _walk_to(player, Vector3(0.0, 0.0, -3.0))
	check("'not yet' below the threshold (got '%s')" % _prompt, _prompt.contains("Not yet"))
	entropy.entropy = 75.0
	await wait(0.3)
	check("go-outside prompt at the threshold (got '%s')" % _prompt, _prompt == "[E] Go Outside")

	section("the betrayal is seen through the window")
	var park := node("CorporateParkManager") as CorporateParkManager
	park.transition_to_park()
	park.transition_to_apartment()
	var shoes := node("Apartment/LuxuryShoes") as LuxuryShoes
	check(
		"shoes are OUTSIDE, past the window wall (z %.1f)" % shoes.global_position.z,
		shoes.global_position.z < -3.6
	)
	var window := shoes.get_node("ProximityArea") as Interactable
	await _walk_to(player, Vector3(window.global_position.x, 0.0, -2.9))
	check("window prompt (got '%s')" % _prompt, _prompt == "[E] Look out the window")
	check("looking realizes the betrayal", window.try_interact() and shoes.is_realized())

	section("Continue from a withdrawn save wakes calm")
	data.chemical_level = 0.0
	data.sensory_overload = 100.0
	(node("Persistence") as Persistence).save_game()
	await reboot()
	await wait(3.0)
	var soothing2 := node("SelfSoothingController") as SelfSoothingController
	check("no compulsion on waking", not soothing2.is_in_compulsion())
	check(
		"not straight back into a dream",
		not (node("DreamscapeManager") as DreamscapeManager).in_dreamscape()
	)


func _walk_to(player: PlayerMovement, at: Vector3) -> void:
	var ext := player.room_half_extents
	player.global_position = Vector3(clampf(at.x, -ext.x, ext.x), 0.0, clampf(at.z, -ext.y, ext.y))
	await wait(0.3)
