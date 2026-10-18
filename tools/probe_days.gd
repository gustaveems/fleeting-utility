extends "res://tools/lib/verify_harness.gd"
## Ticket-14 probe: days (sleep → night dream → morning, the lease reclaims his works)
## and mastery in vain (hold E to paint, the canvas paints his state, a verdict that is
## never satisfied, skill that rises but buys nothing lasting).
##
## Run: godot --headless --path . -s tools/probe_days.gd

var _prompt: String = ""


func _title() -> String:
	return "DAYS PROBE"


func _run() -> void:
	var ic := node("InteractionController") as InteractionController
	ic.target_detected.connect(func(p: String): _prompt = p)
	ic.target_lost.connect(func(): _prompt = "")
	var days := node("DayCycle") as DayCycle
	var easel := node("Apartment/Easel") as Easel
	var cot := node("Apartment/Cot") as Interactable
	var sm := node("PlayerStateMachine") as PlayerStateMachine
	var data := sm.state_data
	var player := node("Player") as PlayerMovement
	var hud := node("CoreHud/HudUI") as HudUI
	check("day cycle, easel and cot exist", days != null and easel != null and cot != null)
	if days == null or easel == null or cot == null:
		return
	check("Day 1", days.day == 1)
	check("HUD shows the day (got '%s')" % hud.day_text(), hud.day_text() == "DAY 1")
	(node("DreamscapeManager") as DreamscapeManager).auto_return_seconds = 1.0

	section("painting: hold E, the canvas paints his state")
	data.chemical_level = 0.5
	data.sensory_overload = 0.0
	await _walk_to(player, easel.global_position)
	check("easel prompt (got '%s')" % _prompt, _prompt == "[E] Hold to paint")
	var skill_before := easel.skill
	Input.action_press(InputActionData.ACTION_INTERACT)
	await wait(1.0)
	check("progress shown while holding (got '%s')" % _prompt, _prompt.begins_with("Painting"))
	Input.action_release(InputActionData.ACTION_INTERACT)
	var paused_at := easel.progress
	await wait(0.6)
	check("releasing pauses the work", is_equal_approx(easel.progress, paused_at))
	Input.action_press(InputActionData.ACTION_INTERACT)
	await wait(3.6)
	Input.action_release(InputActionData.ACTION_INTERACT)
	await wait(0.1)
	check("a finished work hangs on the wall", easel.hung_works().size() == 1)
	var verdict := hud.displayed_line()
	check("a verdict, never satisfied (got '%s')" % verdict, Easel.VERDICTS.has(verdict))
	check("skill rises", easel.skill > skill_before)

	section("High-Focus paints faster")
	data.chemical_level = 0.95
	Input.action_press(InputActionData.ACTION_INTERACT)
	await wait(2.4)
	Input.action_release(InputActionData.ACTION_INTERACT)
	await wait(0.1)
	check("High-Focus work done in ~2 s", easel.hung_works().size() == 2)
	var works := easel.hung_works()
	check("each work is its own canvas", works[0].seed_value != works[1].seed_value)

	section("the wall is finite")
	Input.action_press(InputActionData.ACTION_INTERACT)
	await wait(2.4)
	Input.action_release(InputActionData.ACTION_INTERACT)
	await wait(0.2)
	check("three works", easel.hung_works().size() == 3)
	check("full-wall message (got '%s')" % _prompt, _prompt.contains("No more wall"))

	section("a compulsion takes the brush away")
	(node("SelfSoothingController") as SelfSoothingController)._enter_compulsion()
	check("painting refused while compelled", not easel.can_interact())
	(node("SelfSoothingController") as SelfSoothingController)._exit_compulsion()

	section("the works survive a reload (within the day)")
	data.chemical_level = 0.5
	(node("Persistence") as Persistence).save_game()
	var seeds := []
	for w in easel.hung_works():
		seeds.append(w.seed_value)
	var skill := easel.skill
	await reboot()
	easel = node("Apartment/Easel") as Easel
	days = node("DayCycle") as DayCycle
	cot = node("Apartment/Cot") as Interactable
	player = node("Player") as PlayerMovement
	ic = node("InteractionController") as InteractionController
	ic.target_detected.connect(func(p: String): _prompt = p)
	ic.target_lost.connect(func(): _prompt = "")
	hud = node("CoreHud/HudUI") as HudUI
	var seeds_after := []
	for w in easel.hung_works():
		seeds_after.append(w.seed_value)
	check("same works on the wall", seeds_after == seeds)
	check("skill kept", is_equal_approx(easel.skill, skill))

	section("sleep: night, then morning; the lease reclaims")
	(node("DreamscapeManager") as DreamscapeManager).auto_return_seconds = 1.0
	await _walk_to(player, cot.global_position)
	check("cot prompt (got '%s')" % _prompt, _prompt == "[E] Sleep")
	check("sleeping", cot.try_interact())
	var dm := node("DreamscapeManager") as DreamscapeManager
	await dm.transition_completed  # into the night dream
	check("night is a dream", dm.in_dreamscape())
	await dm.transition_completed  # morning
	await wait(0.2)
	check("Day 2", days.day == 2)
	check("HUD shows the new day", hud.day_text() == "DAY 2")
	check("works reclaimed overnight", easel.hung_works().is_empty())
	check(
		"the lease says so (got '%s')" % hud.displayed_line(),
		hud.displayed_line().contains("lease")
	)
	var morning := (node("PlayerStateMachine") as PlayerStateMachine).state_data
	check(
		"wakes gently (overload %.0f)" % morning.sensory_overload, morning.sensory_overload <= 15.0
	)
	check("skill outlives the works", is_equal_approx(easel.skill, skill))

	section("a collapse dream is not a night")
	morning.chemical_level = 0.0
	morning.sensory_overload = 0.0
	morning.relief_seconds = 0.0
	await wait(0.1)
	morning.sensory_overload = 100.0
	await dm.transition_completed
	await dm.transition_completed
	check("still Day 2 after a collapse", days.day == 2)

	section("a renewed lease starts at Day 1")
	(node("LeaseRenewal") as LeaseRenewal).renew()
	check("Day 1 again", days.day == 1)
	check("skill is his to keep", is_equal_approx(easel.skill, skill))


func _walk_to(player: PlayerMovement, at: Vector3) -> void:
	var ext := player.room_half_extents
	player.global_position = Vector3(clampf(at.x, -ext.x, ext.x), 0.0, clampf(at.z, -ext.y, ext.y))
	await wait(0.3)
