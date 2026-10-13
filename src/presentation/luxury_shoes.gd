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
## MASTER_BRIEF: "Looking out the window, he spots his friend wearing high-status luxury
## shoes." The friend stands OUTSIDE, past the north (window) wall, visible over its
## low sill. The one-shot look zone sits INSIDE the room at the window:
## "[E] Look out the window" realizes the betrayal, then the zone goes quiet.
## (The first version put the shoes on the apartment floor with no window involved;
## the playtester went straight for the window, 2026-10-14.)

## --- SIGNALS -------------------------------------------------------------------------

signal betrayal_realized

## --- CONSTANTS -----------------------------------------------------------------------

const NARRATIVE_TEXT := "High-status luxury. He sold me out."

## --- REFERENCES ----------------------------------------------------------------------

## The player's CharacterBody3D, for proximity detection.
@export var player: PlayerMovement
@export var interaction_controller: InteractionController

## Where the look zone sits relative to the friend: back inside the room, against the
## inner face of the window wall.
@export var look_zone_offset: Vector3 = Vector3(0.0, 0.0, 2.6)

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
	# The friend: a dark, still figure. Placeholder until character art exists.
	var friend := MeshInstance3D.new()
	friend.name = "Friend"
	var body := CapsuleMesh.new()
	body.radius = 0.28
	body.height = 1.75
	friend.mesh = body
	friend.position = Vector3(0.0, 0.875 + 0.1, 0.0)
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color(0.06, 0.06, 0.07)
	coat.roughness = 0.8
	friend.material_override = coat
	add_child(friend)

	# The shoes: bright, glossy, unmistakably expensive against the grey.
	var shoe_mat := StandardMaterial3D.new()
	shoe_mat.albedo_color = Color(0.95, 0.90, 0.78)
	shoe_mat.roughness = 0.15
	shoe_mat.metallic = 0.3
	shoe_mat.emission_enabled = true
	shoe_mat.emission = Color(0.9, 0.75, 0.4)
	shoe_mat.emission_energy_multiplier = 0.35

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
	box.size = Vector3(0.14, 0.09, 0.30)
	mi.mesh = box
	mi.material_override = mat
	return mi


## ----- PROXIMITY ----------------------------------------------------------------------


func _build_proximity() -> void:
	_proximity_area = Interactable.new()
	_proximity_area.name = "ProximityArea"
	_proximity_area.player = player
	_proximity_area.interaction_controller = interaction_controller
	_proximity_area.prompt_text = "[E] Look out the window"
	# The zone stands inside the room at the window, not out here with the friend.
	_proximity_area.position = look_zone_offset
	_proximity_area.one_shot = true
	_proximity_area.interacted.connect(_on_realized)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.0, 1.4)
	shape.shape = box
	shape.position = Vector3(0.0, 1.0, 0.0)
	_proximity_area.add_child(shape)
	add_child(_proximity_area)
