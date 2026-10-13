class_name InputActionData
extends RefCounted
## DATA LAYER — the whole key map, registered at runtime.
##
## Declared in code instead of project.godot's [input] section so the whole key map
## lives in one auditable file and a bare checkout runs without hand-edited
## InputEvent structures.
## Cost: rebinding from the editor Settings dialog is not available yet. Revisit when
## an options menu exists.
##
## SCREEN MAPPING (why W is not "up")
## ----------------------------------
## The camera sits on the +X/+Z side looking back at the origin at 45 degrees yaw, so
## the four grid axes land on the four screen diagonals. W/A/S/D are bound to the grid
## axis that carries the key's screen direction:
##
##   W / Up    -> NORTH (-Z) -> up-right      S / Down -> SOUTH (+Z) -> down-left
##   A / Left  -> WEST  (-X) -> up-left       D / Right-> EAST  (+X) -> down-right
##
## Movement is free-roam (2026-10-11 pivot): PlayerMovement maps these through the
## camera basis, and key combinations give the diagonals.

const ACTION_MOVE_NORTH := "move_north"
const ACTION_MOVE_EAST := "move_east"
const ACTION_MOVE_SOUTH := "move_south"
const ACTION_MOVE_WEST := "move_west"

## Dev rig for the unified workspace scene (WorkspaceBootstrap): inject the two meters
## on demand so the crash/clutter/atmosphere chain can be watched without waiting on
## passive decay.
const ACTION_DEV_DUMP_OVERLOAD := "dev_dump_overload"
const ACTION_DEV_DUMP_ENTROPY := "dev_dump_entropy"
const ACTION_DEV_RESET_ENTROPY := "dev_reset_entropy"

## Ticket-05: interact (statue return in the dreamscape) and a dev shortcut that forces
## the dreamscape transition without waiting out the chemical/overload collapse.
const ACTION_INTERACT := "interact"
const ACTION_DEV_DREAMSCAPE := "dev_dreamscape"

## Ticket-12: delete the save so the next launch starts fresh.
const ACTION_DEV_WIPE_SAVE := "dev_wipe_save"


## physical_keycode so the binding follows the key's position on the keyboard, not the
## layout — W/A/S/D stay W/A/S/D on AZERTY.
static func _bindings() -> Dictionary:
	return {
		ACTION_MOVE_NORTH: [KEY_W, KEY_UP],
		ACTION_MOVE_EAST: [KEY_D, KEY_RIGHT],
		ACTION_MOVE_SOUTH: [KEY_S, KEY_DOWN],
		ACTION_MOVE_WEST: [KEY_A, KEY_LEFT],
		ACTION_DEV_DUMP_OVERLOAD: [KEY_TAB],
		ACTION_DEV_DUMP_ENTROPY: [KEY_T],
		ACTION_DEV_RESET_ENTROPY: [KEY_R],
		ACTION_INTERACT: [KEY_E],
		ACTION_DEV_DREAMSCAPE: [KEY_N],
		ACTION_DEV_WIPE_SAVE: [KEY_F9],
	}


## Idempotent: safe to call from any _ready(), including a scene reloaded in-editor.
static func register() -> void:
	var bindings := _bindings()
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var keys: Array = bindings[action]
		for keycode in keys:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			event.pressed = false
			InputMap.action_add_event(action, event)


## action -> WorkspaceGridData.Facing, so PlayerController holds no if-chain about keys.
static func facing_actions() -> Dictionary:
	return {
		ACTION_MOVE_NORTH: 0,  # Facing.NORTH
		ACTION_MOVE_EAST: 1,  # Facing.EAST
		ACTION_MOVE_SOUTH: 2,  # Facing.SOUTH
		ACTION_MOVE_WEST: 3,  # Facing.WEST
	}


## Pressed facing this frame. Returns -1 when nothing is held.
## Reads as "held", not "just_pressed", because walking must continue while the key is
## down; GridMover's one-step-at-a-time rule turns that into a chain of 1m commits.
## If several directions are held, the last one in facing_actions() order wins rather
## than flickering between them — deterministic, and it means a rolling finger across the
## keys does not stutter the step.
static func polled_facing() -> int:
	var result := -1
	var actions := facing_actions()
	for action in actions:
		if Input.is_action_pressed(action):
			# Explicit int() keeps this a typed assignment; Dictionary lookups come back
			# as Variant and strict typing should not be satisfied with an unsafe assign.
			result = int(actions[action])
	return result
