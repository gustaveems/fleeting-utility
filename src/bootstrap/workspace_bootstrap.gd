class_name WorkspaceBootstrap
extends Node3D
## COMPOSITION ROOT — the unified Task-pipeline scene (workspace.tscn).
##
## WHAT THIS IS
## ------------
## Every Task/Ticket script written so far is instantiated and wired HERE, so one F5
## runs the whole pipeline end-to-end:
##
##   PlayerStateMachine (+ PlayerStateData + WorkspaceEntropyData)   Tickets 02
##   PlayerMovement        (grid-snapped, crash-slowed tweens)       Task 2
##   WorkspaceCamera       (fixed iso, crash FOV breathing)          Task 3
##   ScreenEffects         (CA/blur/tremor + movement shake)         Task 4
##   SoftBoundaryController(vignette) + live edge-proximity drive    Task 3 (+ gap closed)
##   SpatialGrid + CraftingBench + RecipeDatabase                    Ticket 03
##   VisualClutterManager                                            Ticket 04 T1
##   SurfaceDegradation                                              Ticket 04 T2
##   AtmosphereController                                            Ticket 04 T3
##
## The Ticket-01 layered pipeline (Main.tscn/GameBootstrap) is the alternative
## architecture; keep exactly one in the tree. This file is what F5 loads.
##
## ITEM "SCENES" ARE PACKED AT RUNTIME
## -----------------------------------
## No editor-authored .tscn exists for clutter or items. PackedScene.pack() snapshots a
## bare class-annotated node (script + exported properties serialize; the placeholder
## children are auto-built by each class's _ready() on instantiate). Real art scenes
## replace these once the asset pipeline exists — the pack() sites are the only lines
## that change.
##
## DEMO SEED (deliberate, tunable)
## -------------------------------
## A from-clean boot is ~40 s of nothing happening while chemistry creeps, then it is
## over. So the scene starts mid-cycle: chemical 0.45 (no High-Focus, crossing the
## unmedicated threshold in ~8 s), entropy 38 (clutter batch + first decal batch
## already visible, lamp about to fail). Plus dev rig keys to drive the state on demand:
##   TAB  overload +20      T  entropy +20      R  entropy reset (full relief)

## --- TUNING --------------------------------------------------------------------------

## Where the BenchArea sits in room coordinates. Matches WorkspaceBlockout's
## CraftingBenchPlaceholder cell (1,1) in a 9x7 room.
const BENCH_ORIGIN := Vector3(-3.0, 0.0, -2.0)

## Desk lamp placement above the bench, warm incandescent — this is the base
## AtmosphereController scales the flicker from.
const LAMP_POSITION := Vector3(-3.0, 1.25, -2.0)
const LAMP_COLOR := Color(1.0, 0.85, 0.63)
const LAMP_ENERGY := 1.4
const LAMP_RANGE := 3.5

## Demo seed: start mid-cycle so the decay story is visible within the first minute.
const DEMO_CHEMICAL := 0.45
const DEMO_ENTROPY := 38.0

## Dev rig injection amounts.
const DEV_OVERLOAD_DUMP := 20.0
const DEV_ENTROPY_DUMP := 20.0

## --- INTERNAL STATE ------------------------------------------------------------------

var _grid: WorkspaceGridData
var _state_machine: PlayerStateMachine
var _state_data: PlayerStateData
var _entropy_data: WorkspaceEntropyData

var _world_env: WorldEnvironment
var _key_light: DirectionalLight3D
var _lamp: OmniLight3D

var _player: PlayerMovement
var _camera: WorkspaceCamera
var _screen_effects: ScreenEffects
var _boundary: SoftBoundaryController

var _bench_area: Node3D
var _spatial_grid: SpatialGrid
var _bench: CraftingBench

var _clutter: VisualClutterManager
var _decals: SurfaceDegradation
var _atmosphere: AtmosphereController

## Ticket-06: the interaction lock gate.
var _interaction_controller: InteractionController

## Ticket-05: the apartment as one toggleable subtree, plus the dream world.
var _apartment_root: Node3D
var _valley: DreamscapeEnvironment
var _dreamscape_manager: DreamscapeManager
var _ambulance: AmbulanceInterception

