extends SceneTree
## Headless probe: verify every Environment / DirectionalLight3D property that
## Ticket-07 writes actually exists on Godot 4.7.2.
## gdparse is syntax-only, so a typo like `exposure_multiplier` parses fine and only
## fails at runtime. This catches that class of error before the eye test.


func _init() -> void:
	print("Godot ", Engine.get_version_info().get("string", "?"))

	var env := Environment.new()
	var dir := DirectionalLight3D.new()

	print("--- Environment ---")
	for p in [
		"tonemap_mode",
		"tonemap_exposure",
		"ambient_light_color",
		"ambient_light_energy",
		"background_color",
		"fog_density",
		"fog_light_color",
		"volumetric_fog_density",
		"adjustment_enabled",
		"adjustment_contrast",
		"adjustment_saturation",
		"fog_sky_affect",
		"exposure_multiplier"
	]:
		print("  [%s] %s" % [_mark(env, p), p])

	print("--- DirectionalLight3D ---")
	for p in ["light_energy", "light_color", "shadow_enabled", "shadow_bias"]:
		print("  [%s] %s" % [_mark(dir, p), p])

	print("--- Tone mapper enum constant used by Ticket-07 ---")
	print("  TONE_MAPPER_ACES =", Environment.TONE_MAPPER_ACES)
	print("  TONE_MAPPER_FILMIC =", Environment.TONE_MAPPER_FILMIC)
	print("  Environment enum list: ", ClassDB.class_get_enum_list("Environment"))

	print("--- live defaults ---")
	print("  tonemap_mode=", env.tonemap_mode, " tonemap_exposure=", env.tonemap_exposure)
	print("  shadow_bias=", dir.shadow_bias, " shadow_enabled=", dir.shadow_enabled)
	quit()


func _mark(obj: Object, prop: String) -> String:
	for p in obj.get_property_list():
		if p.name == prop:
			return "OK     "
	return "MISSING"
