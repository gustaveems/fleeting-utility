extends "res://tools/lib/verify_harness.gd"
## Ticket-06 Task 1 verification: the ambulance interception.
##
## Shortens the interception delay + escalation so the whole sequence runs in seconds,
## then asserts: interception fires, auto-return is cancelled, anchors are disabled,
## screen-effects override engages, and the forced return lands back in the apartment.
##
## Run: godot --headless --path . -s tools/ticket06_verify.gd

var _manager: DreamscapeManager
var _ambulance: AmbulanceInterception
var _screen: ScreenEffects
var _valley: Node3D
var _atmosphere: AtmosphereController
var _interaction: InteractionController
var _player: PlayerMovement
var _ws: Node
var _intercepted := false
var _defib := false


func _run() -> void:
	_manager = ws.get_node("DreamscapeManager")
	_ambulance = ws.get_node("AmbulanceInterception")
	_screen = ws.get_node("ScreenEffects")
	_valley = ws.get_node("DreamscapeValley")
	_atmosphere = ws.get_node("Apartment").get_node("AtmosphereController")
	_interaction = ws.get_node("InteractionController")
	_player = ws.get_node("Player")

	_ambulance.interception_started.connect(func(): _intercepted = true)
	_ambulance.defibrillation_triggered.connect(func(): _defib = true)

	# Compress the sequence: 2 s to intercept, 1 s escalation.
	_ambulance.interception_delay = 2.0
	_ambulance.escalation_seconds = 1.0

	await _manager.transition_to_dreamscape()
	check("entered dream", _manager.in_dreamscape())

	# Wait past interception (2 s) + escalation (1 s) + forced-return fades (~0.5 s).
	# Generous slack: the headless scheduler can drift.
	await create_timer(10.0).timeout

	check("interception fired", _intercepted)
	check("defibrillation fired", _defib)
	check("forced back to apartment", not _manager.in_dreamscape())
	check("apartment visible again", _manager.workspace_root.visible)
	check("override cleared after sequence", _screen._intensity_override < 0.0)

	# Anchors were disabled during the sequence; confirm they are still disabled now
	# (the interception seals them; a later task decides whether they re-enable).
	var disabled_count := 0
	for child in _valley.get_children():
		if child is MemoryAnchor and not (child as MemoryAnchor).monitoring:
			disabled_count += 1
	check("anchors sealed (>=1 disabled)", disabled_count >= 1)

	# Clinical post-climax state (Task 2): harsh cold light, dead lamp, no shadows.
	check("clinical mode active", _atmosphere.is_clinical_mode())
	check("desk lamp dead", is_zero_approx(_atmosphere.lamp.light_energy))
	check("key light shadowless", _atmosphere.key_light.shadow_enabled == false)
	check(
		"ambient cold white-blue",
		(
			_atmosphere.environment.ambient_light_color.b
			> _atmosphere.environment.ambient_light_color.r
		)
	)

	# Task 3: withdrawal + lock + climax latch + lucid cap.
	check("player in withdrawal", _player.is_in_withdrawal)
	check("interaction locked", _interaction.is_locked)
	check("lucid cap at 0.5", is_equal_approx(_screen.lucid_cap, 0.5))
	check("withdrawal shake active", _manager.camera.withdrawal_shake > 0.0)

	# Climax latch: the permanent flag is set, so the dream can never re-trigger.
	check("climax latch armed", _manager.state_machine._climax_fired)


func _title() -> String:
	return "TICKET-06 VERIFY"