## Runtime-packed stand-ins for real .tscn assets.
var _raw_compound_scene: PackedScene
var _pill_scene: PackedScene
var _clutter_scene: PackedScene


## ----- LIFECYCLE ---------------------------------------------------------------------

func _ready() -> void:
	InputActionData.register()
	_build_prototypes()
	_build_data()
	_build_room()
	_build_player_pipeline()
	_build_effects()
	_build_bench()
	_build_dreamscape()


func _process(_delta: float) -> void:
	_drive_edge_proximity()
	_handle_dev_keys()


## ----- RUNTIME PROTOTYPE SCENES ------------------------------------------------------

func _build_prototypes() -> void:
	_raw_compound_scene = _pack_inventory(&"raw_compound")
	# The bench re-instantiates this per craft and overwrites item_id from the recipe;
	# the default id only seeds the placeholder color.
	_pill_scene = _pack_inventory(&"pill_bottle")
	var proto := ClutterItem.new()
	_clutter_scene = PackedScene.new()
	_clutter_scene.pack(proto)
	proto.free()


## Pack a bare InventoryItem with its id authored, so instantiate() carries the
## identity and _ready() builds the colored placeholder mesh.
func _pack_inventory(id: StringName) -> PackedScene:
	var item := InventoryItem.new()
	item.item_id = id
	var scene := PackedScene.new()
	scene.pack(item)
	item.free()
	return scene


## ----- DATA --------------------------------------------------------------------------

func _build_data() -> void:
	_grid = WorkspaceGridData.new()
	_state_data = PlayerStateData.new()
	_entropy_data = WorkspaceEntropyData.new()
	_state_machine = PlayerStateMachine.new()
	_state_machine.name = "PlayerStateMachine"
	_state_machine.state_data = _state_data
	_state_machine.entropy_data = _entropy_data
	add_child(_state_machine)
	_apply_demo_seed()


## ----- ROOM --------------------------------------------------------------------------

func _build_room() -> void:
	# The Environment values below are clean-room defaults only; AtmosphereController
	# owns them from its first _apply_atmosphere() onward.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.045, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.83, 0.80)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.30, 0.28, 0.26)
	env.fog_density = 0.004
	# Without this the fog paints the whole background its own color (default 1.0) and
	# the room floats in brown soup — confirmed on the first real render.
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	_world_env.environment = env
	add_child(_world_env)

	# Ticket-05: everything apartment-specific lives under one node so the dreamscape
	# transition can hide the whole room with a single visible flag. The WorldEnvironment
	# node stays OUTSIDE (its environment resource is swapped, not hidden), as do the
	# player, camera, post-FX and boundary — those persist across both worlds.
	_apartment_root = Node3D.new()
	_apartment_root.name = "Apartment"
	add_child(_apartment_root)

	_key_light = DirectionalLight3D.new()
	_key_light.name = "KeyLight"
	_key_light.light_energy = 1.15
	_key_light.light_color = Color(0.98, 0.90, 0.78)
	_key_light.shadow_enabled = true
	_key_light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	_apartment_root.add_child(_key_light)

	_lamp = OmniLight3D.new()
	_lamp.name = "DeskLamp"
	_lamp.light_energy = LAMP_ENERGY
	_lamp.light_color = LAMP_COLOR
	_lamp.omni_range = LAMP_RANGE
	_lamp.shadow_enabled = false  # a flickering shadow strobes; the key light owns shadows
	_lamp.position = LAMP_POSITION
	_apartment_root.add_child(_lamp)

	# Reused Ticket-01 presentation class purely for blockout geometry — the SurfaceDecal
	# batches project onto these walls/floor, which is why the room needs real surfaces.
	var blockout := WorkspaceBlockout.new()
	blockout.name = "WorkspaceBlockout"
	blockout.grid = _grid
	_apartment_root.add_child(blockout)


## ----- PLAYER + CAMERA ---------------------------------------------------------------

