extends "res://tools/lib/verify_harness.gd"
## Interactable probe: prompts and gates for the door, the park return door and the
## luxury shoes, driven by real physics overlap (walk the player in) and try_interact().
##
## Run: godot --headless --path . -s tools/probe_interactables.gd

var _prompt: String = ""


func _title() -> String:
	return "INTERACTABLES PROBE"


func _run() -> void:
	var player := node("Player") as PlayerMovement
	var ic := node("InteractionController") as InteractionController
	var door := node("Apartment/ApartmentDoor") as ApartmentDoor
	var park := node("CorporateParkManager") as CorporateParkManager
	var ransacked := node("RansackedStateManager") as RansackedStateManager
	var entropy := (node("PlayerStateMachine") as PlayerStateMachine).entropy_data
	ic.target_detected.connect(func(p: String): _prompt = p)
	ic.target_lost.connect(func(): _prompt = "")
	var home := player.global_position

	section("door below the betrayal threshold")
	entropy.entropy = 40.0
	await _walk_to(player, Vector3(0.0, 0.0, -3.0))
	check("player near the door", door.is_player_near)
	check("explains itself below threshold (got '%s')" % _prompt, _prompt.begins_with("Not yet"))
	check("E refused below threshold", not door.try_interact())

	section("door at the threshold")
	entropy.entropy = 75.0
	door.refresh_prompt()
	check("prompt '[E] Go Outside' (got '%s')" % _prompt, _prompt == "[E] Go Outside")
	ic.lock(&"probe")
	check("E refused while interactions are locked", not door.try_interact())
	ic.unlock(&"probe")
	check("E opens the walk", door.try_interact())
	check("now in the park", park.walk_taken)

	section("park return door")
	var return_door := node("CorporateParkManager/CorporatePark/ReturnDoor") as Interactable
	check("return door is an Interactable", return_door != null)
	await _walk_to(player, Vector3(0.0, 0.0, 0.0))
	check("return prompt (got '%s')" % _prompt, _prompt == "[E] Return to Apartment")
	check("E returns to the apartment", return_door.try_interact())
	check("ransack applied on return", ransacked.is_ransacked)

	section("door after the walk, before the window")
	var flow := node("GameFlow") as GameFlow
	await _walk_to(player, Vector3(0.0, 0.0, -3.0))
	check("no second walk offered (got '%s')" % _prompt, _prompt.is_empty())
	check("E refused: walk spent", not door.try_interact())
	check("no hesitation before the betrayal is seen", flow.phase == GameFlow.Phase.RANSACKED)

	section("the window: look out, once")
	var shoes := node("Apartment/LuxuryShoes") as LuxuryShoes
	check("friend placed outside", shoes != null)
	if shoes == null:
		return
	var zone := shoes.get_node("ProximityArea") as Interactable
	await _walk_to(player, Vector3(zone.global_position.x, 0.0, -2.9))
	check("look prompt (got '%s')" % _prompt, _prompt == "[E] Look out the window")
	check("first look realizes the betrayal", zone.try_interact() and shoes.is_realized())
	var hud := node("CoreHud/HudUI") as HudUI
	check(
		"HUD shows the betrayal line (got '%s')" % hud.displayed_line(),
		hud.displayed_line() == LuxuryShoes.NARRATIVE_TEXT
	)
	check("prompt gone after the look (got '%s')" % _prompt, _prompt.is_empty())
	check("second look refused", not zone.try_interact())

	section("back at the door: the hesitation")
	await _walk_to(player, Vector3(0.0, 0.0, 0.0))
	await _walk_to(player, Vector3(0.0, 0.0, -3.0))
	check("the door triggers the hesitation", flow.phase == GameFlow.Phase.HESITATION)
	await (node("DualVisionController") as DualVisionController).visions_ended
	player.global_position = home


func _walk_to(player: PlayerMovement, at: Vector3) -> void:
	player.global_position = Vector3(at.x, 0.0, at.z)
	await wait(0.3)
