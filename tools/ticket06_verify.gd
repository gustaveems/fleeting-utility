extends SceneTree
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
var _fails := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/workspace.tscn")
	root.add_child(scene.instantiate())
	_run()


func _process(_delta: float) -> bool:
	return false


func _run() -> void:
	await process_frame
	await process_frame
	var ws := root.get_node("Workspace")
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
	_check("entered dream", _manager.in_dreamscape())

	# Wait past interception (2 s) + escalation (1 s) + forced-return fades (~0.5 s).
	# Generous slack: the headless scheduler can drift.
	await create_timer(10.0).timeout

	_check("interception fired", _intercepted)
	_check("defibrillation fired", _defib)
	_check("forced back to apartment", not _manager.in_dreamscape())
	_check("apartment visible again", _manager.workspace_root.visible)
	_check("override cleared after sequence", _screen._intensity_override < 0.0)

	# Anchors were disabled during the sequence; confirm they are still disabled now
	# (the interception seals them; a later task decides whether they re-enable).
	var disabled_count := 0
	for child in _valley.get_children():
		if child is MemoryAnchor and not (child as MemoryAnchor).monitoring:
			disabled_count += 1
	_check("anchors sealed (>=1 disabled)", disabled_count >= 1)

	# Clinical post-climax state (Task 2): harsh cold light, dead lamp, no shadows.
	_check("clinical mode active", _atmosphere.is_clinical_mode())
	_check("desk lamp dead", is_zero_approx(_atmosphere.lamp.light_energy))
	_check("key light shadowless", _atmosphere.key_light.shadow_enabled == false)
	_check(
		"ambient cold white-blue",
		(
			_atmosphere.world_environment.environment.ambient_light_color.b
			> _atmosphere.world_environment.environment.ambient_light_color.r
		)
	)

	# Task 3: withdrawal + lock + climax latch + lucid cap.
	_check("player in withdrawal", _player.is_in_withdrawal)
	_check("interaction locked", _interaction.is_locked)
	_check("lucid cap at 0.5", is_equal_approx(_screen.lucid_cap, 0.5))
	_check("withdrawal shake active", _manager.camera.withdrawal_shake > 0.0)

	# Climax latch: the permanent flag is set, so the dream can never re-trigger.
	_check("climax latch armed", _manager.state_machine._climax_fired)

	print("VERIFY_DONE fails=", _fails)
	quit()


func _check(name: String, passed: bool) -> void:
	if not passed:
		_fails += 1
	print("[%s] %s" % ["PASS" if passed else "FAIL", name])