func _build_player_pipeline() -> void:
	_player = PlayerMovement.new()
	_player.name = "Player"
	# Free roam (2026-10-11 pivot): wall colliders from WorkspaceBlockout do containment;
	# the half-extents here are the tunneling safety clamp, inset past the wall faces.
	_player.room_half_extents = Vector2(
		float(_grid.width_cells) * _grid.cell_size * 0.5 - 0.35,
		float(_grid.depth_cells) * _grid.cell_size * 0.5 - 0.35
	)
	_player.state_machine = _state_machine
	add_child(_player)

	_camera = WorkspaceCamera.new()
	_camera.name = "WorkspaceCamera"
	_camera.state_machine = _state_machine
	add_child(_camera)
	# Seed the fixed iso standoff BEFORE binding the target: WorkspaceCamera lerps, so
	# starting at the resting position prevents a slide-in from the origin on frame 1.
	_camera.global_position = _player.global_position \
		+ _camera.camera_offset + Vector3(0.0, _camera.framing_lift, 0.0)
	_camera.set_target(_player)


## ----- EFFECTS -----------------------------------------------------------------------

func _build_effects() -> void:
	_screen_effects = ScreenEffects.new()
	_screen_effects.name = "ScreenEffects"
	_screen_effects.state_machine = _state_machine
	_screen_effects.player_movement = _player
	add_child(_screen_effects)

	_boundary = SoftBoundaryController.new()
	_boundary.name = "SoftBoundaryController"
	add_child(_boundary)

	_clutter = VisualClutterManager.new()
	_clutter.name = "ClutterField"
	# Position (0,0,0): the manager's 20 spawn positions are authored in room-absolute
	# coordinates and applied as LOCAL positions, so the node must sit at room origin.
	_clutter.entropy_data = _entropy_data
	_clutter.clutter_item_scene = _clutter_scene
	_apartment_root.add_child(_clutter)

	_decals = SurfaceDegradation.new()
	_decals.name = "SurfaceDegradation"
	_decals.entropy_data = _entropy_data
	_apartment_root.add_child(_decals)

	_atmosphere = AtmosphereController.new()
	_atmosphere.name = "AtmosphereController"
	_atmosphere.entropy_data = _entropy_data
	_atmosphere.world_environment = _world_env
	_atmosphere.key_light = _key_light
	_atmosphere.lamp = _lamp
	_apartment_root.add_child(_atmosphere)


## ----- CRAFTING ----------------------------------------------------------------------

func _build_bench() -> void:
	_bench_area = Node3D.new()
	_bench_area.name = "BenchArea"
	_bench_area.position = BENCH_ORIGIN
	_apartment_root.add_child(_bench_area)

	# 4x4 worktop centered on the placeholder box; cells span ±2m around it.
	_spatial_grid = SpatialGrid.new()
	_spatial_grid.name = "SpatialGrid"
	_spatial_grid.position = Vector3(-2.0, 0.45, -2.0)
	_bench_area.add_child(_spatial_grid)

	_bench = CraftingBench.new()
	_bench.name = "CraftingBench"
	_bench.spatial_grid = _spatial_grid
	_bench.recipe_database = RecipeDatabase.new()
	_bench.chemical_manager = _state_data
	_bench.result_item_scene = _pill_scene
	_bench_area.add_child(_bench)

	# Seed two raw compounds so a craft can be tested immediately: Space at (0,0),
	# then call the bench's interact() from the console
	#   get_node("/root/Workspace/BenchArea/CraftingBench").interact()
	# The result (an amber pill cube) lands in the first free cell on completion.
	_spatial_grid.place_item(_raw_compound_scene, Vector2i(0, 0))
	_spatial_grid.place_item(_raw_compound_scene, Vector2i(1, 0))


## ----- DREAMSCAPE (Ticket-05) ----------------------------------------------------------

