class_name ApartmentDoor
extends Interactable
## PRESENTATION — the apartment exit door (Ticket-08 Task 2).
##
## An interactable door at the apartment edge. When the player walks up and presses E,
## the door checks the Workspace Entropy "Betrayal Threshold" (>= 70.0). If the room
## has decayed enough, it opens — emitting `initiate_walk` and handing control to the
## CorporateParkManager.
##
## INTERACTION (Interactable)
## --------------------------
## While interactions are locked (e.g. a compulsion), the door cannot be opened.
## Below the threshold, or once this cycle's walk is spent, it shows no prompt: after
## the betrayal, walking up to it is the hesitation (HesitationController listens to
## body_entered), not another outing.

## --- SIGNALS -------------------------------------------------------------------------

signal initiate_walk

## --- CONSTANTS -----------------------------------------------------------------------

const BETRAYAL_THRESHOLD := 70.0

## --- REFERENCES ----------------------------------------------------------------------

@export var entropy_data: WorkspaceEntropyData
@export var corporate_park_manager: CorporateParkManager
## Act I, 7c: the metro across the city, any day (once a day), and the menu to choose.
@export var metro_ride: MetroRide
## Ticket-24: on an invitation night the door goes up to the crowd's rooftop.
@export var standing: Standing
@export var runner: DialogueRunner

## --- INTERNAL STATE ------------------------------------------------------------------

var _collision_shape: CollisionShape3D


func _ready() -> void:
	prompt_text = "[E] Go Outside"
	super()
	_build_frame()


func can_interact() -> bool:
	if _betrayed():
		return false
	return _park_open() or _metro_open() or _event_open()


## The room has decayed past the threshold: the door now leads to the park walk.
func opens_to_park() -> bool:
	return _park_open()


## Below the threshold the door is the metro; at it, the park (or the metro).
func current_prompt() -> String:
	if not can_interact():
		return blocked_prompt()
	if _park_open():
		return prompt_text
	return StandingScript.DOOR_PROMPT if _event_open() else ActOneScript.DOOR_METRO_PROMPT


func blocked_prompt() -> String:
	# After the betrayal, standing here is the hesitation: no words.
	if _betrayed():
		return ""
	if metro_ride != null:
		return ActOneScript.DOOR_OUT_TODAY
	return "Not yet. The room isn't unbearable enough."


func _on_interacted() -> void:
	var options: Array[String] = []
	var actions: Array[String] = []
	if _park_open():
		options.append(ActOneScript.DOOR_PARK)
		actions.append("park")
	if _event_open():
		options.append(str(StandingScript.EVENTS[standing.invitation()][2]))
		actions.append("event")
	if _metro_open():
		options.append(ActOneScript.DOOR_METRO)
		actions.append("metro")
	if runner == null or options.size() == 1 and actions[0] == "park":
		_go(actions[0])  # the story's walk, as before: no menu
		return
	options.append(ActOneScript.DOOR_STAY)
	actions.append("stay")
	var picked := await runner.ask(options)
	_go(actions[picked])


func _go(action: String) -> void:
	match action:
		"park":
			initiate_walk.emit()
			if corporate_park_manager != null:
				corporate_park_manager.transition_to_park()
		"metro":
			metro_ride.start_ride()
		"event":
			standing.go_out()


func _betrayed() -> bool:
	return corporate_park_manager != null and corporate_park_manager.walk_taken


func _park_open() -> bool:
	return entropy_data != null and entropy_data.entropy >= BETRAYAL_THRESHOLD and not _betrayed()


func _event_open() -> bool:
	return standing != null and standing.invitation() >= 0


func _metro_open() -> bool:
	return metro_ride != null and metro_ride.available()


## ----- VISUAL -------------------------------------------------------------------------


func _build_frame() -> void:
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	# Deep sensor (1.4 m) reaching into the room: the door sits ON the north wall plane,
	# and the movement clamp stops the capsule ~0.35 m short of it, so a thin 0.3 m box
	# was unreachable in practice.
	box.size = Vector3(1.2, 2.2, 1.4)
	_collision_shape.shape = box
	_collision_shape.position = Vector3(0.0, 1.1, 0.7)
	add_child(_collision_shape)

	# The real door (Downtown kit, CC0): a worn wooden frame and a plain door, facing
	# into the room. The box posts below are the fallback.
	var kit := "res://assets/third_party/quaternius_downtown/models/"
	if CityKit.prop(kit + "DoorFrame_Wooden.gltf", self, Vector3.ZERO, 0.0, 0.0) != null:
		CityKit.prop(kit + "Door_1.gltf", self, Vector3(0.5, 0.0, 0.0), 0.0, 0.0)
		return
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
