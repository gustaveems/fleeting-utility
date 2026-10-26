extends "res://tools/lib/verify_harness.gd"
## Ticket-12 save/load probe. Plays to each checkpoint, saves, reboots the whole game
## in-process (which auto-loads) and checks that the restored world matches, down to
## the ransack debris layout. Also checks malformed and future-version saves are
## refused safely, and the settings store round-trips.
##
## Run: godot --headless --path . -s tools/probe_persistence.gd


func _title() -> String:
	return "PERSISTENCE PROBE"


func _run() -> void:
	section("fresh boot")
	var p := node("Persistence") as Persistence
	check("Persistence present", p != null)
	if p == null:
		return
	check("no save on a fresh boot", not p.has_save())
	check("boots in WORKSPACE", _flow().phase == GameFlow.Phase.WORKSPACE)

	await _test_ransacked_round_trip()
	await _test_scarred_round_trip()
	await _test_bad_saves()
	_test_settings()


# ------------------------------------------------------------------ RANSACKED
func _test_ransacked_round_trip() -> void:
	section("ransacked checkpoint round-trip")
	var sm := node("PlayerStateMachine") as PlayerStateMachine
	sm.entropy_data.entropy = 76.0
	# As in play: the room crosses the thresholds before the checkpoint, so the neighbour's
	# decay remarks are in the save (otherwise the first tick after the reload adds them).
	sm.entropy_data.entropy_changed.emit(76.0)
	(node("CorporateParkManager") as CorporateParkManager).transition_to_park()
	(node("CorporateParkManager") as CorporateParkManager).transition_to_apartment()
	var shoes := node("Apartment/LuxuryShoes") as LuxuryShoes
	(shoes.get_node("ProximityArea") as Interactable).try_interact()
	var visions := node("DualVisionController") as DualVisionController
	(node("HesitationController") as HesitationController).initiate_hesitation()
	await visions.visions_ended
	sm.state_data.chemical_level = 0.33
	sm.state_data.sensory_overload = 12.0
	var p := node("Persistence") as Persistence
	check("autosaved at the checkpoint", p.has_save())
	check("explicit save succeeds", p.save_game())
	var before := _comparable(p.snapshot())
	var debris_before := _debris()
	check("ransack left debris (%d pieces)" % debris_before.size(), debris_before.size() >= 5)

	await reboot()
	p = node("Persistence") as Persistence
	var after := _comparable(p.snapshot())
	check("snapshot identical after reload", after == before)
	if after != before:
		print("    before: ", before)
		print("    after:  ", after)
	check("phase RANSACKED", _flow().phase == GameFlow.Phase.RANSACKED)
	check("same debris layout", _debris() == debris_before)
	check("bench gone and non-solid", live_shapes(node("Apartment/BenchArea/CraftingBench")) == 0)
	check(
		"broken lighting",
		(node("Apartment/AtmosphereController") as AtmosphereController).is_broken_mode()
	)
	var shoes2 := node("Apartment/LuxuryShoes") as LuxuryShoes
	check("betrayal already realized", shoes2 != null and shoes2.is_realized())
	check("walk spent", (node("CorporateParkManager") as CorporateParkManager).walk_taken)
	check(
		"climax armed by the visions",
		(node("AmbulanceInterception") as AmbulanceInterception).armed
	)
	var chem := (node("PlayerStateMachine") as PlayerStateMachine).state_data.chemical_level
	check("chemistry restored (%.3f ~ 0.33)" % chem, absf(chem - 0.33) < 0.03)


# ------------------------------------------------------------------ SCARRED
func _test_scarred_round_trip() -> void:
	section("scarred checkpoint round-trip")
	var dm := node("DreamscapeManager") as DreamscapeManager
	var endgame := node("EndgameLoopManager") as EndgameLoopManager
	var ambulance := node("AmbulanceInterception") as AmbulanceInterception
	ambulance.interception_delay = 0.5
	ambulance.escalation_seconds = 0.5
	endgame.clinical_pause_seconds = 0.3
	dm.auto_return_seconds = 999.0
	await dm.transition_to_dreamscape()
	await endgame.loop_reset
	var rate := (node("PlayerStateMachine") as PlayerStateMachine).entropy_data.entropy_growth_rate
	var before := _comparable((node("Persistence") as Persistence).snapshot())

	await reboot()
	var after := _comparable((node("Persistence") as Persistence).snapshot())
	check("snapshot identical after reload", after == before)
	if after != before:
		print("    before: ", before)
		print("    after:  ", after)
	check("phase SCARRED", _flow().phase == GameFlow.Phase.SCARRED)
	check("one loop completed", _flow().loops_completed == 1)
	var sm := node("PlayerStateMachine") as PlayerStateMachine
	check("climax latched: no more dreams", sm.is_climax_latched())
	check(
		"interactions locked for good",
		(node("InteractionController") as InteractionController).is_locked
	)
	check(
		"faster entropy kept, not re-multiplied",
		is_equal_approx(sm.entropy_data.entropy_growth_rate, rate)
	)
	check(
		"subdued lighting",
		(node("Apartment/AtmosphereController") as AtmosphereController).is_subdued_mode()
	)


# ------------------------------------------------------------------ bad saves
func _test_bad_saves() -> void:
	section("malformed save is refused, not fatal")
	_write_raw("{ this is not json")
	await reboot()
	check("boots fresh in WORKSPACE", _flow().phase == GameFlow.Phase.WORKSPACE)
	check("bad file set aside", FileAccess.file_exists(TEST_SAVE_PATH + ".bad"))

	section("save from a newer game version is refused")
	_write_raw(JSON.stringify({"version": Persistence.VERSION + 1, "phase": "SCARRED"}))
	await reboot()
	check("boots fresh in WORKSPACE", _flow().phase == GameFlow.Phase.WORKSPACE)
	check("reports why", (node("Persistence") as Persistence).last_error.contains("version"))
	wipe_test_save()


# ------------------------------------------------------------------ settings
func _test_settings() -> void:
	section("settings store")
	var s := SettingsStore.new()
	s.set_value(&"audio", &"master_db", -6.0)
	check("settings save", s.save() == OK)
	var t := SettingsStore.new()
	check("settings reload", t.load() == OK)
	check("value round-trips", is_equal_approx(t.get_value(&"audio", &"master_db", 0.0), -6.0))
	check("default for unknown key", t.get_value(&"audio", &"missing", 3.0) == 3.0)


# ------------------------------------------------------------------ helpers
func _flow() -> GameFlow:
	return node("GameFlow") as GameFlow


## Snapshot minus what legitimately moves between save and compare: the wall-clock
## stamp and the live meters (entropy and chemistry keep ticking through the reboot;
## they are checked separately with a tolerance).
func _comparable(snap: Dictionary) -> Dictionary:
	var s := snap.duplicate(true)
	s.erase("saved_at")
	s.erase("meters")
	(s["entropy"] as Dictionary).erase("value")
	return s


func _debris() -> Array:
	var out := []
	for child in node("Apartment").get_children():
		if child.name.begins_with("Debris"):
			out.append((child as Node3D).transform)
	return out


func _write_raw(text: String) -> void:
	var f := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()
