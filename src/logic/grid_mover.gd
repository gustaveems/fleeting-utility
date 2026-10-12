class_name GridMover
extends RefCounted
## LOGIC LAYER — discrete grid position and one-cell-at-a-time stepping.
##
## Strictly cell-space: it stores Vector2i and never a Vector3, and it does not know
## what a camera is. Conversion to world space happens once, in WorkspaceGridData, and
## only Presentation interpolates. That is the separation-of-concerns requirement from
## the brief, and it is what makes this class trivially unit-testable once a Godot test
## framework is in place (see docs/TICKET-01.md, "Not verified").
##
## STEP MODEL
## ----------
## One step in flight at a time, no path queue. `request_move()` starts a step only if
## (a) nothing is stepping, (b) the wanted facing is already committed, and (c) the
## target cell is inside the room. Repeated presses from a held key therefore chain
## steps frame by frame, giving continuous walking out of discrete 1m commits — the
## "grid-snapped but not jerky" behaviour constraint #3 actually needs.
##
## A step against a wall is refused rather than blocked mid-motion. Because motion only
## ever starts from a settled cell centre, the player never vibrates against an
## invisible surface; the wall is felt through SoftBoundaryModel's vignette instead
## (constraint #6).

## NOTE: signal parameters are intentionally untyped — GDScript 2.0 does not accept type
## annotations in signal declarations. Payload types, in declaration order:
##   step_started     (Vector2i from_cell, Vector2i to_cell)
##   step_completed   (Vector2i cell)
##   step_refused     (Vector2i cell, int facing)
signal step_started(from_cell, to_cell)
signal step_completed(cell)
signal step_refused(cell, facing)

var _grid: WorkspaceGridData
var _turn: TurnController
var _cell: Vector2i = Vector2i.ZERO

var _stepping: bool = false
var _from: Vector2i = Vector2i.ZERO
var _to: Vector2i = Vector2i.ZERO
var _elapsed: float = 0.0
var _duration: float = 0.18


func setup(grid: WorkspaceGridData, turn: TurnController, spawn_cell: Vector2i) -> void:
	_grid = grid
	_turn = turn
	_cell = spawn_cell
	_from = spawn_cell
	_to = spawn_cell
	_stepping = false
	_elapsed = 0.0


func cell() -> Vector2i:
	return _cell


func facing() -> int:
	return _turn.facing()


func stepping() -> bool:
	return _stepping


## Where the body is right now, in cell coordinates. Mid-step this is still the origin
## cell — the position only commits at completion, so nothing downstream can half-occupy
## two cells (matters for Ticket-03 crafting-bench interaction ranges).
func target_cell() -> Vector2i:
	return _to if _stepping else _cell


## Eased 0..1 progress of the in-flight step. Feeds PlayerView's interpolation.
func step_alpha() -> float:
	if not _stepping:
		return 1.0
	var t := clampf(_elapsed / maxf(_duration, 0.0001), 0.0, 1.0)
	# Smoothstep curve: accelerate out of the snap, settle into it. Written out rather
	# than using ease() so the curve is explicit and its constants are not deprecated.
	return t * t * (3.0 - 2.0 * t)


## Endpoints of the in-flight step in cell coordinates (identical when idle).
func step_from() -> Vector2i:
	return _from


func step_to() -> Vector2i:
	return _to


## Attempt to start a step in `facing`. Returns false if the step was refused, which is
## a legitimate soft-boundary event, not an error.
func request_move(facing: int, profile: MovementProfileData) -> bool:
	if _stepping:
		return false
	# Turning and stepping are separate commitments: the facing must land first.
	if facing != _turn.facing():
		return false
	var next := _cell + WorkspaceGridData.facing_offset(facing)
	if not _grid.contains(next):
		step_refused.emit(_cell, facing)
		return false
	_from = _cell
	_to = next
	_elapsed = 0.0
	_duration = maxf(0.02, profile.step_duration_seconds)
	_stepping = true
	step_started.emit(_from, _to)
	return true


func advance(delta: float) -> void:
	if not _stepping:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_stepping = false
		_cell = _to
		step_completed.emit(_cell)
