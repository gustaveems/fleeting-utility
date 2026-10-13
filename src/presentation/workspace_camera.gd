class_name WorkspaceCamera
extends Camera3D
## PRESENTATION LAYER — fixed-angle isometric workspace camera (Task 3 spec).
##
## Extends Camera3D directly (per spec). This is a *replacement* for IsoCameraRig,
## which was a Node3D wrapper with a child Camera3D. The flat hierarchy means this
## script owns both the transform and the camera properties — simpler for inspector
## authoring, but less separable if a later ticket wants to add a second camera mode.
##
## PERSPECTIVE, NOT ORTHOGRAPHIC
## -----------------------------
## Task 3 specifies Perspective projection locked to an isometric-looking rotation.
## Orthographic would give pixel-perfect 1 m cells; Perspective gives depth cues that
## help the player judge how far objects are. The tradeoff is that cell sizes on
## screen vary slightly across the frame, which matters for grid-precise placement
## (Ticket-03 crafting bench). If that becomes a problem, set `is_orthographic = true`.
##
## ROTATION
## --------
## X = -30°, Y = 45° is a classic "3/4 iso" look — steeper than true isometric
## (35.264°) but gentler than top-down. The result reads as a room you're looking into
## from an elevated corner, which suits the claustrophobic apartment. The rotation is
## locked: no player control, no mouse-look, no orbit. The camera's identity is that it
## never moves, only follows.
##
## CRASH FOV BREATHING
## -------------------
## When `sensory_overload` is high, the FOV oscillates slowly (±2°, ~0.25 Hz). This is
## meant to feel like the room is breathing — the world compresses and expands around
## the player, inducing claustrophobia without shaking the camera (which would be
## nauseating at this elevation). The amplitude and speed are exported so they can be
## tuned or disabled.

## --- SIGNALS -------------------------------------------------------------------------
## (none required by spec; camera is a leaf consumer)

## --- PROJECTION ----------------------------------------------------------------------

## Set true to switch from Perspective to Orthographic. Orthographic is better for
## grid-precise work (Ticket-03); Perspective gives depth cues for room navigation.
@export var is_orthographic: bool = false

## Vertical field of view in Perspective mode. 45° at this elevation gives a room that
## fills most of the frame without excessive barrel distortion at the corners.
@export var perspective_fov: float = 45.0

## Vertical world span in Orthographic mode (metres visible top-to-bottom).
@export var orthographic_size: float = 9.0

## --- FOLLOW LOGIC --------------------------------------------------------------------

## The node the camera tracks. If assigned in the inspector or via `set_target()`, the
## camera lerps toward this node's world position every frame. If null, the camera holds
## its authored position (useful for cutscenes or Ticket-06 ambulance sequence).
@export var target_node: Node3D

## Smoothing factor for the follow lerp (0 = no smoothing, 1 = instant). 0.10 gives a
## gentle trailing feel; increase to 0.20 for snappier tracking during Crash.
@export var follow_smoothing: float = 0.10

## Vertical offset so the camera looks at the player's chest, not their feet.
@export var framing_lift: float = 0.85

## Eye-to-target standoff in world axes. With rotation locked at (-30°, 45°) the
## forward axis is (-0.612, -0.5, -0.612), so the resting position is the target plus
## this offset. Follow logic lerps toward (player + lift + offset) — lerping toward the
## player WITHOUT the offset would drive the camera inside the body capsule.
@export var camera_offset: Vector3 = Vector3(8.6, 7.0, 8.6)

## Ticket-06: post-climax withdrawal shake. A small constant random offset applied to
## the follow target, so the camera jitters slightly even when the player is still.
@export var withdrawal_shake: float = 0.0

## --- DREAM FRAMING (Ticket-11) -------------------------------------------------------
## The fixed iso angle points the top of the frame 7.5° BELOW the horizon, so the
## valley's 15 m monoliths could never fit at any distance. In the dream the view opens
## up: shallower pitch, wider lens, a little further back. The statues stand whole on
## the horizon. Applied at the world swap, under the white fade.

@export var room_pitch_degrees: float = -30.0
@export var dream_pitch_degrees: float = -12.0
@export var dream_fov: float = 55.0
@export var dream_offset_scale: float = 1.4

## --- CRASH STATE REACTION ------------------------------------------------------------

## If assigned, the camera reads `sensory_overload` from this node's `state_data`.
## If null, crash FOV breathing is disabled and the camera stays at `perspective_fov`.
@export var state_machine: PlayerStateMachine

