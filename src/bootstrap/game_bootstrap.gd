class_name GameBootstrap
extends Node3D
## COMPOSITION ROOT — assembles the Ticket-01 scene at runtime.
##
## WHY CODE AND NOT A HAND-AUTHORED .tscn
## --------------------------------------
## scenes/Main.tscn is a single Node3D with this script. Everything below it is built
## here, because:
##   1. walls, grid lines and the footprint are derived from WorkspaceGridData, and a
##      scene file would duplicate that truth in serialised transforms that can rot;
##   2. a .gd is machine-checkable in this project's loop and a .tscn is not, so the
##      ticket can be validated without the editor open;
##   3. there is no art pipeline yet — every node here is a greybox named for the asset
##      that will replace it.
## The cost is stated plainly in docs/TICKET-01.md: nothing is editable in the 3D
## viewport until this is migrated into scene files, and the dev HUD/post-FX layer
## numbers must survive that move.
##
## WIRING MAP (who is allowed to know whom)
## ---------------------------------------
##   InputActionData -> PlayerController        (input -> facing)
##   PlayerController -> GridMover / TurnController   (intent -> committed state)
##   PlayerController -> PlayerView / IsoCameraRig    (state -> pixels, per frame)
##   PerceptionDirector -> IsoCameraRig, PerceptionPostFX   (intensity -> shake, shaders)
##   SoftBoundaryModel  -> SoftBoundaryPresentation, PerceptionPostFX (proximity -> fog, vignette)
## No node upstream of a signal asks what the consumer does with it. That is what lets
## Ticket-02 replace PerceptionDirector without touching a single presentation script.

var _grid: WorkspaceGridData
var _movement: WorkspaceMovementData
var _perception: PerceptionDirector
var _boundary: SoftBoundaryModel
var _state_data: PlayerStateData
var _state_machine: PlayerStateMachine
var _state_entropy: WorkspaceEntropyData

var _environment: Environment
var _light: DirectionalLight3D
var _overlay: GridOverlay3D
var _rig: IsoCameraRig
var _player: PlayerController
var _post_fx: PerceptionPostFX
var _boundary_presentation: SoftBoundaryPresentation
var _hud: DevHud


func _ready() -> void:
	InputActionData.register()
	_build_data()
	_build_world()
	_build_camera()
	_build_player()
	_build_effects()
	_build_hud()
	_wire()


## DATA LAYER
## Currently constructed in code with the class defaults. When design iteration starts,
## replace these two lines with preload()s of .tres assets and the rest of the tree is
## unaffected — that is the point of the split.
func _build_data() -> void:
	_grid = WorkspaceGridData.new()
	_movement = WorkspaceMovementData.new()
	_perception = PerceptionDirector.new()
	_boundary = SoftBoundaryModel.new()
	_state_data = PlayerStateData.new()
	_state_machine = PlayerStateMachine.new()
	_state_machine.state_data = _state_data
	# Ticket-02: the room degrades. Entropy data is created here rather than in a .tres
	# so both code pipeline and scene pipeline default to the same tuning numbers.
	_state_entropy = WorkspaceEntropyData.new()
	_state_machine.entropy_data = _state_entropy
	add_child(_state_machine)


## The room: dark, boxy, one window. Lighting is a single raking key plus cool ambient so
## the Crash post pass has something to smear; the autumn valley of Ticket-05 is the
## deliberate opposite of this.
func _build_world() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.045, 0.045, 0.05)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.55, 0.53, 0.50)
	_environment.ambient_light_energy = 0.45
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	# Fog starts thin and is driven up by SoftBoundaryPresentation. Enabling it here is
	# what makes constraint #6 possible at all: the edge has to be something the air can
	# do, not something a collider has to be.
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.30, 0.28, 0.26)
	_environment.fog_density = 0.006
	_environment.volumetric_fog_enabled = true
	_environment.volumetric_fog_density = 0.015

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = _environment
	add_child(world_env)

	_light = DirectionalLight3D.new()
	_light.name = "KeyLight"
	_light.light_energy = 1.15
	_light.light_color = Color(0.98, 0.90, 0.78)
	_light.shadow_enabled = true
	add_child(_light)
	# Low raking angle: reads the 1m grid through long shadows, which is how a fixed
	# isometric camera conveys floor depth at all.
	_light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)

	var blockout := WorkspaceBlockout.new()
	blockout.name = "WorkspaceBlockout"
	blockout.grid = _grid
	add_child(blockout)

	_overlay = GridOverlay3D.new()
	_overlay.name = "GridOverlay"
	add_child(_overlay)
	_overlay.configure(_grid)


func _build_camera() -> void:
	_rig = IsoCameraRig.new()
	_rig.name = "IsoCameraRig"
	add_child(_rig)


func _build_player() -> void:
	# grid/movement must be assigned before add_child(): PlayerController._ready() builds
	# its logic objects from them and asserts if they are missing.
	_player = PlayerController.new()
	_player.name = "Player"
	_player.grid = _grid
	_player.movement = _movement
	_player.setup(_perception, _boundary)
	add_child(_player)
	_player.bind_camera_rig(_rig)


func _build_effects() -> void:
	_boundary_presentation = SoftBoundaryPresentation.new()
	_boundary_presentation.name = "SoftBoundaryPresentation"
	add_child(_boundary_presentation)
	_boundary_presentation.bind(_environment, _light)

	_post_fx = PerceptionPostFX.new()
	_post_fx.name = "PerceptionPostFX"
	add_child(_post_fx)


func _build_hud() -> void:
	_hud = DevHud.new()
	_hud.name = "DevHud"
	add_child(_hud)
	_hud.bind(_player.mover(), _player.turn(), _perception, _boundary, _grid)
	_hud.bind_state_machine(_state_machine)


## Signal edges only. Presentation never polls logic, and logic never names presentation.
func _wire() -> void:
	_perception.crash_intensity_changed.connect(_post_fx.set_crash_intensity)
	_perception.crash_intensity_changed.connect(_rig.set_crash_intensity)
	_perception.focus_intensity_changed.connect(_post_fx.set_focus_intensity)
	_boundary.proximity_changed.connect(_post_fx.set_edge_proximity)
	_boundary.proximity_changed.connect(_boundary_presentation.set_proximity)


## Dev-only input. PlayerController deliberately does not know these keys exist: the
## focus toggle is a stub of Ticket-02's state machine and the grid is an authoring aid,
## so both belong to the harness, not to the movement pipeline.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(InputActionData.ACTION_TOGGLE_FOCUS_STATE):
		_perception.toggle()
	if Input.is_action_just_pressed(InputActionData.ACTION_TOGGLE_GRID):
		_overlay.show_overlay(not _overlay.visible)