func _build_dreamscape() -> void:
	_valley = DreamscapeEnvironment.new()
	_valley.name = "DreamscapeValley"
	add_child(_valley)

	_dreamscape_manager = DreamscapeManager.new()
	_dreamscape_manager.name = "DreamscapeManager"
	_dreamscape_manager.workspace_root = _apartment_root
	_dreamscape_manager.dreamscape_root = _valley
	_dreamscape_manager.world_environment = _world_env
	_dreamscape_manager.apartment_environment = _world_env.environment
	_dreamscape_manager.valley_environment = _valley.valley_environment
	_dreamscape_manager.player = _player
	_dreamscape_manager.state_machine = _state_machine
	_dreamscape_manager.camera = _camera
	add_child(_dreamscape_manager)

	# The trigger signal is wired by DreamscapeManager itself (guarded self-connect);
	# only the statue-proximity edge lives here, because the valley is bootstrap-built.
	_valley.statue_proximity_changed.connect(_dreamscape_manager.set_statue_proximity)

	# Wire memory anchors to the manager (created by DreamscapeEnvironment).
	for child in _valley.get_children():
		if child is MemoryAnchor:
			child.dreamscape_manager = _dreamscape_manager

	# Dreamscape HUD: countdown timer + "Interact to Return" prompt.
	var hud := DreamscapeHud.new()
	hud.name = "DreamscapeHud"
	hud.dreamscape_manager = _dreamscape_manager
	add_child(hud)

	# Ticket-06: the ambulance interception. Arms 15 s into each dream, seals the exits,
	# then forces a violent return.
	_ambulance = AmbulanceInterception.new()
	_ambulance.name = "AmbulanceInterception"
	_ambulance.dreamscape_manager = _dreamscape_manager
	_ambulance.screen_effects = _screen_effects
	_ambulance.valley_root = _valley
	add_child(_ambulance)

	# Ticket-06: the interaction lock gate.
	_interaction_controller = InteractionController.new()
	_interaction_controller.name = "InteractionController"
	add_child(_interaction_controller)

	# Wire the interaction controller to the bench and dreamscape manager.
	_bench.interaction_controller = _interaction_controller
	_dreamscape_manager.interaction_controller = _interaction_controller

	# Ticket-06: the violent forced return flips the apartment into clinical mode AND
	# locks all interactions AND puts the player into withdrawal.
	_dreamscape_manager.forced_return_completed.connect(_on_forced_return)


## ----- DEMO SEED + DEV RIG -------------------------------------------------------------

func _apply_demo_seed() -> void:
	_state_data.chemical_level = DEMO_CHEMICAL
	_entropy_data.entropy = DEMO_ENTROPY
	# Managers read the stored value at their own _ready(), so the seed is reflected
	# without emitting a signal first.


func _handle_dev_keys() -> void:
	if Input.is_action_just_pressed(InputActionData.ACTION_DEV_DUMP_OVERLOAD):
		_state_data.apply_overload_pressure(DEV_OVERLOAD_DUMP)
	if Input.is_action_just_pressed(InputActionData.ACTION_DEV_DUMP_ENTROPY):
		_entropy_data.entropy = clampf(
			_entropy_data.entropy + DEV_ENTROPY_DUMP, 0.0, 100.0
		)
		_entropy_data.entropy_changed.emit(_entropy_data.entropy)
	if Input.is_action_just_pressed(InputActionData.ACTION_DEV_RESET_ENTROPY):
		_entropy_data.reset()


## Live vignette drive — the Ticket-03 guide's known gap, closed here. Edge proximity
## is computed from the room footprint (same math as WorkspaceBlockout) each frame.
func _drive_edge_proximity() -> void:
	if _boundary == null or _player == null:
		return
	var cell := _grid.world_to_cell(_player.global_position)
	# Outside the apartment footprint (i.e. in the valley) there is no room edge to
	# express — without this guard the out-of-range cell reads as closeness 1.0 and
	# the vignette would close in across the whole dreamscape.
	if not _grid.contains(cell):
		_boundary.set_edge_proximity(0.0)
		return
	_boundary.set_edge_proximity(_grid.edge_closeness(cell))


## Ticket-06: the post-climax state. Clinical lighting, locked interactions, withdrawal
## movement, meters pinned (chemical 0, overload 100), but screen effects capped so the
## player remains lucid.
func _on_forced_return() -> void:
	_atmosphere.set_clinical_mode(true)
	_interaction_controller.is_locked = true
	_player.is_in_withdrawal = true
	_state_data.chemical_level = 0.0
	_state_data.sensory_overload = 100.0
	_screen_effects.lucid_cap = 0.5
	_camera.withdrawal_shake = 0.02
