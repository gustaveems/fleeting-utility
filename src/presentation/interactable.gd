class_name Interactable
extends Area3D
## PRESENTATION — a walk-up, press-E interaction zone.
##
## One implementation of the pattern the door, the luxury shoes and the park's return
## door each used to hand-roll: a player-only sensor (PhysicsLayers), a HUD prompt via
## InteractionController.set_target/clear_target while the player stands inside, and an
## E press gated by the interaction lock.
##
## EXTENDING
## ---------
## Subclass (or instance and connect `interacted`) and override as needed:
##   can_interact() -> bool   is the interaction available right now? (no prompt if not)
##   _on_interacted()         what pressing E does
## A subclass overriding _ready must call super().
##
## Inside an inactive WorldRoot the zone is paused and its shape disabled, so it can
## neither sense nor prompt (Rule 2).

## Emitted when the player presses E and every gate passes. Audio/UI hook.
signal interacted

## The player body. Null accepts any PlayerMovement.
@export var player: PlayerMovement
@export var interaction_controller: InteractionController
@export var prompt_text: String = "[E] Interact"

## True: works once, then goes quiet (no prompt, no further presses).
@export var one_shot: bool = false

var is_player_near: bool = false

var _used: bool = false

## The prompt this zone last pushed to the HUD; only this one may be cleared by it.
var _published_prompt: String = ""


func _ready() -> void:
	PhysicsLayers.make_player_sensor(self)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not is_player_near:
		return
	# Availability can change while standing here (a craft finishing, entropy rising).
	# set_target de-duplicates, so this is cheap.
	refresh_prompt()
	if Input.is_action_just_pressed(InputActionData.ACTION_INTERACT):
		try_interact()


## Run the interaction if every gate passes. Public so scripted sequences and tests
## can trigger it without synthesizing input. Returns true if it ran.
func try_interact() -> bool:
	if one_shot and _used:
		return false
	if not can_interact():
		return false
	if interaction_controller != null and not interaction_controller.try_interact():
		return false
	if one_shot:
		_used = true
	interacted.emit()
	_on_interacted()
	refresh_prompt()
	return true


## Spend a one-shot without running it (restoring a save).
func mark_used() -> void:
	_used = true
	refresh_prompt()


## Override: is the interaction available right now? (No E press when false; the
## blocked_prompt() explains instead.)
func can_interact() -> bool:
	return true


## Override: the effect of pressing E.
func _on_interacted() -> void:
	pass


## The prompt to show, or "" for none.
func current_prompt() -> String:
	if one_shot and _used:
		return ""
	return prompt_text if can_interact() else blocked_prompt()


## Override: what to show while standing here when E would do nothing ("" = nothing).
## Silence reads as "broken" (playtest 2026-10-14), so say why when there is a reason.
func blocked_prompt() -> String:
	return ""


## Re-publish the prompt (call when can_interact() may have changed while near).
func refresh_prompt() -> void:
	if not is_player_near or interaction_controller == null:
		return
	var prompt := current_prompt()
	if prompt.is_empty():
		_withdraw_prompt()
	else:
		interaction_controller.set_target(prompt)
		_published_prompt = prompt


func _is_player(body: Node3D) -> bool:
	return body == player if player != null else body is PlayerMovement


func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	is_player_near = true
	refresh_prompt()


func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	is_player_near = false
	_withdraw_prompt()


func _withdraw_prompt() -> void:
	if interaction_controller != null and not _published_prompt.is_empty():
		interaction_controller.clear_target(_published_prompt)
	_published_prompt = ""
