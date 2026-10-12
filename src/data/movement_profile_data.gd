class_name MovementProfileData
extends Resource
## DATA LAYER — one set of movement tunables, valid for one perceptual state.
##
## Two profiles exist (WorkspaceMovementData): HIGH_FOCUS and CRASH. Nothing in the
## logic or presentation layers compares states directly; they ask for "the current
## profile" and read these numbers. That is what lets Ticket-02 (Chemical Focus &
## Perception Meter State Machine) drive movement purely by swapping which profile is
## active, instead of reaching into the mover.
##
## Why the brief's "reduced turn speed" and GAME_SPEC.md #1.A's "slower movement" are
## both modelled here as separate fields: they are felt differently. A long step is
## laborious; a late turn is unresponsive. The Crash state wants both, at different
## multipliers, and playtesting will want to tune them independently.

## Wall-clock time to cross one cell. This is a deliberate, weighted walk — the
## protagonist is never sprinting, even medicated.
@export var step_duration_seconds: float = 0.22

## Dead time between deciding to face a new direction and being allowed to move that
## way. This is the logic-layer half of "reduced turn speed": the avatar commits to a
## new facing late, so input feels like it is dragging behind intent.
@export var turn_commit_delay_seconds: float = 0.06

## Presentation-layer half of turn speed: how fast the body model physically rotates
## towards the committed facing, in degrees per second. Kept separate from the commit
## delay so a crash can look sluggish without the input queue getting stricter, or
## vice versa.
@export var turn_speed_degrees_per_second: float = 720.0

## Vertical arc applied mid-step. Small, but it is what makes a 1m snap read as a
## footstep instead of a teleport.
@export var step_arc_height: float = 0.06

## Position smoothing of the camera rig, in seconds to close ~95% of the gap.
## High focus tracks tightly; the crash lets the room slide under the player.
@export var camera_follow_time: float = 0.10
