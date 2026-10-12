class_name StatueNarrative
extends Area3D
## PRESENTATION — the statues' true meaning (Ticket-09).
##
## Attached to each monolithic statue in the valley. During a valley-phase flash in the
## psychological break, if the player's camera is looking at this statue, the narrative
## reveal fires: "Not sacrifices. Monuments. We stood for something greater."
##
## One-shot per vision cycle: the lock resets when visions_ended fires, so the reveal
## can be triggered again in a subsequent hesitation sequence but only once per sequence.

## --- SIGNALS -------------------------------------------------------------------------

signal statue_truth_revealed(text: String)

## --- CONSTANTS -----------------------------------------------------------------------

const NARRATIVE_TEXT := "Not sacrifices. Monuments. We stood for something greater."

## --- REFERENCES ----------------------------------------------------------------------

@export var dual_vision_controller: DualVisionController
@export var camera: Camera3D

## --- TUNING --------------------------------------------------------------------------

## Dot-product threshold for "looking at". 0.6 = ~53° cone in front of the camera.
@export var look_threshold: float = 0.6

## --- INTERNAL STATE ------------------------------------------------------------------

var _triggered_this_cycle: bool = false


func _ready() -> void:
	if dual_vision_controller != null:
		dual_vision_controller.visions_ended.connect(_on_visions_ended)


func _process(_delta: float) -> void:
	if _triggered_this_cycle:
		return
	if dual_vision_controller == null:
		return
	if not dual_vision_controller.is_valley_phase:
		return
	if camera == null:
		return
	if _is_looking_at_me():
		_triggered_this_cycle = true
		statue_truth_revealed.emit(NARRATIVE_TEXT)
		print(NARRATIVE_TEXT)


func _is_looking_at_me() -> bool:
	var forward := -camera.global_transform.basis.z
	var to_me := (global_position - camera.global_position).normalized()
	return forward.dot(to_me) > look_threshold


func _on_visions_ended() -> void:
	_triggered_this_cycle = false
