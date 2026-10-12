class_name WorkspaceMovementData
extends Resource
## DATA LAYER — the movement tuning table for both ends of the Chemical Cycle.
##
## Sub-resources are built in _init() rather than shipped as .tres files: during
## Ticket-01 every number lives in one readable place, and GDScript files are the only
## artefacts we can syntax-check headlessly on this machine. Once the numbers stabilise
## these should become two .tres assets so designers tune them in the inspector.
##
## Balance intent (MASTER_BRIEF.md #1 "manic creation ... chemical self-soothing"):
##   HIGH_FOCUS is crisp — quick steps, almost no turn lag.
##   CRASH        is ~1.9x slower to step and ~4x slower to turn, which is where the
##                "trapped in owned space" feeling comes from physically.
## The multipliers are authored as absolute values, not as ratios against focus, so a
## later ticket can add a third state (withdrawal, detox) without redefining a baseline.

@export var high_focus: MovementProfileData = MovementProfileData.new()
@export var crash: MovementProfileData = MovementProfileData.new()


func _init() -> void:
	# High-Focus: the drug's spatial mastery. GAME_SPEC.md #1.A.
	high_focus.step_duration_seconds = 0.18
	high_focus.turn_commit_delay_seconds = 0.03
	high_focus.turn_speed_degrees_per_second = 900.0
	high_focus.step_arc_height = 0.07
	high_focus.camera_follow_time = 0.08

	# The Crash: slower movement, heavy chromatic aberration, rising Sensory Overload.
	# Blur/shake magnitude is not here — those are perception intensity, owned by Ticket-02.
	crash.step_duration_seconds = 0.34
	crash.turn_commit_delay_seconds = 0.16
	crash.turn_speed_degrees_per_second = 220.0
	crash.step_arc_height = 0.025
	crash.camera_follow_time = 0.26


## Profile lookup by PerceptionDirector.FocusState. One place maps state -> numbers.
func profile_for(focus_state: int) -> MovementProfileData:
	# FocusState.CRASH == 1 by construction; see PerceptionDirector.
	if focus_state == 1:
		return crash
	return high_focus
