extends SceneTree
## Invisible-walls test (Ticket-05 guide, check 4.7).
##
## Question: when a world subtree is HIDDEN, do its colliders stay in the physics
## space? (Answer found: YES, they did — fixed by explicit CollisionShape3D.disabled
## toggling in DreamscapeManager._swap_worlds.)
##
## Method: await each transition properly (headless _process runs unthrottled, so
## frame-counting waits only a fraction of real time — the first version of this probe
## "failed" the return test purely because it tested mid-fade), then raycast.
##
## Positive control: a ray at Statue_0 must HIT — without that, a clear wall result
## would be meaningless.
##
## Run: godot --headless --path . -s tools/invisible_walls_probe.gd


var _manager: DreamscapeManager
var _player: PlayerMovement


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/workspace.tscn")
	root.add_child(scene.instantiate())
	_run()


func _process(_delta: float) -> bool:
	return false  # keep running; _run() quits when done


func _run() -> void:
	await process_frame
	await process_frame
	var ws := root.get_node_or_null("Workspace")
	_manager = ws.get_node("DreamscapeManager")
	_player = ws.get_node("Player")

	# --- Phase 1: valley ---
	await _manager.transition_to_dreamscape()
	print("VALLEY in_dreamscape=", _manager.in_dreamscape(),
		" apartment_visible=", _manager.workspace_root.visible)

	var statue_hit := _ray_to(Vector3(34.0, 2.0, -12.0))
	if statue_hit:
		print("CONTROL statue ray -> HIT ", statue_hit["collider"].name, " (query works)")
	else:
		print("CONTROL statue ray -> MISS — query broken, wall results meaningless!")

	var probes := {
		"EAST (x=+4.5)": Vector3(5.5, 0.5, 0.0),
		"WEST (x=-4.5)": Vector3(-5.5, 0.5, 0.0),
		"NORTH (z=-3.5)": Vector3(0.0, 0.5, -4.5),
		"SOUTH (z=+3.5)": Vector3(0.0, 0.5, 4.5),
	}
	for key in probes:
		var hit := _ray_to(probes[key])
		if hit:
			print("WALL ", key, " -> BLOCKED by hidden wall (BUG) collider=", hit["collider"].name)
		else:
			print("WALL ", key, " -> clear")

	# --- Phase 2: return, colliders must come back ---
	await _manager.return_to_workspace()
	print("RETURN in_dreamscape=", _manager.in_dreamscape(),
		" apartment_visible=", _manager.workspace_root.visible)
	var east := _ray_to(Vector3(5.5, 0.5, 0.0))
	if east:
		print("RETURN east wall -> BLOCKED as expected collider=", east["collider"].name)
	else:
		print("RETURN east wall -> clear (BUG: colliders not restored)")

	# --- Phase 3: HUD countdown actually ticks (the fix for guide gap 4.4) ---
	await _manager.transition_to_dreamscape()
	var hud := root.get_node("Workspace").get_node("DreamscapeHud")
	var timer_label := hud.get_node("TimerLabel") as Label
	await create_timer(2.2).timeout
	print("COUNTDOWN at ~2s: label='", timer_label.text, "' (expect ~28s, not empty)")
	await create_timer(3.0).timeout
	print("COUNTDOWN at ~5s: label='", timer_label.text, "' (expect ~25s)")

	print("PROBE_DONE")
	quit()


func _ray_to(target: Vector3) -> Dictionary:
	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		_player.global_position + Vector3(0.0, 0.5, 0.0),
		target,
		4294967295,  # all layers — we want to know about ANY body out there
		[_player.get_rid()]
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)
