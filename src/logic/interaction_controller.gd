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

signal interaction_locked

var is_locked: bool = false


func try_interact() -> bool:
	if is_locked:
		interaction_locked.emit()
		return false
	return true
