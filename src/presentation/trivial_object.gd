class_name TrivialObject
extends Area3D
## PRESENTATION/LOGIC — the fidget target for the Compulsive State (Ticket-08 Task 1).
##
## A small, mundane object (a loose thread, a stress ball, a stain) that the protagonist
## compulsively interacts with when fully withdrawn and overwhelmed. The SelfSoothingController
## drives the interaction; this object just provides the `soothe(amount)` method and the
## collision/visual setup.
##
## COLLISION SETUP
## ---------------
## PhysicsLayers.INTERACTABLE, masking PLAYER. The Area3D detects the player's body entering
## and exiting, though the actual interaction is handled by the controller's E-key check.
## The collision shape is a small sphere (radius 0.3 m) so the object is reachable from
## a standing position without requiring precise alignment.
##
## VISUAL
## ------
## Placeholder: a small sphere (radius 0.08 m) with a muted grey material. Real art would
## replace this with a stress ball, a loose thread, or a specific stain — something mundane
## and fidgetable.

## --- SIGNALS -------------------------------------------------------------------------

## Emitted on every soothe (each E press / hold tick). The fidget tap sound keys here.
signal soothed(amount: float)

## --- REFERENCES ----------------------------------------------------------------------

@export var state_machine: PlayerStateMachine

## --- INTERNAL STATE ------------------------------------------------------------------

var _collision_shape: CollisionShape3D
var _mesh: MeshInstance3D


func _ready() -> void:
	PhysicsLayers.make_player_sensor(self)

	# Collision shape: small sphere so the object is reachable from standing.
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	_collision_shape.shape = shape
	add_child(_collision_shape)

	# Visual placeholder: small grey sphere.
	_mesh = MeshInstance3D.new()
	_mesh.name = "MeshInstance3D"
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.52)
	mat.roughness = 0.9
	_mesh.material_override = mat
	add_child(_mesh)


## Called by SelfSoothingController when the player interacts (mash or hold E).
## Lowers sensory_overload by `amount`. Idempotent: if state_machine is null or the
## amount is zero, nothing happens.
func soothe(amount: float) -> void:
	if state_machine == null or state_machine.state_data == null:
		return
	if is_zero_approx(amount):
		return
	# Negative pressure = reduction.
	state_machine.state_data.apply_overload_pressure(-amount)
	soothed.emit(amount)
