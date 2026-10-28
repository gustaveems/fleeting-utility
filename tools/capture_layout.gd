extends "res://tools/lib/verify_harness.gd"
## Layout review: every play space from straight above (the true layout, an orthographic
## top view) and from the game camera (what the player sees), entered the way the game
## enters it. → tools/out/layout_<space>_top.png / _iso.png
##
## Run: godot --path . -s tools/capture_layout.gd   (windowed)

var _top: Camera3D
var _iso: Camera3D


func _title() -> String:
	return "CAPTURE LAYOUT"


func _timeout_seconds() -> float:
	return 300.0


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_iso = ws.find_child("WorkspaceCamera", true, false) as Camera3D
	_top = Camera3D.new()
	_top.projection = Camera3D.PROJECTION_ORTHOGONAL
	_top.far = 200.0
	ws.add_child(_top)
	var sm := ws.find_child("PlayerStateMachine", true, false) as PlayerStateMachine
	var promises := ws.find_child("Promises", true, false) as Promises
	promises.pro = "refused"
	promises.care = "enrolled"
	_calm(sm)
	await wait(2.0)

	await _space("apartment", Vector3.ZERO, 11.0)

	var park := ws.find_child("CorporateParkManager", true, false) as CorporateParkManager
	park.park_duration = 999.0
	park.transition_to_park()
	await wait(1.5)
	await _space("park", Vector3.ZERO, 54.0)
	park.transition_to_apartment()
	await wait(1.0)

	var metro := ws.find_child("MetroRide", true, false) as MetroRide
	metro.start_ride()
	await wait(1.5)
	await _space("carriage", Vector3.ZERO, 10.0)
	metro.end_ride()
	await wait(1.0)

	var days := ws.find_child("DayCycle", true, false) as DayCycle
	var standing := ws.find_child("Standing", true, false) as Standing
	days.restore(3)
	_calm(sm)
	standing.go_out()
	await wait(1.5)
	await _space("rooftop", Vector3.ZERO, 10.0)
	var runner := ws.find_child("DialogueRunner", true, false) as DialogueRunner
	for n in 40:
		if not standing.is_out:
			break
		runner.cancel()
		await wait(0.1)
	await wait(1.0)

	var dm := ws.find_child("DreamscapeManager", true, false) as DreamscapeManager
	_calm(sm)
	dm.auto_return_seconds = 999.0
	dm.transition_to_dreamscape()
	for n in 100:
		if dm.in_dreamscape() and not dm.is_busy():
			break
		await wait(0.1)
	await wait(1.0)
	await _space("valley", Vector3.ZERO, 80.0)


func _calm(sm: PlayerStateMachine) -> void:
	sm.state_data.chemical_level = 0.8
	sm.state_data.sensory_overload = 0.0


func _space(name: String, centre: Vector3, size: float) -> void:
	await capture("layout_%s_iso.png" % name)
	_top.size = size
	_top.position = centre + Vector3(0, 60, 0)
	_top.rotation_degrees = Vector3(-90, 0, 0)
	# The rooms' fog would bury a view from 60 m up: the same light, no fog.
	var world := ws.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world != null and world.environment != null:
		var env := world.environment.duplicate() as Environment
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		_top.environment = env
	_top.make_current()
	await wait(0.3)
	await capture("layout_%s_top.png" % name)
	_iso.make_current()
	await wait(0.2)
