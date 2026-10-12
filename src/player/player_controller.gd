class_name PlayerController
extends Node3D
## LOGIC/PRESENTATION GLUE — the only node that reads input, and the only place the two
## halves of Ticket-01 are allowed to meet.
##
## PIPELINE (every frame, in this order)
## ------------------------------------
##   1. resolve the active MovementProfileData from PerceptionDirector's state
##   2. advance the state machines (perception ramp, turn latency, step timer)
##   3. poll held keys and translate them into a turn request or a step request
##   4. push the resulting state into PlayerView and IsoCameraRig
##
## Advancing before polling is deliberate: when TurnController commits a facing on this
## frame, the held key is seen in the same frame and the step starts immediately. Reverse
## the order and every turn costs a wasted frame, which in the Crash state reads as input
## dropping rather than as slowness.
##
## Note what is *not* here: no world coordinates (WorkspaceGridData owns those), no
## shader uniforms (PerceptionPostFX owns those), no wall physics (there is none — a
## refused step becomes a soft-boundary impulse, constraint #6).

signal cell_changed(cell)  # Vector2i, fired when a step commits. Ticket-03/04 listeners.

## Authored by GameBootstrap (or the inspector) before add_child(). Kept as exports so a
## later ticket can hand a level its own footprint and tuning without code.
@export var grid: WorkspaceGridData
@export var movement: WorkspaceMovementData

var _perception: PerceptionDirector
var _boundary: SoftBoundaryModel
var _rig: IsoCameraRig

var _turn: TurnController
var _mover: GridMover
var _view: PlayerView


func _ready() -> void:
	assert(
		grid != null and movement != null,
		"PlayerController needs grid + movement assigned before add_child()"
	)
	assert(
		_perception != null and _boundary != null,
		"Call PlayerController.setup() before add_child()"
	)

	_turn = TurnController.new()
	_mover = GridMover.new()
	_mover.setup(grid, _turn, grid.spawn_cell)

	_view = PlayerView.new()
	_view.name = "View"
	add_child(_view)
	_view.configure(grid, grid.spawn_cell)
	_view.set_target_yaw(grid.facing_yaw(_turn.facing()))

	_mover.step_started.connect(_view.begin_step)
	_mover.step_completed.connect(_view.settle)
	_mover.step_completed.connect(func(cell: Vector2i) -> void: cell_changed.emit(cell))
	_mover.step_refused.connect(_on_step_refused)
	_turn.turn_committed.connect(_on_turn_committed)


## Injection happens before add_child() so _ready() can rely on it.
func setup(perception: PerceptionDirector, boundary: SoftBoundaryModel) -> void:
	_perception = perception
	_boundary = boundary
	_boundary.setup(grid)
	_boundary.reset(grid.spawn_cell)


func bind_camera_rig(rig: IsoCameraRig) -> void:
	_rig = rig
	if rig != null:
		rig.bind_target(_view)


func player_view() -> PlayerView:
	return _view


## Read-only accessors for the dev harness. Deliberately getters, not public fields: the
## HUD must not be able to mutate movement state, and a typo like `_player._cell = ...`
## should not be one keystroke away.
func mover() -> GridMover:
	return _mover


func turn() -> TurnController:
	return _turn


func current_cell() -> Vector2i:
	return _mover.cell()


## Facing arrives as a grid direction; the body needs a world yaw. The conversion lives
## in WorkspaceGridData so logic and presentation can never disagree about it.
func _on_turn_committed(facing: int) -> void:
	_view.set_target_yaw(grid.facing_yaw(facing))


## A refused step is the soft-boundary trigger (constraint #6): hitting the limit of
## owned space must bloom the vignette/fog, not rattle a collider.
func _on_step_refused(_cell: Vector2i, _facing: int) -> void:
	_boundary.notify_refusal()


func _process(delta: float) -> void:
	var profile := movement.profile_for(_perception.state())

	_perception.advance(delta)
	_turn.advance(delta)
	_mover.advance(delta)

	_apply_input(profile)

	_view.advance(_mover.step_alpha(), profile.step_arc_height)
	_view.rotate_towards(delta, profile.turn_speed_degrees_per_second)
	_boundary.advance(delta, _mover.cell())
	if _rig != null:
		_rig.set_follow_time(profile.camera_follow_time)


## Turn and step are separate commitments (see TurnController). A key held towards a
## facing we are not yet pointing at buys a turn, not a move — so in the Crash state the
## player visibly arrives late to their own decision.
func _apply_input(profile: MovementProfileData) -> void:
	var wanted := InputActionData.polled_facing()
	if wanted < 0:
		return
	if wanted != _turn.facing():
		_turn.request(wanted, profile.turn_commit_delay_seconds)
		return
	_mover.request_move(wanted, profile)
