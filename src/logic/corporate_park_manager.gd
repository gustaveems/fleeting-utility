class_name CorporateParkManager
extends Node
## LOGIC/PRESENTATION GLUE — the Corporate Park "Walk" (Ticket-08 Task 2).
##
## STATE MACHINE
## -------------
##   APARTMENT --(entropy >= 70 + interact door)--> APARTMENT  (the walk)
##                apartment hidden, park shown, free-roam open-space movement
##                APARTMENT --(15 s timer OR E at return door)--> APARTMENT
##
## WORLD SWAP
## ----------
## One WorldEnvironment node, two Environment resources: the manager swaps the node's
## `environment` property. The park subtree is shown; the apartment subtree is hidden
## AND its CollisionShape3D nodes are disabled (Rule 2 — visibility does not touch
## the physics space).
##
## MOVEMENT
## --------
## The project already uses free-roam velocity-based movement (2026-10-11 pivot). The
## park feels distinct because `room_half_extents` widen to 20 m and `move_speed`
## increases to 5.5 — open, faster, less constrained. Original values are restored on
## return.
##
## RETURN
## ------
## A "Return Door" Area3D sits in the park. Walking into it and pressing E triggers
## the return. A 15-second auto-return timer is a fallback.

## --- SIGNALS -------------------------------------------------------------------------

## Emitted when the walk begins (apartment hidden, park shown).
signal walk_started

## Emitted when the walk ends and the apartment is visible again. Task 3
## (Ransacked State) connects here.
signal return_from_walk

## --- REFERENCES ----------------------------------------------------------------------

@export var world_environment: WorldEnvironment
@export var apartment_environment: Environment
@export var apartment_root: Node3D
@export var player: PlayerMovement
@export var state_machine: PlayerStateMachine
@export var interaction_controller: InteractionController

## --- TUNING --------------------------------------------------------------------------

## Time in the park before the auto-return fires.
@export var park_duration: float = 15.0

## Free-roam speed and extents for the park (open space).
@export var park_move_speed: float = 5.5
@export var park_room_extents: Vector2 = Vector2(20.0, 20.0)

## --- INTERNAL STATE ------------------------------------------------------------------

var _park_root: Node3D
var _park_env: Environment
var _return_door: Area3D
var _in_park: bool = false
var _transitioning: bool = false
var _near_return_door: bool = false
var _auto_timer: Timer

var _apartment_move_speed: float = 4.0
var _apartment_extents: Vector2 = Vector2(4.2, 3.2)


func _ready() -> void:
	_build_park()
	_auto_timer = Timer.new()
	_auto_timer.name = "ParkAutoReturn"
	_auto_timer.one_shot = true
	_auto_timer.wait_time = park_duration
	_auto_timer.timeout.connect(_on_auto_return_timeout)
	add_child(_auto_timer)
	if apartment_environment == null and world_environment != null:
		apartment_environment = world_environment.environment


func _process(_delta: float) -> void:
	if not _in_park or _transitioning:
		return
	# E key near the return door triggers return.
	if _near_return_door and Input.is_action_just_pressed(InputActionData.ACTION_INTERACT):
		transition_to_apartment()


## ----- PUBLIC API --------------------------------------------------------------------


## Called by ApartmentDoor when the player interacts with it and entropy >= 70.
func transition_to_park() -> void:
	if _transitioning or _in_park:
		return
	_transitioning = true
	_lock_player(true)

	_apartment_move_speed = player.move_speed
	_apartment_extents = player.room_half_extents
	player.move_speed = park_move_speed
	player.room_half_extents = park_room_extents

	_swap_worlds(true)
	_in_park = true
	_auto_timer.start(park_duration)
	_lock_player(false)
	_transitioning = false
	walk_started.emit()


## Return triggered by the auto-return timer or the return door.
func transition_to_apartment() -> void:
	if _transitioning or not _in_park:
		return
	_transitioning = true
	_lock_player(true)
	_auto_timer.stop()

	_swap_worlds(false)
	_in_park = false

	player.move_speed = _apartment_move_speed
	player.room_half_extents = _apartment_extents

	_lock_player(false)
	_transitioning = false
	return_from_walk.emit()


## ----- INTERNALS ----------------------------------------------------------------------


