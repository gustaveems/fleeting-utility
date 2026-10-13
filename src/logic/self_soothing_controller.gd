class_name SelfSoothingController
extends Node
## LOGIC — the Compulsive State mechanic (Ticket-08 Task 1).
##
## TRIGGER
## -------
## When sensory_overload >= 80.0 AND chemical_level == 0.0, the protagonist enters a
## compulsive state: normal movement and interactions are locked, the camera focuses on
## the trivial_object, and the player must mash/hold E to soothe.
##
## RESOLUTION
## ----------
## Each E press (is_action_just_pressed) calls trivial_object.soothe(8.0), which lowers
## sensory_overload. While E is held, overload decays at 55.0/s. If no E input for
## 1.5 s, overload spikes at 15.0/s on top of the withdrawal flood.
##
## TUNING: a compulsion only happens at chemical 0, where overload floods at ~40/s
## (+ entropy feed, up to ~5/s). Soothing must beat that or the compulsion is
## inescapable: holding E nets about −10/s (90 → 50 in ~4 s), and mashing is faster.
##
## When overload drops below 50.0, the compulsion ends: movement and interactions unlock,
## the camera returns to the player, and compulsion_ended fires.
##
## TRANSITION SAFETY
## -----------------
## The controller saves the camera's previous target and restores it on exit. If the
## trivial_object is null or the player is already locked (e.g., mid-dreamscape fade),
## the trigger is suppressed to avoid stacking locks.
##
## The compulsion belongs to the apartment, where the fidget object lives. It cannot
## start while the apartment WorldRoot is inactive, and it ends the moment the apartment
## deactivates. Otherwise an unsoothed compulsion (overload still climbing to the
## collapse at 100) followed the player into the dream, kept the interaction lock and
## pointed the camera at an object in a hidden world, so the memory anchors stopped
## responding.

## --- SIGNALS -------------------------------------------------------------------------

signal compulsion_started
signal compulsion_ended

const SOOTHE_PROMPT := "[E] Soothe — tap or hold"

## --- REFERENCES ----------------------------------------------------------------------

@export var state_machine: PlayerStateMachine
@export var player: PlayerMovement
@export var camera: WorkspaceCamera
@export var interaction_controller: InteractionController
@export var trivial_object: TrivialObject
@export var apartment_root: WorldRoot

## --- TUNING --------------------------------------------------------------------------

## Overload threshold to enter compulsion.
@export var compulsion_threshold: float = 80.0

## Overload threshold to exit compulsion.
@export var recovery_threshold: float = 50.0

## Overload reduction per E press.
@export var soothe_per_press: float = 8.0

## Overload decay rate while E is held (per second).
@export var soothe_hold_rate: float = 55.0

## Overload spike rate if no E input for spike_delay seconds.
@export var spike_rate: float = 15.0

## Seconds of no E input before overload starts spiking.
@export var spike_delay: float = 1.5

## Calm granted after soothing a compulsion out: the window to act (walk, medicate).
@export var relief_seconds: float = 12.0

## --- INTERNAL STATE ------------------------------------------------------------------

var _in_compulsion: bool = false
var _time_since_last_soothe: float = 0.0
var _previous_camera_target: Node3D = null


func is_in_compulsion() -> bool:
	return _in_compulsion


func _ready() -> void:
	if apartment_root != null:
		apartment_root.activation_changed.connect(_on_apartment_activation_changed)


func _process(delta: float) -> void:
	if state_machine == null or state_machine.state_data == null:
		return

	var data := state_machine.state_data

	if not _in_compulsion:
		# Check trigger: fully withdrawn AND overwhelmed.
		var apartment_active := apartment_root == null or apartment_root.is_active
		var overwhelmed := data.sensory_overload >= compulsion_threshold
		if apartment_active and overwhelmed and data.chemical_level <= 0.0:
			_enter_compulsion()
	else:
		# In compulsion: handle input and check exit.
		_handle_compulsion_input(delta, data)
		if data.sensory_overload < recovery_threshold:
			# Soothed out: earn a window of calm before withdrawal can bite again.
			data.grant_relief(relief_seconds)
			_exit_compulsion()


func _enter_compulsion() -> void:
	if trivial_object == null or player == null or camera == null:
		push_warning("SelfSoothingController: missing references, cannot enter compulsion.")
		return

	# Guard against stacking locks (e.g., mid-dreamscape fade).
	if player.input_locked:
		return

	_in_compulsion = true
	_time_since_last_soothe = 0.0

	# Lock normal movement and interactions.
	player.lock_input(&"compulsion")
	if interaction_controller != null:
		interaction_controller.lock(&"compulsion")

	# Repoint camera at the trivial object.
	_previous_camera_target = camera.target_node
	camera.set_target(trivial_object)
	if interaction_controller != null:
		interaction_controller.set_target(SOOTHE_PROMPT)

	compulsion_started.emit()


func _on_apartment_activation_changed(active: bool) -> void:
	if not active and _in_compulsion:
		_exit_compulsion()


func _exit_compulsion() -> void:
	_in_compulsion = false

	# Unlock movement and interactions.
	# Release only our own locks: the post-climax interaction lock must survive.
	if player != null:
		player.unlock_input(&"compulsion")
	if interaction_controller != null:
		interaction_controller.unlock(&"compulsion")
		interaction_controller.clear_target(SOOTHE_PROMPT)

	# Restore camera target.
	if camera != null and _previous_camera_target != null:
		camera.set_target(_previous_camera_target)
		_previous_camera_target = null

	compulsion_ended.emit()


func _handle_compulsion_input(delta: float, data: PlayerStateData) -> void:
	if trivial_object == null:
		return

	var soothed_this_frame := false

	# Mash E: each press reduces overload.
	if Input.is_action_just_pressed(InputActionData.ACTION_INTERACT):
		trivial_object.soothe(soothe_per_press)
		soothed_this_frame = true

	# Hold E: continuous decay while held.
	if Input.is_action_pressed(InputActionData.ACTION_INTERACT):
		data.apply_overload_pressure(-soothe_hold_rate * delta)
		soothed_this_frame = true

	# Track time since last soothe.
	if soothed_this_frame:
		_time_since_last_soothe = 0.0
	else:
		_time_since_last_soothe += delta
		# Spike overload if no input for spike_delay.
		if _time_since_last_soothe > spike_delay:
			data.apply_overload_pressure(spike_rate * delta)