## FOV oscillation amplitude at full crash (degrees). ±2° is subtle but perceptible.
@export var crash_fov_amplitude: float = 2.0

## FOV oscillation frequency at full crash (Hz). 0.25 Hz ≈ one full breath every 4 s.
@export var crash_fov_frequency: float = 0.25

## `sensory_overload` threshold above which FOV breathing activates. Matches the Crash
## state threshold in PlayerStateData (50.0).
@export var crash_fov_threshold: float = 50.0

## --- INTERNAL STATE ------------------------------------------------------------------

var is_dream_framing: bool = false

var _base_fov: float
var _breath_phase: float = 0.0
var _room_offset: Vector3

## ----- LIFECYCLE ---------------------------------------------------------------------


func _ready() -> void:
	# Lock the rotation to the isometric angle. This is the camera's identity: it never
	# changes, only follows.
	rotation_degrees = Vector3(room_pitch_degrees, 45.0, 0.0)
	_room_offset = camera_offset

	# Configure projection.
	if is_orthographic:
		projection = Camera3D.PROJECTION_ORTHOGONAL
		size = orthographic_size
	else:
		projection = Camera3D.PROJECTION_PERSPECTIVE
		fov = perspective_fov
		_base_fov = perspective_fov

	# Ortho doesn't benefit from FOV breathing; disable it.
	if is_orthographic:
		crash_fov_amplitude = 0.0

	near = 0.05
	# 45 m, not 100: the room is ~12 m across, and every extra metre of far plane is
	# more path for volumetric fog to wash the frame out.
	far = 45.0
	make_current()


## ----- FOLLOW LOGIC ------------------------------------------------------------------


func _process(delta: float) -> void:
	_follow_target(delta)
	_update_crash_fov(delta)


func _follow_target(delta: float) -> void:
	if target_node == null:
		return

	# Exponential smoothing: frame-rate independent, converges to target.
	# `follow_smoothing` is the fraction of the gap closed per frame; convert to a
	# delta-aware weight so a 30 fps and 144 fps player get the same feel.
	var target_pos := target_node.global_position + Vector3(0.0, framing_lift, 0.0) + camera_offset
	# Withdrawal shake: small random offset so the camera jitters even when still.
	if withdrawal_shake > 0.0:
		target_pos += (
			Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * withdrawal_shake
		)
	var weight := 1.0 - exp(-delta / maxf(follow_smoothing, 0.001))
	global_position = global_position.lerp(target_pos, weight)


## ----- CRASH FOV BREATHING -----------------------------------------------------------


func _update_crash_fov(delta: float) -> void:
	if is_orthographic or crash_fov_amplitude <= 0.0 or state_machine == null:
		return

	var overload := _get_sensory_overload()
	if overload < crash_fov_threshold:
		# Decay the breath back to base FOV smoothly.
		fov = lerpf(fov, _base_fov, 1.0 - exp(-delta * 3.0))
		_breath_phase = 0.0
		return

	# Normalize the overload above threshold to 0..1 for amplitude scaling.
	var intensity := clampf((overload - crash_fov_threshold) / 50.0, 0.0, 1.0)
	var amplitude := crash_fov_amplitude * intensity

	_breath_phase += delta * crash_fov_frequency * TAU
	var breath := sin(_breath_phase) * amplitude
	fov = _base_fov + breath


func _get_sensory_overload() -> float:
	if state_machine == null or state_machine.state_data == null:
		return 0.0
	return state_machine.state_data.sensory_overload


## ----- PUBLIC API --------------------------------------------------------------------


## Open the view for the valley (true) or return to the room's fixed iso angle (false).
## Instant: callers switch it while the screen is white.
func set_dream_framing(enabled: bool) -> void:
	is_dream_framing = enabled
	var pitch := dream_pitch_degrees if enabled else room_pitch_degrees
	rotation_degrees = Vector3(pitch, 45.0, 0.0)
	camera_offset = _room_offset * (dream_offset_scale if enabled else 1.0)
	if not is_orthographic:
		_base_fov = dream_fov if enabled else perspective_fov
		fov = _base_fov
	if target_node != null:
		global_position = (
			target_node.global_position + Vector3(0.0, framing_lift, 0.0) + camera_offset
		)


## Assign the follow target at runtime (bootstrap uses this instead of the inspector).
func set_target(node: Node3D) -> void:
	target_node = node
