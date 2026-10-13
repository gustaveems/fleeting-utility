extends "res://tools/lib/verify_harness.gd"
## Ticket-11 post-FX probe: one screen pass owns crash CA/blur/tremor, the High-Focus
## look, the soft-boundary vignette, grain and the step shake, with T13 accessibility
## scales. The headless dummy renderer cannot compile shaders, so this checks the
## driving logic. tools/capture_states.gd (windowed) is the visual check.
##
## Run: godot --headless --path . -s tools/probe_post_fx.gd

var _fx: ScreenEffects


func _title() -> String:
	return "POST FX PROBE"


func _run() -> void:
	_fx = node("ScreenEffects") as ScreenEffects
	var sm := node("PlayerStateMachine") as PlayerStateMachine
	check("ScreenEffects present", _fx != null)
	if _fx == null:
		return

	section("one pass")
	check("no separate vignette pass", node("SoftBoundaryController") == null)
	check("ScreenEffects owns edge proximity", _fx.has_method("set_edge_proximity"))

	section("vignette follows the room edge")
	var player := node("Player") as PlayerMovement
	player.global_position = Vector3(player.room_half_extents.x, 0.0, 0.0)
	await wait(0.2)
	var at_wall := _param("edge_proximity")
	player.global_position = Vector3.ZERO
	await wait(0.2)
	var at_centre := _param("edge_proximity")
	check("vignette strong at the wall (%.2f)" % at_wall, at_wall > 0.6)
	check("vignette clear at the centre (%.2f)" % at_centre, at_centre < 0.3)

	section("High-Focus look")
	sm.state_data.chemical_level = 0.95
	sm.state_data.sensory_overload = 0.0
	await wait(1.5)
	check(
		"focus intensity rises in High-Focus (%.2f)" % _param("focus_intensity"),
		_param("focus_intensity") > 0.6
	)
	sm.state_data.chemical_level = 0.4
	await wait(1.5)
	check(
		"focus look fades outside High-Focus (%.2f)" % _param("focus_intensity"),
		_param("focus_intensity") < 0.2
	)

	section("step shake lives in the shader, not the layer")
	sm.state_data.sensory_overload = 90.0
	await wait(0.5)
	_fx._on_movement_completed()
	await wait(0.05)
	var shake: Vector2 = _fx._material.get_shader_parameter("shake_offset")
	check("shake drives the uniform (%s)" % shake, shake.length() > 0.0)
	check("CanvasLayer never moves (offset %s)" % _fx.offset, _fx.offset == Vector2.ZERO)

	section("accessibility scales (T13)")
	_fx.motion_scale = 0.0
	_fx.distortion_scale = 0.25
	await wait(0.1)
	check("motion_scale reaches the shader", is_zero_approx(_param("motion_scale")))
	check("distortion_scale reaches the shader", is_equal_approx(_param("distortion_scale"), 0.25))
	sm.state_data.sensory_overload = 0.0


func _param(param: StringName) -> float:
	var v: Variant = _fx._material.get_shader_parameter(param)
	return float(v) if v != null else -1.0
