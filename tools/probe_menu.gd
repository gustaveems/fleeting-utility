extends "res://tools/lib/verify_harness.gd"
## Ticket-13 probe: boot splash → main menu → settings → New Game → pause → live
## settings in-game → Quit to Menu (checkpoint save) → Continue. Boots the real main
## scene (boot.tscn), not the game directly.
##
## Run: godot --headless --path . -s tools/probe_menu.gd


func _scene_path() -> String:
	return "res://scenes/boot.tscn"


func _title() -> String:
	return "MENU PROBE"


func _run() -> void:
	var boot := current_scene as Boot
	check("boot scene is the main scene", boot != null)
	if boot == null:
		return
	if boot.get_node_or_null("Center") == null:
		await boot.menu_ready

	section("main menu")
	var cont := _find("Button_Continue") as Button
	var new_game := _find("Button_NewGame") as Button
	check("menu built", cont != null and new_game != null)
	check("no Continue without a save", not cont.visible)
	check("keyboard focus on New Game", new_game.has_focus())
	check("placeholder sounds synthesized during the splash", ProceduralAudio._default_bank != null)

	section("settings from the main menu persist")
	(_find("Button_Settings") as Button).pressed.emit()
	var motion := _find("Slider_Motion") as HSlider
	check(
		"settings panel open, first control focused",
		motion != null and (_find("Slider_Master") as HSlider).has_focus()
	)
	motion.value = 0.3
	(_find("Slider_SFX") as HSlider).value = 0.5
	check("setting written to disk", FileAccess.file_exists(TEST_SETTINGS_PATH))
	var sfx := AudioServer.get_bus_index(AudioBuses.SFX)
	check(
		"SFX volume applied (%.1f dB)" % AudioServer.get_bus_volume_db(sfx),
		absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(0.5)) < 0.1
	)
	(_find("Button_Back") as Button).pressed.emit()

	section("New Game starts the game with the settings applied")
	new_game.pressed.emit()
	await _wait_for_scene("Workspace")
	check("in the game", current_scene != null and current_scene.name == "Workspace")
	var fx := _find("ScreenEffects") as ScreenEffects
	check(
		"motion setting reached the post-FX (%.2f)" % fx.motion_scale,
		is_equal_approx(fx.motion_scale, 0.3)
	)

	section("pause")
	var pause := _find("PauseMenu") as PauseMenu
	var sm := _find("PlayerStateMachine") as PlayerStateMachine
	sm.state_data.chemical_level = 0.0
	tap_action(&"ui_cancel")
	await wait(0.1)
	check("Esc opens the pause menu", pause.is_open and paused)
	var frozen := sm.state_data.sensory_overload
	await wait(0.5)
	check(
		"the world is frozen while paused", is_equal_approx(sm.state_data.sensory_overload, frozen)
	)

	section("live settings from the pause menu")
	(_find("Button_Settings") as Button).pressed.emit()
	var hud := _find("HudUI") as HudUI
	var before := hud.meter_fill_color(true)
	(_find("Option_MeterPalette") as OptionButton).item_selected.emit(
		GameSettings.MeterPalette.COLORBLIND
	)
	check("colour-blind palette applied at once", hud.meter_fill_color(true) != before)
	check(
		"palette persisted",
		GameSettings.current().meter_palette == GameSettings.MeterPalette.COLORBLIND
	)
	tap_action(&"ui_cancel")
	await wait(0.1)
	check("Esc backs out of settings, menu still open", pause.is_open)
	tap_action(&"ui_cancel")
	await wait(0.1)
	check("Esc again resumes", not pause.is_open and not paused)
	sm.state_data.chemical_level = 0.6
	sm.state_data.sensory_overload = 0.0

	section("Quit to Menu saves at a checkpoint, Continue resumes")
	pause.open()
	(_find("Button_QuitToMenu") as Button).pressed.emit()
	await _wait_for_scene("Boot")
	check("back at the menu", current_scene != null and current_scene.name == "Boot")
	check("save written", Persistence.save_exists())
	check("tree unpaused", not paused)
	if (current_scene as Boot).get_node_or_null("Center") == null:
		await (current_scene as Boot).menu_ready
	cont = _find("Button_Continue") as Button
	check("Continue offered", cont.visible and cont.has_focus())

	section("New Game over a save asks first")
	(_find("Button_NewGame") as Button).pressed.emit()
	var confirm := _find("ConfirmNewGame") as Control
	check("confirmation shown", confirm.visible)
	check("safe choice focused", (_find("Button_CancelErase") as Button).has_focus())
	(_find("Button_CancelErase") as Button).pressed.emit()
	check("save kept", Persistence.save_exists())

	cont.pressed.emit()
	await _wait_for_scene("Workspace")
	check("Continue loads the game", current_scene != null and current_scene.name == "Workspace")
	var palette_hud := _find("HudUI") as HudUI
	await wait(0.2)
	check(
		"palette survives the restart",
		(
			palette_hud.meter_fill_color(true) != Color.TRANSPARENT
			and GameSettings.current().meter_palette == GameSettings.MeterPalette.COLORBLIND
		)
	)


func _find(node_name: String) -> Node:
	return current_scene.find_child(node_name, true, false) if current_scene != null else null


func _wait_for_scene(scene_name: String) -> void:
	for i in 60:
		await wait(0.1)
		if (
			current_scene != null
			and current_scene.name == scene_name
			and current_scene.is_node_ready()
		):
			await wait(0.6)
			return
