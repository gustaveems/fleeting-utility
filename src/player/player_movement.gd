class_name PlayerMovement
extends CharacterBody3D
## FREE-ROAM movement controller.
##
## DESIGN PIVOT (2026-10-11): the original constraint was grid-snapped 1 m stepping,
## and the game was built and run that way. Alain played it and rejected the feel —
## "it should be a free roam". This is velocity-based planar movement on CharacterBody3D
## via move_and_slide(); the grid survives only as authored data (clutter spawn points,
## the crafting bench's 4x4 worktop, edge-proximity math), not as a locomotion cage.
##
## SCREEN-RELATIVE INPUT
## ---------------------
## The iso camera sits on the +X/+Z diagonal at 45° yaw, so raw world-axis input would
## make W travel down-left of where it points on screen. Input is therefore mapped
## through the camera's own horizontal basis:
##   screen right = (+X, -Z)/√2     screen down = (+X, +Z)/√2
## W = up-screen = world (-X,-Z); D = down-right = (+X,-Z); S/A mirror. Diagonals come
## free from key combinations — that is the whole point of the pivot.
##
## CRASH INTEGRATION
## -----------------
## With free roam, "slower movement" and "reduced turn speed" map onto driving
## dynamics instead of tween durations:
##   top speed   3.2 → 1.4 m/s   (the walk drags)
##   acceleration 14 → 4.5       (the body answers late — the felt sluggishness)
##   turn rate   720° → 180°/s   (the body visibly arrives after the direction change)
## Threshold is state_data.is_crashed() (sensory_overload >= 50), same as everything else.
##
## CONTAINMENT
## -----------
## Real colliders now do the job the grid-refusal used to: WorkspaceBlockout walls are
## StaticBody3D (the camera-facing pair keeps an invisible collision extension upward —
## the player never sees that face, standard iso practice), and a position clamp catches
## any residual tunneling. The soft-boundary vignette/fog still expresses the edge; the
## walls just make it physical.

## --- SIGNALS ---------------------------------------------------------------------

## Emitted when the body transitions stopped -> moving. Camera/VFX listeners.
signal movement_started

## Emitted when the body transitions moving -> stopped. ScreenEffects' crash jolt.
signal movement_completed

## Camera-basis vectors for screen-relative input (yaw 45° iso, unit length).
const _SCREEN_RIGHT := Vector3(0.70710678, 0.0, -0.70710678)
const _SCREEN_DOWN := Vector3(0.70710678, 0.0, 0.70710678)

## Start/stop thresholds for the movement signals, m/s. Deliberate hysteresis band:
## a single threshold would chatter started/completed every frame at the exact speed.
const _START_SPEED := 0.25
const _STOP_SPEED := 0.08

## --- MOVEMENT --------------------------------------------------------------------

## Top speed in metres/second, medicated.
@export var move_speed: float = 4.0

## Top speed in Crash state.
@export var crash_move_speed: float = 1.4

## Exponential approach rate to the desired velocity, 1/s. High-Focus is snappy.
@export var acceleration: float = 17.0

## Crash acceleration. Low value = the body answers input late, which is the felt
## sluggishness — this, not top speed alone, is what makes moving while crashed awful.
@export var crash_acceleration: float = 4.5

## Safety clamp half-extents (metres, XZ). Wall colliders do the real containment;
## this only catches tunneling at high speed / shallow angles.
@export var room_half_extents: Vector2 = Vector2(4.2, 3.2)

## --- ROTATION --------------------------------------------------------------------

## Body-model turn rate towards the heading, degrees/second.
@export var turn_speed_degrees: float = 720.0

## Crash turn rate — the body swings around noticeably after the direction of travel.
@export var crash_turn_speed_degrees: float = 180.0

## --- DEPENDENCIES ----------------------------------------------------------------

## If assigned, crash parameters engage while sensory_overload >= 50. Null = always
## normal handling.
@export var state_machine: PlayerStateMachine

## True while any system holds an input lock (lock_input/unlock_input). Input is
## ignored but the body still decelerates to a stop, so the player never teleports
## mid-fade. Read-only: writers must use a named lock so they cannot release each
## other's (see LockSet).
var input_locked: bool:
	get:
		return _input_locks.is_locked()

## Ticket-06: post-climax withdrawal state. When true, movement becomes fast, jittery,
## and uncontrollable — the protagonist is lucid but panicked.
var is_in_withdrawal: bool = false

## --- INTERNAL STATE --------------------------------------------------------------

var _input_locks := LockSet.new()
var _is_moving: bool = false
var _heading_yaw: float = 0.0
var _body_pivot: Node3D
var _collision_shape: CollisionShape3D
var _mesh: MeshInstance3D

## ----- LIFECYCLE -----------------------------------------------------------------


func _ready() -> void:
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD
	global_position = Vector3.ZERO
	_heading_yaw = 0.0  # default-facing NORTH (up-right on screen)

	_setup_placeholder_body()


func lock_input(lock_owner: StringName) -> void:
	_input_locks.acquire(lock_owner)


func unlock_input(lock_owner: StringName) -> void:
	_input_locks.release(lock_owner)


