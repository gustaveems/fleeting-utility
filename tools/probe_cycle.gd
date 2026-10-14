extends "res://tools/lib/verify_harness.gd"
## The end of the arc (playtest 2026-10-14: after the scarred reset the player was left
## in a dead, dark room forever). Each reset now ends on an EndCard:
##   Renew the lease  → a new cycle; every beat re-armed, scars escalate
##   Walk away        → epilogue, save cleared, back to the main menu
##
## Run: godot --headless --path . -s tools/probe_cycle.gd

var _base_rate: float


func _title() -> String:
	return "CYCLE PROBE"


func _run() -> void:
	_base_rate = (node("PlayerStateMachine") as PlayerStateMachine).entropy_data.entropy_growth_rate

	section("the reset ends on a card")
	await _play_to_scarred()
	var card := node("EndCard") as EndCard
	check("end card present", card != null)
	if card == null:
		return
	await wait(0.5)
	check("card shown after the reset", card.is_open)
	check("the world is paused behind it", paused)

	section("renew the lease: a new, more scarred cycle")
	card.renew()
	await wait(0.3)
	var flow := node("GameFlow") as GameFlow
	var sm := node("PlayerStateMachine") as PlayerStateMachine
	check("card closed, world running", not card.is_open and not paused)
	check("back to WORKSPACE", flow.phase == GameFlow.Phase.WORKSPACE)
	check("cycle counted", flow.loops_completed == 1)
	var bench := node("Apartment/BenchArea/CraftingBench")
	check("bench back and solid", live_shapes(bench) > 0 and (bench as Node3D).is_visible_in_tree())
	check("smaller stash (%d compounds)" % _compounds(), _compounds() == 2)
	check(
		"interactions unlocked",
		not (node("InteractionController") as InteractionController).is_locked
	)
	check("dreams possible again", not sm.is_climax_latched())
	check("ambulance disarmed", not (node("AmbulanceInterception") as AmbulanceInterception).armed)
	check("walk available", not (node("CorporateParkManager") as CorporateParkManager).walk_taken)
	check("wreck cleared", _debris_count() == 0 and node("Apartment/LuxuryShoes") == null)
	check(
		"hesitation re-armed",
		not (node("HesitationController") as HesitationController).has_hesitated
	)
	var atmo := node("Apartment/AtmosphereController") as AtmosphereController
	check(
		"normal lighting",
		not atmo.is_subdued_mode() and not atmo.is_broken_mode() and not atmo.is_clinical_mode()
	)
	check("no withdrawal jitter", not (node("Player") as PlayerMovement).is_in_withdrawal)
	check(
		"full sight again", is_equal_approx((node("ScreenEffects") as ScreenEffects).lucid_cap, 1.0)
	)
	var anchors_live := 0
	for a in (node("DreamscapeValley") as DreamscapeEnvironment).memory_anchors:
		if a.monitoring and not (node("DreamscapeValley") as WorldRoot).is_suppressed(a):
			anchors_live += 1
	check("memory anchors unsealed (%d)" % anchors_live, anchors_live == 3)
	check(
		"entropy grows faster (x%.2f)" % (sm.entropy_data.entropy_growth_rate / _base_rate),
		is_equal_approx(sm.entropy_data.entropy_growth_rate, _base_rate * 1.5)
	)
	check(
		"room starts more decayed (%.0f)" % sm.entropy_data.entropy, sm.entropy_data.entropy > 45.0
	)
	check(
		"medicated again",
		sm.state_data.chemical_level > 0.4 and sm.state_data.sensory_overload < 1.0
	)

	section("the new cycle survives a reload")
	check("saved at the new checkpoint", Persistence.save_exists())
	await reboot()
	flow = node("GameFlow") as GameFlow
	check(
		"still cycle 1 in WORKSPACE",
		flow.loops_completed == 1 and flow.phase == GameFlow.Phase.WORKSPACE
	)
	check("no card on a WORKSPACE load", not (node("EndCard") as EndCard).is_open)

	section("second reset escalates again; walking away ends the story")
	await _play_to_scarred()
	card = node("EndCard") as EndCard
	await wait(0.5)
	check("card again", card.is_open)
	check(
		"renewing would compound the scar (x%.2f)" % (card.renew_preview_rate() / _base_rate),
		is_equal_approx(card.renew_preview_rate(), _base_rate * 1.5 * 1.5)
	)
	card.walk_away()
	for i in 80:
		await wait(0.1)
		if current_scene != null and current_scene.name == "Boot":
			break
	check("back at the main menu", current_scene != null and current_scene.name == "Boot")
	check("story over: save cleared", not Persistence.save_exists())
	check("unpaused", not paused)


func _play_to_scarred() -> void:
	var dm := node("DreamscapeManager") as DreamscapeManager
	var ambulance := node("AmbulanceInterception") as AmbulanceInterception
	var endgame := node("EndgameLoopManager") as EndgameLoopManager
	var card := node("EndCard") as EndCard
	if card != null:
		card.show_delay = 0.2
		card.epilogue_seconds = 0.3
	ambulance.interception_delay = 0.5
	ambulance.escalation_seconds = 0.5
	endgame.clinical_pause_seconds = 0.3
	dm.auto_return_seconds = 999.0
	ambulance.arm()
	await dm.transition_to_dreamscape()
	await endgame.loop_reset


func _compounds() -> int:
	var grid := node("Apartment/BenchArea/SpatialGrid") as SpatialGrid
	var n := 0
	for x in grid.grid_width:
		for y in grid.grid_depth:
			var item := grid.get_item_at(Vector2i(x, y))
			if item is InventoryItem and (item as InventoryItem).item_id == &"raw_compound":
				n += 1
	return n


func _debris_count() -> int:
	var n := 0
	for child in node("Apartment").get_children():
		if child.name.begins_with("Debris"):
			n += 1
	return n
