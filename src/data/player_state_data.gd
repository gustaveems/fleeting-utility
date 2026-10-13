class_name PlayerStateData
extends Resource
## DATA LAYER — the protagonist's current physiological state.
##
## Two meters drive the Chemical Cycle (MASTER_BRIEF.md #1):
##   chemical_level     0..1   how much of the focus drug is in the system
##   sensory_overload   0..100 how overwhelmed the nervous system is
##
## State derivation (Ticket-02, locked design):
##   Crash      == sensory_overload >= crash_overload_threshold (the ONLY crash trigger)
##   High-Focus == chemical_level > high_focus_threshold AND not crashed
##   otherwise     medicated drift
## The meters interact: low chemical accelerates overload accumulation (chemical == 0.0
## floods it at chemical_zero_accumulation_rate), so a fully depleted drug *guarantees*
## a crash within ~1.25 s without itself being a crash trigger.
##
## This resource is pure data + signals. It does not know about movement, camera, or
## shaders. The state machine (PlayerStateMachine) owns the update loop and emits
## threshold signals for UI/camera listeners.

## Signal emitted whenever either meter changes. Consumers receive the whole resource so
## they can read both meters in one callback instead of subscribing to two.
signal state_changed(new_state_data: PlayerStateData)

## Thresholds at which state transitions occur. Exposed so designers can tune without
## editing code.
@export var crash_overload_threshold: float = 50.0
@export var recovery_chemical_threshold: float = 0.3

## Above this chemical_level the protagonist is in High-Focus (clear vision, fast
## interactions). Ticket-02's third band: > high_focus_threshold = High-Focus,
## < recovery_chemical_threshold = unmedicated accumulation, 0.0 = fully withdrawn.
@export var high_focus_threshold: float = 0.7

## Rate at which sensory_overload accumulates per second when unmedicated. Tunable so
## the Crash can feel like a slow burn or a sudden collapse.
@export var overload_accumulation_rate: float = 8.0

## Maximum accumulation rate when chemical_level hits exactly 0.0. The protagonist is
## fully withdrawn: overload floods in — roughly 1.25 s to cross a 50.0 crash threshold
## at 40.0/s. High-Focus is a cliff, not a slope, once the drug is gone.
@export var chemical_zero_accumulation_rate: float = 40.0

## Rate at which sensory_overload decays per second when medicated. Should be slower
## than accumulation, so the drug buys time but doesn't instantly fix things.
@export var overload_decay_rate: float = 3.0

## Rate at which chemical_level depletes per second. The drug doesn't last forever.
@export var chemical_depletion_rate: float = 0.02

## Current grid position (cell coordinates). Updated by GridMover on step completion.
var current_grid_position: Vector2i = Vector2i.ZERO

## Which way the protagonist is facing (grid direction vector, not enum). Updated by
## TurnController on turn commitment.
var facing_direction: Vector2i = Vector2i(0, -1)  # NORTH by default

## 0..1 — how much of the focus-enhancing drug is in the system. 1.0 = fully medicated,
## 0.0 = completely withdrawn. Depletes over time; replenished by taking a pill cooked at
## the bench (BenchStation).
var chemical_level: float = 1.0

## 0..100 — how overwhelmed the nervous system is. Rises when unmedicated or when the
## protagonist is exposed to sensory stimuli (crowds, bright lights, the ransacked room
## in Ticket-04). Falls when medicated or when the protagonist engages in self-soothing
## (Ticket-03). When this exceeds a threshold, the Crash state triggers.
var sensory_overload: float = 0.0

## Seconds of calm left after a soothed compulsion (or a calm wake from a save): no
## withdrawal flood, no outside pressure, the meter eases down. Without it a withdrawn
## player re-entered the compulsion within a second of leaving it and could never act
## (playtest 2026-10-14).
var relief_seconds: float = 0.0


