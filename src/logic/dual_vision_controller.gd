class_name DualVisionController
extends Node
## LOGIC/PRESENTATION GLUE — the rapid, jarring flashes between apartment and valley
## during the psychological break (Ticket-09).
##
## start_visions() toggles the visibility (and collision state) of apartment_root and
## valley_root in an erratic, disorienting sequence. Each phase emits valley_phase_active
## so that statue_narrative.gd can trigger its reveal only during valley flashes.
##
## CRITICAL (Rule 2): visibility does NOT remove colliders from the physics space.
## Every toggle explicitly enables/disables every CollisionShape3D in the affected
## subtree, matching the pattern from DreamscapeManager._swap_worlds().

## --- SIGNALS -------------------------------------------------------------------------

## Emitted when a valley flash begins (true) or an apartment flash begins (false).
signal valley_phase_active(is_active: bool)

## Emitted when the 10-second vision sequence ends. The player is left in the apartment.
signal visions_ended

## --- REFERENCES ----------------------------------------------------------------------

@export var apartment_root: Node3D
@export var valley_root: Node3D

## --- TUNING --------------------------------------------------------------------------

## Erratic flash sequence: (show_valley, duration_seconds).
## Total ~10 s. Every entry is a phase: valley visible (apartment hidden), or apartment
## visible (valley hidden).
@export var flash_sequence: Array = []

## --- INTERNAL STATE ------------------------------------------------------------------

var is_valley_phase: bool = false
var _running: bool = false


func _ready() -> void:
	if flash_sequence.is_empty():
		flash_sequence = [
			[false, 0.2],
			[true, 0.8],
			[false, 0.1],
			[true, 1.5],
			[false, 0.3],
			[true, 0.5],
			[false, 0.15],
			[true, 2.0],
			[false, 0.4],
			[true, 0.6],
			[false, 0.25],
			[true, 1.2],
			[false, 0.5],
			[true, 0.9],
		]


func start_visions() -> void:
	if _running:
		return
	_running = true

	for entry in flash_sequence:
		if not _running:
			break
		var show_valley: bool = entry[0]
		var dur: float = entry[1]
		is_valley_phase = show_valley
		_set_root_visible(apartment_root, not show_valley)
		_set_root_visible(valley_root, show_valley)
		valley_phase_active.emit(show_valley)
		await get_tree().create_timer(dur).timeout

	# Leave in the apartment, valley hidden.
	is_valley_phase = false
	_set_root_visible(apartment_root, true)
	_set_root_visible(valley_root, false)
	valley_phase_active.emit(false)

	_running = false
	visions_ended.emit()


## Toggle a root's visibility AND recursively enable/disable every CollisionShape3D in
## its subtree. This is the same confidentiality-tested pattern as DreamscapeManager.
func _set_root_visible(root: Node3D, visible: bool) -> void:
	if root == null:
		return
	root.visible = visible
	_set_subtree_collisions_enabled(root, visible)


func _set_subtree_collisions_enabled(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not enabled
		_set_subtree_collisions_enabled(child, enabled)
