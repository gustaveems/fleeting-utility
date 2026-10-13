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
## A one-shot Interactable child: walking up shows "[E] Look", pressing E realizes the
## betrayal, then the zone goes quiet.

## --- SIGNALS -------------------------------------------------------------------------

signal betrayal_realized

## --- CONSTANTS -----------------------------------------------------------------------

const NARRATIVE_TEXT := "High-status luxury. He sold me out."

## --- REFERENCES ----------------------------------------------------------------------

## The player's CharacterBody3D, for proximity detection.
@export var player: PlayerMovement
@export var interaction_controller: InteractionController

## --- INTERNAL STATE ------------------------------------------------------------------

var _realized: bool = false
var _proximity_area: Interactable


func _ready() -> void:
	_build_shoes()
	_build_proximity()


func is_realized() -> bool:
	return _realized


## Restore without replaying the beat (no signal, no line on screen).
func mark_realized() -> void:
	_realized = true
	if _proximity_area != null:
		_proximity_area.mark_used()


func _on_realized() -> void:
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
	_proximity_area = Interactable.new()
	_proximity_area.name = "ProximityArea"
	_proximity_area.player = player
	_proximity_area.interaction_controller = interaction_controller
	_proximity_area.prompt_text = "[E] Look"
	_proximity_area.one_shot = true
	_proximity_area.interacted.connect(_on_realized)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	_proximity_area.add_child(shape)
	add_child(_proximity_area)