## Called every frame by PlayerStateMachine. Advances the meters based on current state.
## Returns true if either meter crossed a threshold this frame (so the state machine can
## emit the appropriate signal).
func update_overload(delta: float) -> bool:
	var old_overload := sensory_overload
	var old_chemical := chemical_level

	# Chemical depletes constantly. When it hits zero, the protagonist is fully withdrawn.
	chemical_level = clampf(chemical_level - chemical_depletion_rate * delta, 0.0, 1.0)

	if relief_seconds > 0.0:
		relief_seconds = maxf(relief_seconds - delta, 0.0)
		sensory_overload = clampf(sensory_overload - overload_decay_rate * delta, 0.0, 100.0)
		if (
			not is_equal_approx(old_overload, sensory_overload)
			or not is_equal_approx(old_chemical, chemical_level)
		):
			state_changed.emit(self)
		return false

	# THREE-BAND OVERLOAD MODEL (Ticket-02):
	#   chemical == 0.0       → overload floods at chemical_zero_accumulation_rate
	#   0.0 < chemical < 0.3  → overload accumulates at overload_accumulation_rate
	#   chemical >= 0.3       → overload decays at overload_decay_rate
	#
	# The > 0.7 High-Focus band (see is_high_focus()) is a *chemical* state: it gates
	# interaction speed, not the overload sign. For the overload meter the 0.3 boundary
	# is the only accumulation/decay switch, so between 0.3 and 0.7 the meter decays
	# steadily — a drifting focus is still calm. The 0.0 cliff is intentionally a harder
	# step: the last milligram of drug being gone flips the meter to maximum inflow.
	if chemical_level <= 0.0:
		sensory_overload = clampf(
			sensory_overload + chemical_zero_accumulation_rate * delta, 0.0, 100.0
		)
	elif chemical_level >= recovery_chemical_threshold:
		sensory_overload = clampf(sensory_overload - overload_decay_rate * delta, 0.0, 100.0)
	else:
		sensory_overload = clampf(sensory_overload + overload_accumulation_rate * delta, 0.0, 100.0)

	# Emit if anything changed. Consumers can diff old vs new if they need to know what
	# crossed, but most just want to know "something changed, re-read the meters".
	var overload_changed := not is_equal_approx(old_overload, sensory_overload)
	var chemical_changed := not is_equal_approx(old_chemical, chemical_level)
	if overload_changed or chemical_changed:
		state_changed.emit(self)

	# Return true if a threshold was crossed this frame (for the state machine to emit
	# specific signals).
	var overload_crossed := (
		old_overload < crash_overload_threshold and sensory_overload >= crash_overload_threshold
	)
	var chemical_crossed := old_chemical > 0.0 and chemical_level <= 0.0
	return overload_crossed or chemical_crossed


## Start (or extend) a relief window: see relief_seconds.
func grant_relief(seconds: float) -> void:
	relief_seconds = maxf(relief_seconds, seconds)


## Apply a change to chemical_level (positive = take drug, negative = metabolise faster).
## Called by Ticket-03 crafting bench or consumable items.
func apply_chemical_change(amount: float) -> void:
	chemical_level = clampf(chemical_level + amount, 0.0, 1.0)
	state_changed.emit(self)


## Direct setters for spawn/teleport (Ticket-05 dreamscape transition). Bypass the
## update loop so the meters can be reset without triggering threshold signals.
func set_grid_position(cell: Vector2i) -> void:
	current_grid_position = cell
	state_changed.emit(self)


func set_facing(direction: Vector2i) -> void:
	facing_direction = direction
	state_changed.emit(self)


## Check if the protagonist is currently in the Crash state. This is a derived value,
## not stored — it's computed from the meters each time it's asked.
func is_crashed() -> bool:
	return sensory_overload >= crash_overload_threshold


## Ticket-02 High-Focus band: chemical > high_focus_threshold AND not currently crashed.
## The !is_crashed() guard matters: if overload has already won, the drug's clarity is
## being drowned out by the nervous system, so "clear vision, fast interactions" must
## not apply even while the chemical is still measurably present.
func is_high_focus() -> bool:
	return chemical_level > high_focus_threshold and not is_crashed()


## Add a one-shot pressure to sensory_overload (no per-second rate semantics —
## callers multiply by delta before passing). This is the input channel for external
## systems that push the meter directly: WorkspaceEntropy's passive feed.
## Emits state_changed only when the value actually moves, so a zero contribution in a
## frame produces no signal spam.
func apply_overload_pressure(amount: float) -> void:
	if is_zero_approx(amount):
		return
	if amount > 0.0 and relief_seconds > 0.0:
		return
	var before := sensory_overload
	sensory_overload = clampf(sensory_overload + amount, 0.0, 100.0)
	if not is_equal_approx(before, sensory_overload):
		state_changed.emit(self)
