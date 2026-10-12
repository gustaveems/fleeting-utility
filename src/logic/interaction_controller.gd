class_name InteractionController
extends Node
## LOGIC — a lock gate for all player interactions (Ticket-06 Task 3).
##
## When `is_locked` is true, any call to `try_interact()` emits `interaction_locked`
## and returns false. The UI can listen to the signal to show a "LOCKED" prompt.
## When false, `try_interact()` returns true and the caller proceeds with the interaction.
##
## This is intentionally minimal — it doesn't do raycasts or find interactables. It's
## just a gate. The actual interaction logic stays in DreamscapeManager (anchor return)
## and CraftingBench (crafting), which now check `interaction_controller.try_interact()`
## before proceeding.
##
## TICKET-07: Target detection signals for the Core HUD. Systems that detect interactable
## targets (DreamscapeManager for statues/anchors, CraftingBench for the bench) call
## set_target() when the player enters range and clear_target() when they leave. The HUD
## listens to target_detected/target_lost to show/hide the interaction prompt.

signal interaction_locked
signal target_detected(prompt_text: String)
signal target_lost

var is_locked: bool = false
var _current_target: String = ""


func try_interact() -> bool:
	if is_locked:
		interaction_locked.emit()
		return false
	return true


## Called by proximity-detection systems when the player enters an interactable zone.
## The prompt text is shown on the HUD (e.g., "[E] Craft", "[E] Return").
func set_target(prompt: String) -> void:
	if _current_target == prompt:
		return
	_current_target = prompt
	target_detected.emit(prompt)


## Called by proximity-detection systems when the player leaves an interactable zone.
func clear_target() -> void:
	if _current_target.is_empty():
		return
	_current_target = ""
	target_lost.emit()
