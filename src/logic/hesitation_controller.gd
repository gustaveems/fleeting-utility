class_name HesitationController
extends Node
## LOGIC — The Hesitation (Ticket-09).
##
## When the player, in the ransacked apartment, approaches the door again, the
## psychological break triggers. The player freezes, the camera shakes, a low rumble
## fills the room, and the DualVisionController begins the rapid, jarring flashes
## between the apartment and the valley.
##
## One-shot per ransacked cycle: resets when RansackedStateManager resets.

## --- SIGNALS -------------------------------------------------------------------------

## Audio placeholder. A future audio system connects to play a low-frequency rumble.
signal hesitation_rumble

## --- REFERENCES ----------------------------------------------------------------------

@export var player: PlayerMovement
@export var apartment_door: ApartmentDoor
@export var dual_vision_controller: DualVisionController
@export var ransacked_state_manager: RansackedStateManager
@export var camera: WorkspaceCamera

## --- TUNING --------------------------------------------------------------------------

## Shake intensity applied to the camera during the hesitation. Restored on visions_ended.
@export var hesitation_shake_intensity: float = 0.15

## --- INTERNAL STATE ------------------------------------------------------------------

var _hesitated_in_this_cycle: bool = false

## Camera shake in effect before the hesitation (e.g. the post-climax tremor), restored
## afterwards rather than zeroed.
var _shake_before: float = 0.0


func _ready() -> void:
	if apartment_door != null:
		apartment_door.body_entered.connect(_on_door_body_entered)


func _on_door_body_entered(body: Node3D) -> void:
	if _hesitated_in_this_cycle:
		return
	if body != player:
		return
	if ransacked_state_manager == null or not ransacked_state_manager.is_ransacked:
		return
	initiate_hesitation()


func initiate_hesitation() -> void:
	_hesitated_in_this_cycle = true

	if player != null:
		player.lock_input(&"hesitation")
	if camera != null:
		_shake_before = camera.withdrawal_shake
		camera.withdrawal_shake = hesitation_shake_intensity

	hesitation_rumble.emit()

	if dual_vision_controller != null:
		dual_vision_controller.visions_ended.connect(_on_visions_ended)
		dual_vision_controller.start_visions()


func _on_visions_ended() -> void:
	if player != null:
		player.unlock_input(&"hesitation")
	if camera != null:
		camera.withdrawal_shake = _shake_before
	if dual_vision_controller != null:
		dual_vision_controller.visions_ended.disconnect(_on_visions_ended)
