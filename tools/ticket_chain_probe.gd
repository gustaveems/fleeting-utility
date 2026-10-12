extends SceneTree
## Throwaway functional probe — loads the REAL workspace scene and drives the dev-rig
## keys exactly as a player would, printing the observable state chain.
##   godot --path . -s tools/ticket_chain_probe.gd
## Not a game class (no class_name on purpose). -s scripts must extend SceneTree/MainLoop;
## a Node script passed to -s never enters the tree, which is why this loads the scene
## into root itself.

var _frames := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/workspace.tscn")
	root.add_child(scene.instantiate())
	_run_chain()


func _process(_delta: float) -> bool:
	return false  # keep running; _run_chain quits when done


func _run_chain() -> void:
	await process_frame  # let _ready() cascade finish
	var ws := root.get_node_or_null("Workspace")
	if ws == null:
		print("PROBE FAIL: no Workspace root — scene under test is wrong")
		quit()
		return

	var player := ws.get_node("Player")
	var sm: PlayerStateMachine = ws.get_node("PlayerStateMachine")
	var clutter := ws.get_node("ClutterField")
	var decals := ws.get_node("SurfaceDegradation")
	var lamp: OmniLight3D = ws.get_node("DeskLamp")

	print(
		"PROBE boot: cell≈",
		player.global_position,
		" clutter=",
		_count_visible(clutter),
		" decals=",
		_count_visible(decals),
		" lamp_energy=",
		lamp.light_energy
	)

	# Drive entropy past both decal thresholds via the T dev key (bootstrap +20 each).
	for _i in range(3):
		_tap(KEY_T)
		await _wait(10)
	print(
		"PROBE after T×3: entropy=",
		sm.entropy_data.entropy,
		" clutter=",
		_count_visible(clutter),
		" decals=",
		_count_visible(decals),
		" lamp_energy=",
		lamp.light_energy
	)

	# Crash the protagonist via the Tab dev key, then walk a cell.
	_tap(KEY_TAB)
	await _wait(20)
	print(
		"PROBE after Tab: overload=",
		sm.state_data.sensory_overload,
		" crashed=",
		sm.state_data.is_crashed()
	)

	Input.action_press("move_east")
	await _wait(30)
	Input.action_release("move_east")
	await _wait(60)  # let the deceleration settle below the stop threshold
	print(
		"PROBE after step: pos=",
		player.global_position,
		"  is_moving=",
		player._is_moving,
		" (free roam: any position, must be stopped)"
	)

	# Deactivation path: R resets entropy to 0 — clutter and decals must disappear.
	_tap(KEY_R)
	await _wait(10)
	print(
		"PROBE after R: entropy=",
		sm.entropy_data.entropy,
		" clutter=",
		_count_visible(clutter),
		" decals=",
		_count_visible(decals),
		" lamp_energy=",
		lamp.light_energy
	)

	quit()


func _tap(key: int) -> void:
	var down := InputEventKey.new()
	down.pressed = true
	down.physical_keycode = key
	Input.parse_input_event(down)
	var up := InputEventKey.new()
	up.pressed = false
	up.physical_keycode = key
	Input.parse_input_event(up)


func _wait(n: int) -> void:
	for _i in range(n):
		await process_frame


func _count_visible(parent: Node) -> int:
	var total := 0
	for child in parent.get_children():
		if (child is ClutterItem or child is Decal) and child.visible:
			total += 1
	return total
