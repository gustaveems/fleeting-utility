class_name EndgameLoopManager
extends Node
## LOGIC/PRESENTATION GLUE — the Scarred Reset & Endgame Loop (Ticket-07 Task 2).
##
## TRIGGER
## -------
## Listens to DreamscapeManager.forced_return_completed (the climax season). Once that
## fires, the endgame loop is underway — this manager owns the beat after the ambulance.
##
## BEAT SEQUENCE
## -------------
##   1. Clinical pause (5.0 s): player is locked in the Ticket-06 clinical state, a
##      "SYSTEM RECALIBRATING..." message displays.
##   2. Scarred reset: meters are partially restored, movement unlocks, the crafting
##      bench and grid are permanently hidden, entropy growth accelerates 50%.
##   3. Atmosphere transitions from clinical to SUBDUED (dim, flat, defeated silence).
##   4. loop_reset signal fires with the narrative flavor text so the HUD can display it.
##
## THE SCARS
## ---------
##   - CraftingBench + SpatialGrid → hidden (bench is gone forever from this cycle).
##   - InteractionController remains LOCKED — no bench, no interaction.
##   - entropy_growth_rate × 1.5 — the room decays faster each cycle.
##   - Starting entropy: unchanged (the room did not clean itself; it only reset the
##     protagonist's chemistry).
##
## SAFETY
## ------
## The bench and grid nodes are suppressed, not freed: references stay valid, and
## interaction with the bench is already gated by interaction_controller.try_interact(),
## which returns false while locked.

## --- SIGNALS -------------------------------------------------------------------------

## Emitted after the scarred reset completes. The flavor text should be displayed on the
## HUD for a few seconds (the HUD decides how long).
signal loop_reset(flavor_text: String)

## Flavor text displayed on the HUD after the reset.
const FLAVOR_TEXT := "The utility is fleeting. The lease renews."

## --- REFERENCES ----------------------------------------------------------------------

@export var dreamscape_manager: DreamscapeManager
@export var state_machine: PlayerStateMachine
@export var player: PlayerMovement
@export var interaction_controller: InteractionController
@export var atmosphere_controller: AtmosphereController
@export var entropy_data: WorkspaceEntropyData

## The apartment world. The scarred reset suppresses the bench and grid inside it.
@export var apartment_root: WorldRoot

## The crafting station. Suppressed (not freed) during the scarred reset.
@export var crafting_bench: CraftingBench

## The worktop grid the bench used. Hidden alongside the bench.
@export var spatial_grid: SpatialGrid

## --- TUNING --------------------------------------------------------------------------

## Seconds the player sits in clinical mode before the loop resets.
@export var clinical_pause_seconds: float = 5.0

## Meters after the scarred reset: half medicated, mild overload — functional but not
## comfortable, and the entropy pressure is higher now.
@export var reset_chemical: float = 0.5
@export var reset_overload: float = 20.0

## Entropy rate multiplier per cycle (1.5 = 50% faster decay).
@export var entropy_rate_multiplier: float = 1.5

## --- INTERNAL STATE ------------------------------------------------------------------

var _timer: Timer
var _message_layer: CanvasLayer
var _message_label: Label
var _loop_armed: bool = false
var _original_entropy_rate: float = 0.0


func _ready() -> void:
	if dreamscape_manager != null:
		dreamscape_manager.forced_return_completed.connect(_on_forced_return)
	if entropy_data != null:
		_original_entropy_rate = entropy_data.entropy_growth_rate


func _on_forced_return() -> void:
	if _loop_armed:
		return
	_loop_armed = true

	_show_message("SYSTEM RECALIBRATING...")
	_timer = Timer.new()
	_timer.name = "EndgameTimer"
	_timer.one_shot = true
	_timer.wait_time = clinical_pause_seconds
	_timer.timeout.connect(_execute_scarred_reset)
	add_child(_timer)
	_timer.start()


func _execute_scarred_reset() -> void:
	# 1. Reset the protagonist's chemistry: they're functional again but the room has
	#    been permanently scarred.
	if state_machine != null and state_machine.state_data != null:
		state_machine.state_data.chemical_level = reset_chemical
		state_machine.state_data.sensory_overload = reset_overload
		state_machine.state_data.state_changed.emit(state_machine.state_data)

	# 2. Unlock movement: the withdrawal jitter ends, normal locomotion resumes.
	if player != null:
		player.is_in_withdrawal = false
		player.input_locked = false

	# 3. Lock interactions permanently — no bench, no crafting.
	if interaction_controller != null:
		interaction_controller.is_locked = true

	# 4. Remove the crafting station: suppressed in the apartment WorldRoot, so it is
	#    hidden AND non-solid (Rule 2) and stays gone through later world swaps. The node
	#    references survive for anything that still holds them.
	if apartment_root != null:
		apartment_root.suppress(crafting_bench)
		apartment_root.suppress(spatial_grid)

	# 5. Accelerate entropy: the room decays faster each cycle.
	if entropy_data != null:
		entropy_data.entropy_growth_rate = _original_entropy_rate * entropy_rate_multiplier

	# 6. Atmosphere: clinical → subdued (dim, flat, defeated silence).
	if atmosphere_controller != null:
		atmosphere_controller.set_subdued_mode(true)

	# 7. Dismiss the recalibration message and broadcast the flavor text.
	_hide_message()
	loop_reset.emit(FLAVOR_TEXT)


## ----- MESSAGE OVERLAY ---------------------------------------------------------------


func _show_message(text: String) -> void:
	if _message_layer != null:
		return

	_message_layer = CanvasLayer.new()
	_message_layer.name = "EndgameMessageLayer"
	_message_layer.layer = 60  # above CoreHud at 50
	add_child(_message_layer)

	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	_message_label.text = text
	_message_label.add_theme_font_size_override("font_size", 28)
	_message_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var container := CenterContainer.new()
	container.name = "MessageContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(_message_label)
	_message_layer.add_child(container)


func _hide_message() -> void:
	if _message_layer != null:
		_message_layer.queue_free()
		_message_layer = null
		_message_label = null
