extends "res://tools/lib/verify_harness.gd"
## Ticket-08 Task 1 functional verifier — the Self-Soothing Mechanic.
##
## Drives the real scene through the Compulsive State cycle:
##   1. Boot → verify TrivialObject and SelfSoothingController exist
##   2. Drive overload to 80+ and chemical to 0 → verify compulsion triggers
##   3. Verify player locked, camera repointed
##   4. Simulate E presses → verify overload decreases
##   5. Verify compulsion ends when overload < 50
##   6. Verify player unlocked, camera restored

var _ws: Node
var _sm: PlayerStateMachine
var _sd: PlayerStateData
var _player: PlayerMovement
var _camera: WorkspaceCamera
var _controller: SelfSoothingController
var _trivial: TrivialObject

var _compulsion_started_seen := false
var _compulsion_ended_seen := false


func _run() -> void:
	_ws = ws

	_collect()
	await _test_boot()
	await _test_trigger()
	await _test_soothe()
	await _test_recovery()


func _collect() -> void:
	_sm = _ws.get_node_or_null("PlayerStateMachine")
	_player = _ws.get_node_or_null("Player")
	_camera = _ws.get_node_or_null("WorkspaceCamera")
	_controller = _ws.get_node_or_null("SelfSoothingController")
	_trivial = _ws.get_node_or_null("Apartment/TrivialObject")
	_sd = _sm.state_data if _sm != null else null


# ---------------------------------------------------------------- 1. boot
func _test_boot():
	print("\n--- 1. Self-Soothing Mechanic exists in the tree ---")
	check("SelfSoothingController present", _controller != null)
	check("TrivialObject present", _trivial != null)
	check("TrivialObject is Area3D", _trivial is Area3D)
	check("TrivialObject.state_machine wired", _trivial != null and _trivial.state_machine != null)
	check(
		"Controller.state_machine wired", _controller != null and _controller.state_machine != null
	)
	check("Controller.player wired", _controller != null and _controller.player != null)
	check("Controller.camera wired", _controller != null and _controller.camera != null)
	check(
		"Controller.trivial_object wired",
		_controller != null and _controller.trivial_object != null
	)

	if _controller != null:
		_controller.compulsion_started.connect(func(): _compulsion_started_seen = true)
		_controller.compulsion_ended.connect(func(): _compulsion_ended_seen = true)


# ---------------------------------------------------------------- 2. trigger
func _test_trigger():
	print("\n--- 2. Compulsive State triggers at overload 80+ / chemical 0 ---")
	if _sd == null or _controller == null:
		check("state_machine and controller exist", false)
		return

	# Start in a safe state.
	_sd.chemical_level = 0.5
	_sd.sensory_overload = 40.0
	_sd.state_changed.emit(_sd)
	await create_timer(0.2).timeout
	check("not in compulsion at overload 40 / chemical 0.5", not _controller._in_compulsion)

	# Drive to trigger condition.
	_sd.chemical_level = 0.0
	_sd.sensory_overload = 85.0
	_sd.state_changed.emit(_sd)
	await create_timer(0.2).timeout

	check("compulsion_started signal fired", _compulsion_started_seen)
	check("controller._in_compulsion == true", _controller._in_compulsion)
	check("player.input_locked == true", _player.input_locked)
	check("camera.target_node == trivial_object", _camera.target_node == _trivial)


# ---------------------------------------------------------------- 3. soothe
func _test_soothe():
	print("\n--- 3. E presses lower overload via trivial_object.soothe() ---")
	if _controller == null or _trivial == null or _sd == null:
		check("required refs exist", false)
		return

	var before := _sd.sensory_overload
	_trivial.soothe(10.0)
	await create_timer(0.1).timeout
	var after := _sd.sensory_overload
	check("soothe(10.0) reduced overload (%.1f -> %.1f)" % [before, after], after < before)
	check(
		"overload reduced by ~10.0 (got %.1f)" % (before - after),
		absf((before - after) - 10.0) < 0.1
	)


# ---------------------------------------------------------------- 4. recovery
func _test_recovery():
	print("\n--- 4. Compulsion ends when overload < 50 ---")
	if _controller == null or _sd == null:
		check("required refs exist", false)
		return

	# Drive overload below recovery threshold.
	_sd.sensory_overload = 45.0
	_sd.state_changed.emit(_sd)
	await create_timer(0.2).timeout

	check("compulsion_ended signal fired", _compulsion_ended_seen)
	check("controller._in_compulsion == false", not _controller._in_compulsion)
	check("player.input_locked == false", not _player.input_locked)
	check("camera.target_node restored to player", _camera.target_node == _player)


func _title() -> String:
	return "TICKET-08 TASK 1 VERIFY"
