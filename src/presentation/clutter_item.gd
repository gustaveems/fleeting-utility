class_name ClutterItem
extends Area3D
## PRESENTATION — a single piece of visual clutter (paper, can, bottle, etc.).
##
## A placeholder for art assets: uses simple Godot Primitive Meshes so the clutter is
## visible in the editor and during play. The VisualClutterManager activates/deactivates
## these by toggling `visible` and `monitoring`.
##
## INTERACTION
## -----------
## This is an Area3D so it can be detected by a RayCast3D (future InteractionController).
## When interacted with, it calls `clean_up()` which emits `cleaned` so the entropy
## system can reduce clutter. For now, the interaction is a stub — Ticket-04 will wire
## the actual entropy reduction.

## Signal emitted when the player interacts with this clutter and cleans it up.
signal cleaned(item: ClutterItem)

## The type of clutter: determines the placeholder mesh shape.
@export var clutter_type: StringName = &"paper"

## Whether this item is currently active (visible and monitorable).
var _is_active: bool = false


func _ready() -> void:
	_ensure_collision_shape()
	_ensure_mesh()
	# Start inactive by default. The VisualClutterManager will activate items as needed.
	visible = false
	monitoring = false


## Auto-create a collision shape if none exists. BoxShape3D sized to the mesh.
func _ensure_collision_shape() -> void:
	var has_shape := false
	for child in get_children():
		if child is CollisionShape3D:
			has_shape = true
			break
	if not has_shape:
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(0.4, 0.1, 0.3)  # flattened box for paper-like clutter
		shape.shape = box
		add_child(shape)


## Auto-create a placeholder mesh based on clutter_type. Uses simple primitives so the
## clutter is visible without art assets.
func _ensure_mesh() -> void:
	var has_mesh := false
	for child in get_children():
		if child is MeshInstance3D:
			has_mesh = true
			break
	if not has_mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "ClutterMesh"
		var mesh: Mesh
		match clutter_type:
			&"paper":
				var box := BoxMesh.new()
				box.size = Vector3(0.35, 0.02, 0.25)  # flattened paper
				mesh = box
			&"can":
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.05
				cyl.bottom_radius = 0.05
				cyl.height = 0.12
				mesh = cyl
			&"bottle":
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.03
				cyl.bottom_radius = 0.04
				cyl.height = 0.18
				mesh = cyl
			_:
				var box := BoxMesh.new()
				box.size = Vector3(0.2, 0.1, 0.2)
				mesh = box
		mesh_instance.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.6, 0.55, 0.5)  # grey-brown placeholder
		material.roughness = 0.8
		mesh_instance.material_override = material
		add_child(mesh_instance)


## Activate this clutter item: make it visible and monitorable. Called by the manager
## when entropy rises and this slot should be filled.
func activate() -> void:
	visible = true
	monitoring = true
	_is_active = true


## Deactivate this clutter item: hide it and disable monitoring. Called by the manager
## when entropy drops and this slot should be cleared.
func deactivate() -> void:
	visible = false
	monitoring = false
	_is_active = false


## Check if this item is currently active.
func is_active() -> bool:
	return _is_active


## Called by the InteractionController (future) when the player cleans this clutter.
## Emits `cleaned` so the entropy system can reduce clutter.
func clean_up() -> void:
	cleaned.emit(self)
