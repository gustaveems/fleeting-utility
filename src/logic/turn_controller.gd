class_name TurnController
extends RefCounted
## LOGIC LAYER — facing state and its commitment latency.
##
## Split out of GridMover on purpose: "reduced turn speed" (constraint #5) is a
## distinct mechanic from "slower movement", and Ticket-02 will want to degrade one
## without the other. Two responsibilities, two objects.
##
## THE MODEL
## ---------
## Turning is discrete (4 grid facings) but not instant. A request opens a window of
## `delay_seconds` during which the facing is *intended* but not *committed*. Only on
## commit does the facing change, and GridMover refuses to start a step until the facing
## it wants is the committed one. In Crash that window is ~5x longer, so the player
## feels the delay as the body refusing to answer, which is exactly the mechanic the
## brief asks for — and it is felt while standing still, not hidden inside a step.

## NOTE: signal parameters are intentionally untyped — GDScript 2.0 does not accept type
## annotations in signal declarations, so the contract is documented here instead.
signal turn_committed(facing)  # int: WorkspaceGridData.Facing

var _facing: int = WorkspaceGridData.Facing.NORTH
var _requested: int = -1
var _elapsed: float = 0.0
var _delay: float = 0.0


func facing() -> int:
	return _facing


## -1 when the turn is done. Presentation uses this to know when to stop rotating.
func requested_facing() -> int:
	return _requested


func turning() -> bool:
	return _requested != -1


## Open a turn window. Returns true if a new turn started, false if this facing is
## already committed or already in flight (so a held key does not restart the timer).
func request(facing: int, delay_seconds: float) -> bool:
	if facing == _facing or facing == _requested:
		return false
	_requested = facing
	_delay = maxf(0.0, delay_seconds)
	_elapsed = 0.0
	return true


func advance(delta: float) -> void:
	if not turning():
		return
	_elapsed += delta
	if _elapsed >= _delay:
		_facing = _requested
		_requested = -1
		turn_committed.emit(_facing)


## Hard-set for spawn/teleport, bypassing latency: the room ransacking in Ticket-04
## and the dreamscape transition in Ticket-05 both relocate the player instantly.
func snap(facing: int) -> void:
	_facing = facing
	_requested = -1
	_elapsed = 0.0
	turn_committed.emit(_facing)
