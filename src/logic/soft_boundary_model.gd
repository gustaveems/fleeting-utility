class_name SoftBoundaryModel
extends RefCounted
## LOGIC LAYER — how close to the edge of the leased room the player currently is.
##
## Constraint #6 is a promise about feedback: the workspace ends, but the player is
## never stopped by an invisible wall. This class produces the number that lets
## Presentation keep that promise — a single 0..1 proximity value — and owns the two
## ways it rises:
##
##   1. PROXIMITY  standing near a wall ramps the veil continuously, using
##                 WorkspaceGridData.edge_closeness() over soft_edge_band_cells.
##   2. IMPULSE    a refused step (GridMover.step_refused) injects a full impulse that
##                 decays over `impulse_decay_seconds`, so pressing a key into the wall
##                 blooms the vignette and fogs in. The rejection is seen, not bumped.
##
## Consumers subscribe; nobody here references a shader, a camera, or a Node.

## NOTE: signal parameters are intentionally untyped — GDScript 2.0 does not accept type
## annotations in signal declarations. Payload: proximity (float 0..1).
signal proximity_changed(proximity)

var _grid: WorkspaceGridData
var _proximity: float = 0.0
var _impulse: float = 0.0
var _impulse_decay_seconds: float = 1.4

## Only push when the value actually moves: these signals drive shader uniforms and fog
## density every frame otherwise, which is wasted work during a long idle.
var _last_emitted: float = -1.0


func setup(grid: WorkspaceGridData) -> void:
	_grid = grid


func proximity() -> float:
	return _proximity


## Called by PlayerController on GridMover.step_refused.
func notify_refusal() -> void:
	_impulse = 1.0


func advance(delta: float, cell: Vector2i) -> void:
	var base := 0.0
	if _grid != null:
		base = _grid.edge_closeness(cell)
	_impulse = clampf(_impulse - delta / maxf(_impulse_decay_seconds, 0.0001), 0.0, 1.0)

	# Impulse wins when stronger, so a wall-touch reads as a bloom rather than an
	# addition on top of the ambient edge gradient.
	var next := clampf(maxf(base, _impulse), 0.0, 1.0)
	if not is_equal_approx(next, _proximity):
		_proximity = next
		if absf(next - _last_emitted) > 0.004:
			_last_emitted = next
			proximity_changed.emit(next)


## Forced clear, for scene transitions (Ticket-05 dreamscape) where the room is gone.
func reset(cell: Vector2i) -> void:
	_impulse = 0.0
	_proximity = 0.0
	_last_emitted = -1.0
	if _grid != null:
		_proximity = _grid.edge_closeness(cell)
		_last_emitted = _proximity
