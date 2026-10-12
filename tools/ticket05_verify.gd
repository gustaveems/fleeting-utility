extends "res://tools/lib/verify_harness.gd"
## Ticket-05 end-to-end verification probe.
##
## Tests, in order, against the REAL scene:
##   A. Crash trigger from the meters (chemical 0 + overload 100 → transition fires)
##   B. World-swap state (apartment hidden, valley live, clamp widened, camera far,
##      env resource swapped, HUD countdown ticking)
##   C. Auto-return (timer shortened to 3 s — same code path as 30 s, honest note below)
##   D. Memory-anchor return (teleport into zone, parse the real E action, expect return)
##
## Run: godot --headless --path . -s tools/ticket05_verify.gd

var _manager: DreamscapeManager
var _player: PlayerMovement
var _sm: PlayerStateMachine
var _ws: Node


func _run() -> void:
	_ws = ws
	_manager = _ws.get_node("DreamscapeManager")
	_player = _ws.get_node("Player")
	_sm = _ws.get_node("PlayerStateMachine")

	# --- A: crash trigger from the meters ------------------------------------------
	_sm.state_data.chemical_level = 0.0
	_sm.state_data.sensory_overload = 100.0
	await create_timer(5.0).timeout  # trigger is immediate; fade takes 3.5 s
	check("A trigger: in_dreamscape", _manager.in_dreamscape())

	# --- B: world-swap state ---------------------------------------------------------
	var apartment := _manager.workspace_root
	var valley := _manager.dreamscape_root
	check("B apartment hidden", not apartment.visible)
	check("B valley visible", valley.visible)
	check("B clamp widened", _player.room_half_extents.x > 20.0)
	check("B camera far 150", is_equal_approx(_manager.camera.far, 150.0))
	var env := _ws.get_node("WorldEnvironment")
	check("B env swapped", env.environment == _manager.valley_environment)
	await create_timer(2.5).timeout
	var hud := _ws.get_node("DreamscapeHud")
	var label := hud.get_node("TimerLabel") as Label
	print("   countdown label: '", label.text, "'")
	var ticking := label.text.contains("Fading memory") and not label.text.contains(": 30s")
	check("B countdown ticking", ticking)

	# --- C: auto-return (timer shortened to 3 s; 30 s is the same code path) ---------
	_manager.auto_return_seconds = 3.0
	# The running timer still holds the old duration; restart to apply the short value.
	_manager._auto_return_timer.start(3.0)
	await create_timer(8.0).timeout  # 3 s timer + 3.5 s fade-out/in + slack
	check("C auto-returned", not _manager.in_dreamscape())
	check("C apartment visible again", apartment.visible)
	check("C walls colliding again", _ray_hits(_player.global_position + Vector3(5.5, 0.5, 0.0)))
	check("C overload revived to crash", _sm.state_data.sensory_overload >= 49.0)

	# --- D: memory-anchor return ------------------------------------------------------
	# Restore the long auto-return so the ONLY way phase D can exit the dream is the
	# anchor E interaction — the first run's "anchor returned" PASS was a false positive
	# from phase C's leftover 3 s timer firing mid-test.
	_manager.auto_return_seconds = 30.0
	await _manager.transition_to_dreamscape()
	var anchor: MemoryAnchor = null
	for child in valley.get_children():
		if child is MemoryAnchor:
			anchor = child
			break
	check("D anchor exists in valley", anchor != null)
	if anchor != null:
		_player.global_position = anchor.global_position + Vector3(0.0, -1.0, 0.0)
		await create_timer(0.3).timeout  # physics frames for body_entered
		check("D proximity detected", _manager._near_anchor == anchor)
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		await create_timer(5.0).timeout  # flash + fade + world swap
		check("D anchor returned", not _manager.in_dreamscape())


func _ray_hits(target: Vector3) -> bool:
	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		_player.global_position + Vector3(0.0, 0.5, 0.0), target, 4294967295, [_player.get_rid()]
	)
	query.collide_with_areas = false
	return not space.intersect_ray(query).is_empty()


func _title() -> String:
	return "TICKET-05 VERIFY"
