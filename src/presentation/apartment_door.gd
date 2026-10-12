class_name ApartmentDoor
extends Area3D
## PRESENTATION — the apartment exit door (Ticket-08 Task 2).
##
## An interactable door at the apartment edge. When the player walks up and presses E,
## the door checks the Workspace Entropy "Betrayal Threshold" (>= 70.0). If the room
## has decayed enough, it opens — emitting `initiate_walk` and handing control to the
## CorporateParkManager.
##
## INTERACTION
## -----------
## The door handles its own E-key detection (body_entered/body_exited + _process).
## During compulsion (interaction_controller.is_locked), the door cannot be opened —
## the Self-Soothing Mechanic takes priority.
##
## If entropy < 70, the door remains closed and shows no prompt. The player needs to
## let the room degrade further.

## --- SIGNALS -------------------------------------------------------------------------

signal initiate_walk

## --- REFERENCES ----------------------------------------------------------------------

@export var entropy_data: WorkspaceEntropyData
@export var corporate_park_manager: CorporateParkManager
@export var interaction_controller: InteractionController

## The player's CharacterBody3D, for proximity detection.
@export var player: PlayerMovement

## --- INTERNAL STATE ------------------------------------------------------------------

var _near: bool = false
var _collision_shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 4  # bit 3, interactable
	collision_mask = 2  # bit 2, player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_frame()


func _process(_delta: float) -> void:
	if not _near:
		return
	if not Input.is_action_just_pressed(InputActionData.ACTION_INTERACT):
		return
	# During compulsion, the self-soothing mechanic takes priority.
	if interaction_controller != null and interaction_controller.is_locked:
		return

	var threshold_met := entropy_data != null and entropy_data.entropy >= 70.0
	if not threshold_met:
		return

	initiate_walk.emit()
	if corporate_park_manager != null:
		corporate_park_manager.transition_to_park()


func _on_body_entered(body: Node3D) -> void:
	if body == player:
		_near = true
		if interaction_controller != null:
			var threshold_met := entropy_data != null and entropy_data.entropy >= 70.0
			if threshold_met:
				interaction_controller.set_target("[E] Go Outside")
			else:
				interaction_controller.set_target("")


func _on_body_exited(body: Node3D) -> void:
	if body == player:
		_near = false
		if interaction_controller != null:
			interaction_controller.clear_target()


## ----- VISUAL -------------------------------------------------------------------------


func _build_frame() -> void:
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 2.2, 0.3)
	_collision_shape.shape = box
	add_child(_collision_shape)

	# Simple doorframe: two posts and a lintel.
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.28, 0.25, 0.22)
	frame_mat.roughness = 0.8

	var left_post := _make_box(Vector3(0.08, 2.2, 0.08), frame_mat)
	left_post.position = Vector3(-0.56, 1.1, 0.0)
	add_child(left_post)

	var right_post := _make_box(Vector3(0.08, 2.2, 0.08), frame_mat)
	right_post.position = Vector3(0.56, 1.1, 0.0)
	add_child(right_post)

	var lintel := _make_box(Vector3(1.28, 0.08, 0.08), frame_mat)
	lintel.position = Vector3(0.0, 2.2, 0.0)
	add_child(lintel)


func _make_box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	return mi