func _build_park() -> void:
	# Build park subtree programmatically.
	_park_root = Node3D.new()
	_park_root.name = "CorporatePark"
	_park_root.visible = false
	add_child(_park_root)

	# Outdoor environment.
	_park_env = Environment.new()
	_park_env.background_mode = Environment.BG_COLOR
	_park_env.background_color = Color(0.42, 0.55, 0.72)  # soft blue sky
	_park_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_park_env.ambient_light_color = Color(0.65, 0.68, 0.72)
	_park_env.ambient_light_energy = 0.6
	_park_env.fog_enabled = true
	_park_env.fog_light_color = Color(0.50, 0.55, 0.62)
	_park_env.fog_density = 0.001
	_park_env.fog_sky_affect = 0.0

	# Sun.
	var sun := DirectionalLight3D.new()
	sun.name = "ParkSun"
	sun.light_energy = 1.6
	sun.light_color = Color(1.0, 0.95, 0.82)
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55.0, -20.0, 0.0)
	_park_root.add_child(sun)

	# Ground plane.
	var ground := MeshInstance3D.new()
	ground.name = "ParkGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(50.0, 50.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.58, 0.65, 0.52)  # muted corporate lawn
	ground_mat.roughness = 0.9
	ground.material_override = ground_mat
	ground.position = Vector3(0.0, -0.05, 0.0)
	_park_root.add_child(ground)

	# Sterile low-poly trees — cylinder trunks + sphere canopies.
	var tree_positions := [
		Vector3(-5.0, 0.0, -5.0),
		Vector3(6.0, 0.0, -3.0),
		Vector3(-7.0, 0.0, 6.0),
		Vector3(4.0, 0.0, 7.0),
	]
	for i in tree_positions.size():
		_add_tree(tree_positions[i])

	# Return door: a thin box "portal" near the center of the park.
	_return_door = Area3D.new()
	_return_door.name = "ReturnDoor"
	_return_door.position = Vector3(0.0, 0.9, 0.0)
	PhysicsLayers.make_player_sensor(_return_door)
	_return_door.body_entered.connect(_on_return_door_entered)
	_return_door.body_exited.connect(_on_return_door_exited)
	var door_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 2.0, 0.3)
	door_shape.shape = box
	door_shape.name = "CollisionShape3D"
	_return_door.add_child(door_shape)
	# Visual: a thin grey box.
	var door_mesh := MeshInstance3D.new()
	door_mesh.name = "ReturnDoorMesh"
	var door_box := BoxMesh.new()
	door_box.size = Vector3(1.4, 1.9, 0.05)
	door_mesh.mesh = door_box
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.35, 0.35, 0.38)
	door_mesh.material_override = door_mat
	_return_door.add_child(door_mesh)
	_park_root.add_child(_return_door)


func _add_tree(pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = pos

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.12
	cyl.height = 2.0
	trunk.mesh = cyl
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.28, 0.22)
	trunk.material_override = trunk_mat
	trunk.position = Vector3(0.0, 1.0, 0.0)
	tree.add_child(trunk)

	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.4
	canopy.mesh = sphere
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.28, 0.42, 0.22)
	canopy.material_override = canopy_mat
	canopy.position = Vector3(0.0, 2.4, 0.0)
	tree.add_child(canopy)

	_park_root.add_child(tree)


func _swap_worlds(to_park: bool) -> void:
	apartment_root.visible = not to_park
	_park_root.visible = to_park
	# Rule 2: visibility does NOT remove colliders from the physics space.
	_set_subtree_collisions_enabled(apartment_root, not to_park)
	_set_subtree_collisions_enabled(_park_root, to_park)
	if world_environment != null:
		world_environment.environment = _park_env if to_park else apartment_environment


func _set_subtree_collisions_enabled(subtree: Node, enabled: bool) -> void:
	for child in subtree.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not enabled
		_set_subtree_collisions_enabled(child, enabled)


func _on_return_door_entered(body: Node3D) -> void:
	if body == player:
		_near_return_door = true
		if interaction_controller != null:
			interaction_controller.set_target("[E] Return to Apartment")


func _on_return_door_exited(body: Node3D) -> void:
	if body == player:
		_near_return_door = false
		if interaction_controller != null:
			interaction_controller.clear_target()


func _on_auto_return_timeout() -> void:
	transition_to_apartment()


func _lock_player(locked: bool) -> void:
	if player != null:
		player.input_locked = locked
