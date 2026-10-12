class_name WorkspaceEntropy
extends RefCounted
## LOGIC LAYER — drives WorkspaceEntropyData: growth + overload contribution.
##
## Pure logic: holds a reference to the data resource, advances it over time, and
## derives the per-frame overload pressure it would cause. No Node, no signals to the
## scene tree, no knowledge of who consumes the pressure — PlayerStateMachine calls
## advance() every frame and decides what to do with the returned float.
##
## SEPARATION OF CONCERNS
## ----------------------
## Resource (Data)     owns values + thresholds + the change signal.
## This class (Logic)  owns the rate math and the conversion entropy -> pressure.
## PlayerStateMachine  owns the frame loop and pushes pressure into PlayerStateData.
## Everything downstream (screen effects, camera) reads sensory_overload only — the
## entropy system disappears behind PlayerStateMachine, which is what keeps Ticket-02
## from leaking into Ticket-01 presentation code.

var _data: WorkspaceEntropyData


func setup(data: WorkspaceEntropyData) -> void:
	_data = data


func entropy() -> float:
	if _data == null:
		return 0.0
	return _data.entropy


## Advance the room's clutter by delta seconds. Returns the overload pressure this
## frame caused: entropy * feed_ratio * delta, already bounded by the data's clamps.
## The caller decides whether/how to apply it — no side effects here.
func advance(delta: float) -> float:
	if _data == null:
		return 0.0

	var before := _data.entropy
	_data.entropy = clampf(_data.entropy + _data.entropy_growth_rate * delta, 0.0, 100.0)
	if not is_equal_approx(before, _data.entropy):
		_data.entropy_changed.emit(_data.entropy)

	return _data.entropy * _data.overload_feed_ratio * delta


func reset() -> void:
	if _data != null:
		_data.reset()