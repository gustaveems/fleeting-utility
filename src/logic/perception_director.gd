class_name PerceptionDirector
extends Node
## LOGIC LAYER — which side of the Chemical Cycle the protagonist is on.
##
## TICKET-05 TASK 2 — promoted from RefCounted to Node so it can run _process().
##
## ORIGINAL TICKET-01/02 (preserved, untouched API):
##   FocusState enum, state(), is_crashed(), crash_intensity(), focus_intensity(),
##   set_state(), toggle(), advance(), state_name(), and the three intensity signals.
##   All existing consumers of the legacy pipeline (Main.tscn / GameBootstrap) are
##   unaffected: they call advance() in their own _process, and the RefCounted->Node
##   change is transparent at the call site.
##
## TICKET-05 CRASH TRIGGER (new):
##   In _process(), monitors the PlayerStateMachine for the knockout condition:
##     chemical_level <= 0.0 AND sensory_overload >= 100.0
##   When BOTH hold for a continuous 0.3 s (debounce — chemical can bounce above 0.0
##   for a single frame at the threshold and the trigger must not flutter), the crash
##   sequence fires: crash_state_entered signal, transition_to_dreamscape(), input
##   lock, and a one-frame intensity burst via crash_intensity_changed.
##
##   The is_in_dreamscape flag gates re-entry; it is set true when the sequence fires
##   and the director must be told to clear it on return (see reset_from_dreamscape()).
##   The dreamscape manager already owns the actual transition and return logic; this
##   class is the *trigger* side, not the *state* side.

## --- ORIGINAL SIGNALS (untouched) ----------------------------------------------------------

signal state_changed(focus_state)
signal crash_intensity_changed(intensity)
signal focus_intensity_changed(intensity)

## --- TICKET-05 SIGNAL -------------------------------------------------------------------------

## Emitted when the knockout condition fires after the debounce — one-off, not pulsed.
signal crash_state_entered

## --- ORIGINAL ENUM (untouched) ----------------------------------------------------------------

enum FocusState {
	HIGH_FOCUS = 0,
	CRASH = 1,
}

## --- TICKET-05 DEPENDENCIES (new) -------------------------------------------------------------

@export var player_state_machine: PlayerStateMachine

## The dreamscape transition controller.
@export var dreamscape_manager: DreamscapeManager

## Placeholder for the future InteractionController (null-safe).
@export var interaction_controller: Node

## Trigger debounce (spec: "handle the edge case where chemical_level bounces above 0.0
## right at the threshold"). The condition must hold continuously for this long before
## the sequence fires.
@export var debounce_seconds: float = 0.3

## --- ORIGINAL + NEW REGULAR STATE --------------------------------------------------------------

## Gates re-entry; set true when the sequence fires, false from reset_from_dreamscape().
var is_in_dreamscape: bool = false

var _transition_seconds: float = 1.2

var _state: int = FocusState.HIGH_FOCUS
var _crash_intensity: float = 0.0
var _focus_intensity: float = 0.0

var _debounce_timer: float = 0.0
var _sequence_fired: bool = false


## ----- ORIGINAL API (untouched) ---------------------------------------------------------------

func state() -> int:
	return _state


func is_crashed() -> bool:
	return _state == FocusState.CRASH


func crash_intensity() -> float:
	return _crash_intensity


func focus_intensity() -> float:
	return _focus_intensity


func set_state(next_state: int) -> void:
	if next_state == _state:
		return
	_state = next_state
	state_changed.emit(_state)


func toggle() -> void:
	set_state(FocusState.CRASH if _state == FocusState.HIGH_FOCUS else FocusState.HIGH_FOCUS)


func advance(delta: float) -> void:
	var target := 1.0 if _state == FocusState.CRASH else 0.0
	var opposite := 0.0 if target == 1.0 else 1.0
	var rate := delta / maxf(_transition_seconds, 0.0001)

	if not is_equal_approx(_crash_intensity, target):
		_crash_intensity = clampf(_crash_intensity + signf(target - _crash_intensity) * rate, 0.0, 1.0)
		crash_intensity_changed.emit(_crash_intensity)

	if not is_equal_approx(_focus_intensity, opposite):
		_focus_intensity = clampf(_focus_intensity + signf(opposite - _focus_intensity) * rate, 0.0, 1.0)
		focus_intensity_changed.emit(_focus_intensity)


func state_name() -> String:
	return "CRASH" if _state == FocusState.CRASH else "HIGH-FOCUS"


## ----- TICKET-05: _PROCESS + TRIGGER (new) ----------------------------------------------------

## Runs every frame when instantiated by a pipeline that gives this object a parent
## (i.e. when it is a Node in the tree). The legacy GameBootstrap pipeline never adds
## PerceptionDirector to the tree — it calls advance() externally — so the trigger path
## is inert in that pipeline: no tree, no _process(), no double-fire risk.
func _process(delta: float) -> void:
	# Preserve the original ramp behaviour from the RefCounted era.
	advance(delta)

	if player_state_machine == null or dreamscape_manager == null:
		return
	if is_in_dreamscape or _sequence_fired:
		return

	var data := player_state_machine.state_data
	if data == null:
		return

	var collapse := data.chemical_level <= 0.0 and data.sensory_overload >= 100.0
	if collapse:
		_debounce_timer += delta
		if _debounce_timer >= debounce_seconds and not _sequence_fired:
			_sequence_fired = true
			initiate_crash_sequence()
	else:
		_debounce_timer = 0.0
		_sequence_fired = false


## ----- TICKET-05: CRASH SEQUENCE (new) --------------------------------------------------------

func initiate_crash_sequence() -> void:
	crash_state_entered.emit()
	is_in_dreamscape = true

	# One-frame intensity burst: push crash_intensity to 1.0 so any consumer that
	# cares about the legacy signal (or the pincushion for a future ScreenEffects
	# listener) sees a full spike before the dreamscape calms the meters to zero.
	crash_intensity_changed.emit(1.0)

	if interaction_controller != null and interaction_controller.has_method("set_enabled"):
		interaction_controller.call("set_enabled", false)

	dreamscape_manager.transition_to_dreamscape()


## Called externally (by DreamscapeManager or the bootstrap) when the dreamscape ends
## and the apartment is restored. Clears the gating flags so the trigger can re-arm
## — chemical will still be 0.0 on return, but overload is reset to ~50 by
## PlayerStateMachine.on_dreamscape_returned(), so the collapse condition will not
## immediately re-trigger. If overload were still >= 100 the trigger would fire after
## the debounce, which is exactly the re-firing case the debounce exists for.
func reset_from_dreamscape() -> void:
	is_in_dreamscape = false
	_debounce_timer = 0.0
	_sequence_fired = false