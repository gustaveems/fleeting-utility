extends "res://tools/lib/verify_harness.gd"
## Ticket-11 VFX probe: dust and leaves live in their worlds, freeze with them, and
## dust density follows the room's state.
##
## Run: godot --headless --path . -s tools/probe_vfx.gd


func _title() -> String:
	return "VFX PROBE"


func _run() -> void:
	var vfx := node("VfxDirector") as VfxDirector
	var entropy := (node("PlayerStateMachine") as PlayerStateMachine).entropy_data
	var dm := node("DreamscapeManager") as DreamscapeManager
	var player := node("Player") as PlayerMovement
	check("VfxDirector present", vfx != null)
	if vfx == null:
		return

	section("emitters live in their worlds")
	check(
		"dust under the apartment", vfx.dust != null and vfx.dust.get_parent() == node("Apartment")
	)
	check(
		"leaves under the valley",
		vfx.leaves != null and vfx.leaves.get_parent() == node("DreamscapeValley")
	)
	check("dust moving at boot", vfx.dust.speed_scale > 0.0)
	check("leaves frozen while the valley is inactive", is_zero_approx(vfx.leaves.speed_scale))

	section("dust follows the room")
	entropy.entropy = 10.0
	await wait(0.1)
	var clean := vfx.dust.amount_ratio
	entropy.entropy = 90.0
	await wait(0.1)
	var decayed := vfx.dust.amount_ratio
	check("dust thickens with entropy (%.2f -> %.2f)" % [clean, decayed], decayed > clean + 0.4)

	section("dream swaps the particles")
	dm.auto_return_seconds = 999.0
	await dm.transition_to_dreamscape()
	check("leaves fall in the dream", vfx.leaves.speed_scale > 0.0)
	check("dust frozen in the dream", is_zero_approx(vfx.dust.speed_scale))
	var cam := node("WorkspaceCamera") as WorkspaceCamera
	check(
		"dream framing opens the view (pitch %.0f)" % cam.rotation_degrees.x,
		cam.rotation_degrees.x > -20.0
	)
	player.global_position = Vector3(6.0, 0.0, -4.0)
	await wait(0.1)
	var offset := vfx.leaves.global_position - player.global_position
	check(
		"leaves fall around the player (offset %s)" % offset,
		absf(offset.x) < 0.01 and absf(offset.z) < 0.01
	)
	await dm.return_to_workspace()
	check("dust moving again", vfx.dust.speed_scale > 0.0)
	check(
		"room framing restored (pitch %.0f)" % cam.rotation_degrees.x,
		is_equal_approx(cam.rotation_degrees.x, -30.0)
	)
	check("leaves frozen again", is_zero_approx(vfx.leaves.speed_scale))

	section("clinical room is sterile")
	(node("GameFlow") as GameFlow)._enter_phase(GameFlow.Phase.CLINICAL)
	await wait(0.1)
	check("no dust in the clinical room", is_zero_approx(vfx.dust.amount_ratio))

	section("clinical reflections")
	var atmo := node("Apartment/AtmosphereController") as AtmosphereController
	var env := atmo.environment
	check("no SSR before the climax", not env.ssr_enabled)
	atmo.set_clinical_mode(true)
	check("SSR on in the clinical room", env.ssr_enabled)
	check(
		"floor polished (roughness %.2f)" % atmo.floor_material.roughness,
		atmo.floor_material.roughness <= AtmosphereController.CLINICAL_FLOOR_ROUGHNESS + 0.001
	)
	atmo.set_subdued_mode(true)
	check("SSR off after the reset", not env.ssr_enabled)
	check("floor matte again", atmo.floor_material.roughness > 0.8)
