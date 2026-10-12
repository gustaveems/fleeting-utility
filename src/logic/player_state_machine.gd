class_name PlayerStateMachine
extends Node
## LOGIC LAYER — controller for PlayerStateData, owns the update loop and threshold signals.
##
## This node advances the meters every frame and emits specific signals when thresholds
## are crossed, so UI and camera systems can react without polling the resource.
##
## SIGNALS
## -------
## overload_threshold_reached  emitted once when sensory_overload crosses crash_overload_threshold
##                             (rising edge). The Crash state begins.
## chemical_depleted           emitted once when chemical_level hits 0.0 (rising edge).
##                             The protagonist is fully withdrawn; overload will now
##                             accumulate at maximum rate.
##
## These are one-shot signals (emitted on the frame the threshold is crossed, not every
## frame the condition holds). Consumers should not assume they fire repeatedly.
##
## INTEGRATION WITH TICKET-01
## --------------------------
## This state machine is separate from PerceptionDirector (which owns the binary
## HIGH_FOCUS/CRASH state and crash_intensity 0..1 ramp). The two systems coexist:
##   - PlayerStateMachine owns the meters (chemical_level, sensory_overload) and emits
##     threshold signals for UI/camera.
##   - PerceptionDirector owns the perceptual state (which movement profile to use,
##     post-FX intensity) and is driven by the meters (via a future integration ticket).
## For now, PerceptionDirector is toggled manually (Tab key). A future ticket will wire
## PlayerStateMachine's threshold signals to PerceptionDirector.set_state(CRASH).

## Signal emitted once when sensory_overload crosses the crash threshold.
signal overload_threshold_reached

## Signal emitted once when chemical_level hits zero.
signal chemical_depleted

## Signal emitted once when the protagonist collapses into the dreamscape: chemical
## fully gone AND sensory_overload pinned at maximum (Ticket-05). Distinct from the
## crash threshold (50) — this is the knockout, not the bad trip. Rising-edge like the
## others; re-arms when the condition clears (which on_dreamscape_entered() guarantees).
signal dreamscape_transition_requested

## The resource this node controls. Exported so it can be assigned in the inspector or
## injected by GameBootstrap.
@export var state_data: PlayerStateData

## The room's clutter meter (Ticket-02). Assigned in the inspector or by GameBootstrap.
## If null, entropy stays at 0 and contributes no overload pressure — the degradation
## mechanic is opt-in via this one reference.
@export var entropy_data: WorkspaceEntropyData

## Overload restored on dreamscape return. He wakes lucid, unmedicated and immediately
## crashed again — the brief's "violent revival" — but not pinned at the knockout
## condition, so the transition can re-arm.
@export var post_dreamscape_overload: float = 50.0

## Internal flags to ensure threshold signals fire only once per crossing (rising edge).
var _overload_threshold_fired: bool = false
var _chemical_depleted_fired: bool = false
var _dreamscape_fired: bool = false

## Ticket-06: permanent climax latch. Once the dreamscape has been triggered and the
## forced return completed, this flag stays true forever — the dream can never re-fire,
## even if the meters somehow clear and re-meet the collapse condition.
var _climax_fired: bool = false

## Logic driver for entropy_data, built here so the scene tree never has to carry it.
var _entropy: WorkspaceEntropy


func _ready() -> void:
	if state_data == null:
		state_data = PlayerStateData.new()
		# Reset flags in case the resource was reused.
		_overload_threshold_fired = false
		_chemical_depleted_fired = false
	if entropy_data != null:
		_entropy = WorkspaceEntropy.new()
		_entropy.setup(entropy_data)


func _process(delta: float) -> void:
	if state_data == null:
		return

	# FRAME ORDER (matters):
	#   1. Entropy pressure lands FIRST so the overload value the chemical logic sees
	#      already includes this frame's clutter contribution.
	#   2. update_overload() then applies chemical decay/accumulation on top.
	# Both meters therefore agree within a single frame, and a frame never silently
	# discards entropy pressure because it arrived after the accumulation step.
	if _entropy != null:
		var pressure := _entropy.advance(delta)
		if pressure > 0.0:
			state_data.apply_overload_pressure(pressure)

	# Advance the meters. Returns true if a threshold was crossed.
	var threshold_crossed := state_data.update_overload(delta)

	if threshold_crossed:
		# Check which threshold was crossed and emit the appropriate signal (once).
		var overload_crossed := (
			state_data.sensory_overload >= state_data.crash_overload_threshold
			and not _overload_threshold_fired
		)
		if overload_crossed:
			_overload_threshold_fired = true
			overload_threshold_reached.emit()

		var chemical_empty := state_data.chemical_level <= 0.0 and not _chemical_depleted_fired
		if chemical_empty:
			_chemical_depleted_fired = true
			chemical_depleted.emit()

		# Reset flags if the meters drop back below thresholds (so the signal can fire
		# again on the next crossing). This allows the Crash state to be entered and
		# exited multiple times.
		if state_data.sensory_overload < state_data.crash_overload_threshold:
			_overload_threshold_fired = false
		if state_data.chemical_level > 0.0:
			_chemical_depleted_fired = false

	# Dreamscape knockout condition (Ticket-05): fully withdrawn AND maxed overload.
	# Checked every frame regardless of threshold_crossed, because at the pin the
	# meters stop changing and update_overload() stops reporting crossings.
	var collapse := state_data.chemical_level <= 0.0 and state_data.sensory_overload >= 100.0
	if collapse and not _dreamscape_fired and not _climax_fired:
		_dreamscape_fired = true
		dreamscape_transition_requested.emit()
	elif not collapse:
		_dreamscape_fired = false

	# Once the climax fires, it never re-arms — the dream is a one-way trip.
	if _dreamscape_fired:
		_climax_fired = true


## Dreamscape bookkeeping (called by DreamscapeManager, never by presentation code):
## the dream is serene, so the meters drop out of crash while he is under. This also
## disarms the collapse condition so the trigger cannot re-fire mid-dream.
func on_dreamscape_entered() -> void:
	if state_data == null:
		return
	state_data.sensory_overload = 0.0
	state_data.state_changed.emit(state_data)


## Ticket-06: latch the climax explicitly. Called by EndgameLoopManager at the forced
## return, BEFORE it pins the meters at the knockout condition. Latching only inside
## the collapse trigger missed dreams entered any other way (dev key, tests), and the
## post-climax pin then re-triggered a second dream and a second ambulance.
func latch_climax() -> void:
	_climax_fired = true
	_dreamscape_fired = true


## The violent return: lucid, unmedicated, crashed — but below the knockout pin.
func on_dreamscape_returned() -> void:
	if state_data == null:
		return
	state_data.sensory_overload = post_dreamscape_overload
	state_data.state_changed.emit(state_data)


## Convenience accessor for consumers that want to read the meters without holding a
## reference to the resource.
func get_state_data() -> PlayerStateData:
	return state_data


## Check if the protagonist is currently in the Crash state. Derived from the meters.
func is_crashed() -> bool:
	if state_data == null:
		return false
	return state_data.is_crashed()
