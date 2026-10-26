class_name LeaseRenewal
extends Node
## LOGIC — what happens after the scarred reset ("The lease renews."). The EndCard
## offers both; this node carries them out.
##
## renew()      a new cycle in the same apartment. Every beat re-arms (stash, bench,
##              walk, betrayal, hesitation, climax). The scars carry and escalate:
##              entropy's growth rate keeps compounding (×1.5 per reset, applied by
##              EndgameLoopManager), the room starts more decayed, the stash shrinks.
## walk_away()  the story ends: the save is cleared and the game returns to the menu.

## Loaded by path (see PauseMenu): a preload would cycle with boot.tscn.
const MENU_SCENE_PATH := "res://scenes/boot.tscn"

const START_CHEMICAL := 0.45
const BASE_ENTROPY := 38.0
const ENTROPY_PER_CYCLE := 12.0
const MAX_START_ENTROPY := 65.0  # below the door's 70: the walk must still be earned

@export var game_flow: GameFlow
@export var state_machine: PlayerStateMachine
@export var entropy_data: WorkspaceEntropyData
@export var endgame: EndgameLoopManager
@export var ransacked: RansackedStateManager
@export var park: CorporateParkManager
@export var hesitation: HesitationController
@export var ambulance: AmbulanceInterception
@export var spatial_grid: SpatialGrid
@export var persistence: Persistence
@export var compound_scene: PackedScene
@export var day_cycle: DayCycle
@export var act_one: ActOne
@export var promises: Promises


func renew() -> void:
	var loops := game_flow.loops_completed if game_flow != null else 1
	if ransacked != null:
		ransacked.reset_cycle()
	if endgame != null:
		endgame.reset_cycle()
	if state_machine != null:
		state_machine.reset_climax()
	if ambulance != null:
		ambulance.reset_cycle()
	if park != null:
		park.walk_taken = false
	if hesitation != null:
		hesitation.has_hesitated = false
	if state_machine != null and state_machine.state_data != null:
		var data := state_machine.state_data
		data.chemical_level = START_CHEMICAL
		data.sensory_overload = 0.0
		data.relief_seconds = 0.0
		data.state_changed.emit(data)
	if entropy_data != null:
		entropy_data.entropy = minf(BASE_ENTROPY + ENTROPY_PER_CYCLE * loops, MAX_START_ENTROPY)
		entropy_data.entropy_changed.emit(entropy_data.entropy)
	_restock(stash_compounds(loops))
	if day_cycle != null:
		day_cycle.reset_cycle()
	if act_one != null:
		act_one.reset_cycle()
	if promises != null:
		promises.reset_cycle()
	if game_flow != null:
		game_flow.restore(GameFlow.Phase.WORKSPACE, loops)


## Compounds on the worktop at the start of a cycle: 4 (two doses) on the first, then
## one dose a cycle. The supply only shrinks.
static func stash_compounds(loops_completed: int) -> int:
	return 4 if loops_completed <= 0 else 2


func walk_away() -> void:
	if persistence != null:
		persistence.auto_save = false
	Persistence.delete_save()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _restock(count: int) -> void:
	if spatial_grid == null or compound_scene == null:
		return
	for x in spatial_grid.grid_width:
		for y in spatial_grid.grid_depth:
			spatial_grid.remove_item(Vector2i(x, y))
	# remove_item frees on the next frame; place into the cleared occupancy now.
	for i in count:
		spatial_grid.place_item(
			compound_scene, Vector2i(i % spatial_grid.grid_width, i / spatial_grid.grid_width)
		)
