class_name LuxuryShoes
extends StaticBody3D
## PRESENTATION — the betrayal narrative prop (Ticket-08 Task 3).
##
## A pair of high-status luxury shoes left near the window after the apartment was
## ransacked. When the player walks up and presses E, the shoes emit `betrayal_realized`
## and print the narrative text: "High-status luxury. He sold me out."
##
## VISUAL
## ------
## Placeholder: two small dark boxes side by side, suggesting a pair of expensive shoes.
## Real art would replace this with a detailed shoe model.
##
## INTERACTION
## -----------
## An Area3D child detects player proximity. When the player is near and presses E,
## the betrayal is realized. The interaction is one-shot: after the first E press,
## further presses do nothing.

## --- SIGNALS -------------------------------------------------------------------------

signal betrayal_realized

## --- CONSTANTS -----------------------------------------------------------------------

const NARRATIVE_TEXT := "High-status luxury. He sold me out."

## --- REFERENCES ----------------------------------------------------------------------

## The player's CharacterBody3D, for proximity detection.
@export var player: Node3D

## --- INTERNAL STATE ------------------------------------------------------------------

var _near: bool = false
var _realized: bool = false
var _proximity_area: Area3D


func _ready() -> void:
	_build_shoes()
	_build_proximity()


func _process(_delta: float) -> void:
	if not _near or _realized:
		return
	if Input.is_action_just_pressed(InputActionData.ACTION_INTERACT):
		_realized = true
		betrayal_realized.emit()
		print(NARRATIVE_TEXT)


## ----- VISUAL -------------------------------------------------------------------------


func _build_shoes() -> void:
	var shoe_mat := StandardMaterial3D.new()
	shoe_mat.albedo_color = Color(0.12, 0.10, 0.08)
	shoe_mat.roughness = 0.4
	shoe_mat.metallic = 0.1

	# Left shoe.
	var left := _make_shoe_box(shoe_mat)
	left.position = Vector3(-0.08, 0.04, 0.0)
	left.rotation_degrees = Vector3(0.0, -8.0, 0.0)
	add_child(left)

	# Right shoe.
	var right := _make_shoe_box(shoe_mat)
	right.position = Vector3(0.08, 0.04, 0.0)
	right.rotation_degrees = Vector3(0.0, 5.0, 0.0)
	add_child(right)


func _make_shoe_box(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.10, 0.06, 0.22)
	mi.mesh = box
	mi.material_override = mat
	return mi


## ----- PROXIMITY ----------------------------------------------------------------------


func _build_proximity() -> void:
	_proximity_area = Area3D.new()
	_proximity_area.name = "ProximityArea"
	_proximity_area.collision_layer = 4  # interactable
	_proximity_area.collision_mask = 2  # player
	_proximity_area.body_entered.connect(_on_body_entered)
	_proximity_area.body_exited.connect(_on_body_exited)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	_proximity_area.add_child(shape)
	add_child(_proximity_area)


func _on_body_entered(body: Node3D) -> void:
	if body == player:
		_near = true


func _on_body_exited(body: Node3D) -> void:
	if body == player:
		_near = false
