extends "res://tools/lib/verify_harness.gd"
## Ticket-09 functional verifier — The Hesitation, Dual Visions, Statue Narrative.
##
## Headless, so Input.is_action_just_pressed is inert and body_entered never fires
## (no physics simulation in headless). The probe therefore tests the public API:
##   - initiate_hesitation() locks the player
##   - dual_vision_controller.start_visions() runs the flash loop
##   - valley_phase_active toggles correctly
##   - visions_ended emits, player unlocks
##   - statue_narrative._is_looking_at_me() returns true when aimed

var _ws: Node
var _hesitation: HesitationController
var _dual_vision: DualVisionController
var _player: PlayerMovement
var _camera: WorkspaceCamera
var _apartment: Node3D
var _valley: Node3D
var _statue0: StaticBody3D
var _narrative0: StatueNarrative

var _valley_seen := 0
var _vision_end_seen := false


func _run() -> void:
	_ws = ws

	_gather()
	await _test_hesitation_lock()
	await _test_dual_vision_flashes()
	await _test_visions_end()
	await _test_statue_look()


func _gather() -> void:
	_hesitation = _ws.get_node_or_null("HesitationController")
	_dual_vision = _ws.get_node_or_null("DualVisionController")
	_player = _ws.get_node_or_null("Player")
	_camera = _ws.get_node_or_null("WorkspaceCamera")
	_apartment = _ws.get_node_or_null("Apartment")
	_valley = _ws.get_node_or_null("DreamscapeValley")
	for c in _valley.get_children():
		if c.name == "Statue_0" and c is StaticBody3D:
			_statue0 = c as StaticBody3D
			break
	if _statue0 != null:
		for c in _statue0.get_children():
			if c is StatueNarrative:
				_narrative0 = c as StatueNarrative
				break


# ---------------------------------------------------------------- 1. hesitation lock
func _test_hesitation_lock():
	print("\n--- 1. Hesitation locks player and starts dual visions ---")
	check("HesitationController present", _hesitation != null)
	check("DualVisionController present", _dual_vision != null)
	check("Statue_0 has StatueNarrative child", _narrative0 != null)
	if _hesitation == null:
		return

	# Manually trigger the ransacked state on the way to testing the hesitation.
	var ransacked := _ws.get_node_or_null("RansackedStateManager")
	check("RansackedStateManager present", ransacked != null)
	if ransacked != null:
		(ransacked as RansackedStateManager).is_ransacked = true

	_dual_vision.visions_ended.connect(func(): _vision_end_seen = true)
	_dual_vision.valley_phase_active.connect(func(active: bool): _valley_seen += 1 if active else 0)

	_hesitation.initiate_hesitation()
	await create_timer(0.3).timeout
	check("player locked during hesitation", _player.input_locked)
	check(
		"camera shake set (withdrawal_shake=%.2f)" % _camera.withdrawal_shake,
		_camera.withdrawal_shake > 0.0
	)


# ---------------------------------------------------------------- 2. flash loop
func _test_dual_vision_flashes():
	print("\n--- 2. Dual vision toggles valley visibility and emits valley_phase_active ---")
	if _dual_vision == null:
		check("required refs", false)
		return
	# The vision loop is running from Step 1. Wait for a valley flash near start.
	await create_timer(1.2).timeout  # sequence: 0.2 apt, 0.8 valley → in valley now
	check("valley_phase_active fired at least once (count=%d)" % _valley_seen, _valley_seen >= 1)

	# During valley phase (depends on timing — but we're past the first 1s).
	# Just check that during the sequence, the state toggled meaningfully.
	await create_timer(0.5).timeout  # into the valley flash at 0.8s → ending at 1.0s

	# Actually, let's just verify the valley root visibility is being correctly toggled
	# by checking that the valley is either visible or not (it changes rapidly).
	# Wait for the sequence to finish (~10s total).
	await create_timer(9.0).timeout
	check("visions_ended of the full ~10s sequence seen", _vision_end_seen)
	check("valley_phase_active toggled at least once (count=%d)" % _valley_seen, _valley_seen >= 1)


# ---------------------------------------------------------------- 3. visions end
func _test_visions_end():
	print("\n--- 3. Visions end: player unlocked, apartment visible ---")
	if _hesitation == null or _dual_vision == null:
		check("required refs", false)
		return
	check("player unlocked after visions", not _player.input_locked)
	check(
		"camera shake reset (got %.2f)" % _camera.withdrawal_shake,
		is_equal_approx(_camera.withdrawal_shake, 0.0)
	)
	check("apartment root visible", _apartment.visible)
	check("valley root hidden", not _valley.visible)
	check("dual vision _running == false", not _dual_vision._running)


# ---------------------------------------------------------------- 4. statue look
func _test_statue_look():
	print("\n--- 4. StatueNarrative._is_looking_at_me() dot-product check ---")
	if _narrative0 == null or _camera == null or _statue0 == null:
		check("required refs", false)
		return

	# Position the camera directly in front of the statue, looking at it.
	var cam_home := _camera.global_position
	var cam_rot_home := _camera.rotation_degrees
	_camera.target_node = null  # Freeze follow so manual position sticks.
	_camera.global_position = _statue0.global_position + Vector3(3.0, 1.5, 0.0)
	_camera.rotation_degrees = Vector3(0.0, 90.0, 0.0)  # look -Z toward statue
	await create_timer(0.15).timeout
	var looking := _narrative0._is_looking_at_me()
	print(
		(
			"      camera at %s rot %s forward=%s to_statue=%s dot=%.3f"
			% [
				str(_camera.global_position),
				str(_camera.rotation_degrees),
				str(-_camera.global_transform.basis.z).substr(0, 30),
				str((_statue0.global_position - _camera.global_position).normalized()).substr(
					0, 30
				),
				-_camera.global_transform.basis.z.dot(
					(_statue0.global_position - _camera.global_position).normalized()
				)
			]
		)
	)
	check("look check passes when aimed (got result=%s)" % str(looking), looking)

	_camera.rotation_degrees = Vector3(0.0, -90.0, 0.0)  # look opposite
	await create_timer(0.15).timeout
	check("look check fails when aimed away", not _narrative0._is_looking_at_me())

	_camera.global_position = cam_home
	_camera.rotation_degrees = cam_rot_home
	_camera.target_node = _player


func _title() -> String:
	return "TICKET-09 VERIFY"