## Build the placeholder capsule + collision + facing wedge. Nothing is authored in a
## scene, so there is nothing to look up (no find_child by name, Ironclad Rule 3).
func _setup_placeholder_body() -> void:
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	add_child(_collision_shape)
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.28
	capsule_shape.height = 0.80
	_collision_shape.shape = capsule_shape
	_collision_shape.position = Vector3(0.0, 0.50, 0.0)

	_body_pivot = Node3D.new()
	_body_pivot.name = "BodyPivot"
	add_child(_body_pivot)

	_mesh = MeshInstance3D.new()
	_mesh.name = "MeshCapsule"
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.26
	capsule_mesh.height = 0.74
	_mesh.mesh = capsule_mesh
	_mesh.position = Vector3(0.0, 0.48, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.76, 0.66)
	material.roughness = 0.75
	_mesh.material_override = material
	_body_pivot.add_child(_mesh)

	var wedge := MeshInstance3D.new()
	wedge.name = "FacingWedge"
	var wedge_mesh := BoxMesh.new()
	wedge_mesh.size = Vector3(0.12, 0.10, 0.22)
	wedge.mesh = wedge_mesh
	# PrimitiveMesh has no `position` in Godot 4 (Godot 3 API): the -0.22 z
	# protrusion has to live on the MeshInstance3D transform, not the mesh.
	wedge.position = Vector3(0.0, 0.72, -0.22)
	var wedge_mat := StandardMaterial3D.new()
	wedge_mat.albedo_color = Color(0.85, 0.30, 0.24)
	wedge_mat.roughness = 0.75
	wedge.material_override = wedge_mat
	_body_pivot.add_child(wedge)


## ----- MOVEMENT ------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	# Locked input still decelerates: desired velocity is zero, so the exponential
	# approach glides the body to a stop instead of freezing it mid-stride.
	var input_dir := Vector3.ZERO if input_locked else _poll_input_world()

	var speed := _current_speed()
	var accel := _current_acceleration()

	# Withdrawal: fast, jittery, uncontrollable. The spec asked for "0.05s tween" but
	# the movement is velocity-based (free-roam pivot), so the intent is high speed +
	# low control + lateral noise.
	if is_in_withdrawal:
		speed = 5.5
		accel = 2.0
		# Panicked lateral drift — the body moves even without input.
		var noise := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.25
		input_dir += noise

	# Exponential velocity approach: frame-rate independent, and the accel constant is
	# the crash knob — low accel reads as the body refusing to answer, not just a
	# slower walk.
	var desired := input_dir * speed
	var weight := 1.0 - exp(-accel * delta)
	velocity.x = lerpf(velocity.x, desired.x, weight)
	velocity.z = lerpf(velocity.z, desired.z, weight)
	velocity.y = 0.0  # planar movement; no gravity/floor physics needed

	move_and_slide()
	_clamp_to_room()
	_update_heading(input_dir, delta)
	_update_moving_signals()


## Screen-relative input: W is "up on screen", not "world -Z".
func _poll_input_world() -> Vector3:
	var ix := 0.0
	var iy := 0.0
	if Input.is_action_pressed("move_east"):
		ix += 1.0
	if Input.is_action_pressed("move_west"):
		ix -= 1.0
	if Input.is_action_pressed("move_south"):
		iy += 1.0
	if Input.is_action_pressed("move_north"):
		iy -= 1.0
	if is_zero_approx(ix) and is_zero_approx(iy):
		return Vector3.ZERO
	var dir := _SCREEN_RIGHT * ix + _SCREEN_DOWN * iy
	return dir.normalized()


func _clamp_to_room() -> void:
	var p := global_position
	p.x = clampf(p.x, -room_half_extents.x, room_half_extents.x)
	p.z = clampf(p.z, -room_half_extents.y, room_half_extents.y)
	global_position = p


## Body rotation follows the heading with a capped turn rate. In crash the cap is low,
## so the model visibly swings around *after* the direction of travel has changed —
## "reduced turn speed" in driving terms.
func _update_heading(input_dir: Vector3, delta: float) -> void:
	if _body_pivot == null:
		return
	if input_dir != Vector3.ZERO:
		# Yaw that points the model's -Z forward axis along the movement direction.
		var target_yaw := atan2(-input_dir.x, -input_dir.z)
		var max_step := (
			deg_to_rad(crash_turn_speed_degrees if _crashed() else turn_speed_degrees) * delta
		)
		var diff := wrapf(target_yaw - _heading_yaw, -PI, PI)
		_heading_yaw += clampf(diff, -max_step, max_step)
	_body_pivot.rotation.y = _heading_yaw


## Stopped<->moving transitions drive the signals (with a hysteresis band so they
## cannot chatter at the threshold speed).
func _update_moving_signals() -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if not _is_moving:
		if speed > _START_SPEED:
			_is_moving = true
			movement_started.emit()
	else:
		if speed < _STOP_SPEED:
			_is_moving = false
			movement_completed.emit()


## ----- CRASH STATE ---------------------------------------------------------------


func _current_speed() -> float:
	return crash_move_speed if _crashed() else move_speed


func _current_acceleration() -> float:
	return crash_acceleration if _crashed() else acceleration


func _crashed() -> bool:
	if state_machine == null or state_machine.state_data == null:
		return false
	return state_machine.state_data.is_crashed()


## ----- PUBLIC API ----------------------------------------------------------------


## Read-only movement state (dev HUD / probes).
func is_moving() -> bool:
	return _is_moving
