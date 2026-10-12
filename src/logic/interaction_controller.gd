class_name InteractionController
extends Node
## LOGIC — a lock gate for all player interactions (Ticket-06 Task 3).
##
## While any system holds a lock (lock/unlock with a named owner, see LockSet),
## `is_locked` is true and any call to `try_interact()` emits `interaction_locked`
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

## Read-only: take a named lock with lock()/unlock().
var is_locked: bool:
	get:
		return _locks.is_locked()

var _locks := LockSet.new()
var _current_target: String = ""


func lock(lock_owner: StringName) -> void:
	_locks.acquire(lock_owner)


func unlock(lock_owner: StringName) -> void:
	_locks.release(lock_owner)


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
## Pass `only_if` (the prompt you published) so leaving one zone cannot wipe a prompt
## another zone just set. Exit and enter can land in the same physics step, in either
## order.
func clear_target(only_if: String = "") -> void:
	if _current_target.is_empty():
		return
	if not only_if.is_empty() and only_if != _current_target:
		return
	_current_target = ""
	target_lost.emit()
