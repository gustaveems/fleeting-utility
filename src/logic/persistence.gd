class_name Persistence
extends Node
## LOGIC — save/load across sessions (Ticket-12): a versioned JSON checkpoint.
##
## CHECKPOINTS, NOT SNAPSHOTS OF EVERY FRAME
## -----------------------------------------
## The game saves on reaching a stable phase (WORKSPACE, RANSACKED, SCARRED) and on quit
## while in one. The dream, the walk, the hesitation and the climax are timed
## set-pieces. Quitting inside one resumes at the last checkpoint rather than
## mid-sequence.
##
## WHAT IS SAVED (schema v1)
## -------------------------
##   phase, loops_completed                         GameFlow
##   meters {chemical, overload}                    PlayerStateData
##   entropy {value, growth_rate}                   WorkspaceEntropyData (the scar)
##   climax_latched                                 PlayerStateMachine
##   walk_taken                                     CorporateParkManager
##   ransacked, ransack_seed, betrayal_realized     RansackedStateManager
##   has_hesitated, ambulance_armed                 Hesitation / Ambulance
##   decal_seed                                     SurfaceDegradation
##   bench_items [[x, y, item_id], ...]             SpatialGrid
## Seeds rebuild the debris and decals exactly. Ambient randomness (clutter spin,
## flicker) is not saved.
##
## SAFETY
## ------
## Writes go to <path>.tmp and are then renamed over the save, so a crash mid-write
## never leaves a truncated file. On load, unparseable data is moved aside to
## <path>.bad and a newer schema version is refused; either way the game boots fresh.
## last_error says why.

signal saved(path: String)
signal loaded(phase_name: String)

const VERSION := 1
## Calm granted when resuming a withdrawn save.
const WAKE_RELIEF_SECONDS := 12.0
const CHECKPOINTS: Array[GameFlow.Phase] = [
	GameFlow.Phase.WORKSPACE, GameFlow.Phase.RANSACKED, GameFlow.Phase.SCARRED
]

## Where the save lives. Tests point this elsewhere before booting the scene.
static var save_path: String = "user://save.json"

## Continue from the save on boot. T13's menu will ask instead.
@export var auto_load: bool = true
@export var auto_save: bool = true

@export var game_flow: GameFlow
@export var state_machine: PlayerStateMachine
@export var entropy_data: WorkspaceEntropyData
@export var park: CorporateParkManager
@export var ransacked: RansackedStateManager
@export var hesitation: HesitationController
@export var ambulance: AmbulanceInterception
@export var endgame: EndgameLoopManager
@export var spatial_grid: SpatialGrid
@export var decals: SurfaceDegradation
@export var day_cycle: DayCycle
@export var easel: Easel

## item_id → scene, to rebuild the bench worktop.
@export var item_scenes: Dictionary[StringName, PackedScene] = {}

## Why the last load or save failed ("" if it didn't).
var last_error: String = ""

## ----- LIFECYCLE -----------------------------------------------------------------------


func _ready() -> void:
	if game_flow != null:
		game_flow.phase_changed.connect(_on_phase_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_if_at_checkpoint()


## ----- PUBLIC API ---------------------------------------------------------------------


## Save only if at a checkpoint (quit paths). Returns true if a save was written.
func save_if_at_checkpoint() -> bool:
	return auto_save and _at_checkpoint() and save_game()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func wipe() -> void:
	delete_save()


## Delete the save without a running game (the main menu's New Game).
static func delete_save() -> void:
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))


static func save_exists() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	var tmp := save_path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		last_error = "cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())]
		push_warning("Persistence: " + last_error)
		return false
	# full_precision: the default rounds floats, which drifted seeds and meters.
	file.store_string(JSON.stringify(snapshot(), "\t", true, true))
	file.close()
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(save_path)
	)
	if err != OK:
		last_error = "cannot replace save (%s)" % error_string(err)
		push_warning("Persistence: " + last_error)
		return false
	last_error = ""
	saved.emit(save_path)
	return true


## Load and apply the save. Returns false (and leaves the fresh game running) if there
## is no usable save.
func load_game() -> bool:
	if not has_save():
		last_error = "no save"
		return false
	var text := FileAccess.get_file_as_string(save_path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		last_error = "save is not valid JSON; moved to %s.bad" % save_path
		push_warning("Persistence: " + last_error)
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(save_path),
			ProjectSettings.globalize_path(save_path + ".bad")
		)
		return false
	var version := int((data as Dictionary).get("version", 0))
	if version > VERSION or version < 1:
		last_error = "save version %d not supported (this build reads %d)" % [version, VERSION]
		push_warning("Persistence: " + last_error)
		return false
	apply(data)
	last_error = ""
	loaded.emit(str(data.get("phase", "")))
	return true


