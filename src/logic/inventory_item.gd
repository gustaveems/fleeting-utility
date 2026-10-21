class_name InventoryItem
extends Area3D
## DATA/PRESENTATION — a placeable item on a SpatialGrid.
##
## Holds an item_id (for crafting recipes, UI labels, etc.) and its grid_position (the
## cell it occupies on the SpatialGrid). The Area3D body makes it detectable by a
## RayCast3D (future InteractionController Ticket-02).
##
## INTERACTION
## -----------
## This node is added to the "interactable" group so a RayCast3D can detect it. The
## future InteractionController will raycast, check if the collider is in the
## "interactable" group, and call interact() on it. The interact() method emits the
## `interacted` signal so UI/crafting systems can react.
##
## COLLISION SHAPE
## ---------------
## If no CollisionShape3D child exists at _ready, one is auto-created with a BoxShape3D
## (0.8×0.8×0.8m). This makes the item "just work" when instantiated from a PackedScene
## without manual scene-tree authoring. If you author the scene in the editor with a
## custom collision shape, the auto-creation is skipped.

## Signal emitted when the player interacts with this item (called by InteractionController).
signal interacted(item: InventoryItem)

## Unique identifier for this item type (e.g., "raw_compound", "pill_bottle").
## Used by crafting recipes and UI labels.
@export var item_id: StringName = &""

## The cell this item occupies on the SpatialGrid. Set by SpatialGrid.place_item() or
## manually if placing without the grid.
@export var grid_position: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_ensure_collision_shape()
	_ensure_mesh()
	add_to_group("interactable")


## Create a default collision shape if none exists. The box is slightly smaller than a
## full cell (0.8m vs 1.0m) so items don't visually overlap at cell boundaries.
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
		box.size = Vector3(0.8, 0.8, 0.8)
		shape.shape = box
		add_child(shape)


## The item's look: a real model per id if installed, else a colour-coded placeholder cube
## sized to sit inside its cell.
func _ensure_mesh() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			return

	# Real models (Poly Haven, CC0) when installed: the raw compound is a chemical tub,
	# the finished dose a corporate medical pack. Scaled to sit inside a cell.
	var model_path := _model_for_id()
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		var model := (load(model_path) as PackedScene).instantiate() as Node3D
		model.name = "ItemModel"
		model.scale = Vector3.ONE * _model_scale_for_id()
		model.position = Vector3(0.0, 0.03, 0.0)
		add_child(model)
		return

	var instance := MeshInstance3D.new()
	instance.name = "ItemMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.45, 0.45)
	instance.mesh = box
	instance.position = Vector3(0.0, 0.25, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = _color_for_id()
	material.roughness = 0.7
	instance.material_override = material
	add_child(instance)


func _model_for_id() -> String:
	match item_id:
		&"raw_compound":
			return "res://assets/third_party/polyhaven/plastic_container/plastic_container.gltf"
		&"pill_bottle":
			return "res://assets/third_party/polyhaven/medical_box/medical_box.gltf"
	return ""


func _model_scale_for_id() -> float:
	return 0.5 if item_id == &"raw_compound" else 0.85


func _color_for_id() -> Color:
	match item_id:
		&"raw_compound":
			return Color(0.45, 0.60, 0.35)  # greenish sludge block
		&"pill_bottle":
			return Color(0.85, 0.65, 0.25)  # amber bottle block
		_:
			return Color(0.62, 0.60, 0.58)  # unmarked


## Called by the InteractionController when the player interacts with this item.
## Emits the `interacted` signal so UI/crafting systems can react (open inventory,
## start crafting, etc.).
func interact() -> void:
	interacted.emit(self)
