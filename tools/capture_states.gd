extends "res://tools/lib/verify_harness.gd"
## Visual capture of every lighting state, for before/after comparisons in polish
## tickets (T11). It replaces screenshot_probe, clinical_capture and ticket07_capture,
## and needs no autoload edits.
##
## Must run WINDOWED (the headless dummy renderer has no render target):
##     godot --path . -s tools/capture_states.gd
## PNGs land in tools/out/ (gitignored).
##
## Lighting states are driven straight through AtmosphereController, so no fades or
## flashes contaminate the frame. The DreamFade rect is forced transparent first.

const SETTLE := 0.4

var _atmo: AtmosphereController


func _title() -> String:
	return "CAPTURE STATES"


func _run() -> void:
	_atmo = node("Apartment/AtmosphereController")
	var fade := node("DreamscapeManager/DreamFade/FadeRect") as ColorRect
	if fade != null:
		fade.modulate.a = 0.0

	_set_entropy(10.0)
	await _shot("apartment_clean.png")
	_set_entropy(90.0)
	await _shot("apartment_decayed.png")
	_atmo.set_clinical_mode(true)
	await _shot("apartment_clinical.png")
	_atmo.set_subdued_mode(true)
	await _shot("apartment_subdued.png")
	_atmo.set_broken_mode(true)
	await _shot("apartment_broken.png")

	_atmo.set_broken_mode(false)
	_atmo.set_subdued_mode(false)
	var park := node("CorporateParkManager") as CorporateParkManager
	if park != null:
		await park.transition_to_park()
		await wait(2.0)
		await _shot("park.png")
		await park.transition_to_apartment()
		await wait(1.0)

	var act := node("Apartment/ActOne") as ActOne
	if act != null:
		_atmo.set_broken_mode(false)
		_set_entropy(30.0)
		act.runner.clear_queue()
		var talk := node("DialogueRunner") as DialogueRunner
		if talk.is_running:
			talk.cancel()
			await wait(0.2)
		act._place_crate()
		act.play(ActOneScript.CALLS[2], true)
		await wait(1.2)
		await _shot("act_one_call.png")
		act._neighbour_at_door()
		act.play(ActOneScript.NEIGHBOUR_AFTER_RANSACK)
		await wait(1.0)
		await _shot("act_one_neighbour.png")

	var metro := node("MetroRide") as MetroRide
	if metro != null:
		metro.start_ride()
		await wait(2.0)
		await _shot("metro_ride.png")
		metro.end_ride()
		await wait(1.0)
		var flow := node("GameFlow") as GameFlow
		flow.loops_completed = 1
		metro.last_ride_day = -1
		metro.start_ride()
		await wait(2.0)
		await _shot("metro_stone.png")
		metro.end_ride()
		flow.loops_completed = 0
		await wait(1.0)

	var manager := node("DreamscapeManager") as DreamscapeManager
	await manager.transition_to_dreamscape()
	if fade != null:
		fade.modulate.a = 0.0
	await _shot("valley.png")


func _set_entropy(value: float) -> void:
	_atmo.entropy_data.entropy = value
	_atmo.entropy_data.entropy_changed.emit(value)


func _shot(file_name: String) -> void:
	await wait(SETTLE)
	await capture(file_name)