func snapshot() -> Dictionary:
	var data := {
		"version": VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"phase": game_flow.phase_name() if game_flow != null else "WORKSPACE",
		"loops_completed": game_flow.loops_completed if game_flow != null else 0,
	}
	if state_machine != null and state_machine.state_data != null:
		data["meters"] = {
			"chemical": state_machine.state_data.chemical_level,
			"overload": state_machine.state_data.sensory_overload,
		}
		data["climax_latched"] = state_machine.is_climax_latched()
	if entropy_data != null:
		data["entropy"] = {
			"value": entropy_data.entropy, "growth_rate": entropy_data.entropy_growth_rate
		}
	if park != null:
		data["walk_taken"] = park.walk_taken
	if ransacked != null:
		data["ransacked"] = ransacked.is_ransacked
		data["ransack_seed"] = ransacked.ransack_seed
		data["betrayal_realized"] = ransacked.is_betrayal_realized()
	if hesitation != null:
		data["has_hesitated"] = hesitation.has_hesitated
	if ambulance != null:
		data["ambulance_armed"] = ambulance.armed
	if decals != null:
		data["decal_seed"] = decals.layout_seed
	data["bench_items"] = _bench_items()
	if day_cycle != null:
		data["day"] = day_cycle.day
	if easel != null:
		data["painting"] = easel.snapshot()
	return data


## Apply a snapshot to a freshly booted game. Order matters: meters and entropy first,
## then the scars in arc order (walk, ransack, hesitation, climax), then the phase, so
## phase listeners (audio, VFX) see the restored world.
func apply(data: Dictionary) -> void:
	var meters: Dictionary = data.get("meters", {})
	if state_machine != null and state_machine.state_data != null:
		state_machine.state_data.chemical_level = float(meters.get("chemical", 0.5))
		state_machine.state_data.sensory_overload = float(meters.get("overload", 0.0))
		_wake_calm(state_machine.state_data)
	var entropy: Dictionary = data.get("entropy", {})
	if entropy_data != null and not entropy.is_empty():
		entropy_data.entropy = float(entropy.get("value", entropy_data.entropy))
		entropy_data.entropy_growth_rate = float(
			entropy.get("growth_rate", entropy_data.entropy_growth_rate)
		)
		entropy_data.entropy_changed.emit(entropy_data.entropy)
	if decals != null and int(data.get("decal_seed", 0)) != 0:
		decals.relayout(int(data["decal_seed"]))
	_restore_bench_items(data.get("bench_items", []))
	if day_cycle != null:
		day_cycle.restore(int(data.get("day", 1)))
	if easel != null and data.has("painting"):
		easel.restore(data["painting"])

	if park != null:
		park.walk_taken = bool(data.get("walk_taken", false))
	if ransacked != null and bool(data.get("ransacked", false)):
		ransacked.apply_ransack(int(data.get("ransack_seed", 0)), false)
		if bool(data.get("betrayal_realized", false)):
			ransacked.restore_betrayal_realized()
	if hesitation != null:
		hesitation.has_hesitated = bool(data.get("has_hesitated", false))
	if ambulance != null and bool(data.get("ambulance_armed", false)):
		ambulance.arm()

	var phase := _phase_from_name(str(data.get("phase", "WORKSPACE")))
	if phase == GameFlow.Phase.SCARRED and endgame != null:
		endgame.restore_scarred()
	elif bool(data.get("climax_latched", false)) and state_machine != null:
		state_machine.latch_climax()
	if game_flow != null:
		game_flow.restore(phase, int(data.get("loops_completed", 0)))


## ----- INTERNALS -------------------------------------------------------------------------


## A save made mid-withdrawal would otherwise resume straight into a compulsion or a
## collapse dream (playtest 2026-10-14). Resume below the crash, in a relief window.
func _wake_calm(data: PlayerStateData) -> void:
	if data.sensory_overload >= data.crash_overload_threshold:
		data.sensory_overload = data.crash_overload_threshold - 5.0
	if data.chemical_level <= 0.0:
		data.grant_relief(WAKE_RELIEF_SECONDS)


func _on_phase_changed(_from: GameFlow.Phase, _to: GameFlow.Phase) -> void:
	if auto_save and _at_checkpoint():
		save_game()


func _at_checkpoint() -> bool:
	return game_flow != null and CHECKPOINTS.has(game_flow.phase)


func _phase_from_name(phase_name: String) -> GameFlow.Phase:
	var idx := GameFlow.Phase.keys().find(phase_name)
	if idx == -1 or not CHECKPOINTS.has(idx):
		return GameFlow.Phase.WORKSPACE
	return idx as GameFlow.Phase


func _bench_items() -> Array:
	var out := []
	if spatial_grid == null:
		return out
	for x in spatial_grid.grid_cells.size():
		for y in (spatial_grid.grid_cells[x] as Array).size():
			var item: Node = spatial_grid.grid_cells[x][y]
			if item is InventoryItem:
				out.append([x, y, String((item as InventoryItem).item_id)])
	return out


func _restore_bench_items(items: Array) -> void:
	if spatial_grid == null:
		return
	for x in spatial_grid.grid_cells.size():
		for y in (spatial_grid.grid_cells[x] as Array).size():
			spatial_grid.remove_item(Vector2i(x, y))
	for entry in items:
		var id := StringName(str(entry[2]))
		if item_scenes.has(id):
			spatial_grid.place_item(item_scenes[id], Vector2i(int(entry[0]), int(entry[1])))
