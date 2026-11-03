class_name Forest
extends RefCounted
## PRESENTATION — many trees, cheaply (playtest 2026-11-03, third: "the forest needs much
## much more forestation and volume"). Hundreds of tree props as separate scenes cost a
## draw per part per tree; here each model's parts become one MultiMesh per 30 m cell
## (cells so the camera still culls what's behind it).
##
##   Forest.plant(parent, model, placements, dress)   the trees: `placements` are the
##       tree roots' transforms in `parent`'s space; `dress(node)` may re-skin the model
##       once (surface override materials), and every copy wears it
##   Forest.trunks(parent, spots, radius, height)      one body, a cylinder per trunk:
##       you walk around trees, not through them

const CELL := 30.0


## Plant `placements` copies of the model at `model_path`. False if the model is missing.
static func plant(
	parent: Node3D, model_path: String, placements: Array[Transform3D], dress := Callable()
) -> bool:
	if placements.is_empty():
		return true
	if not ResourceLoader.exists(model_path):
		return false
	var model := (load(model_path) as PackedScene).instantiate() as Node3D
	if dress.is_valid():
		dress.call(model)
	var parts: Array = []  # [mesh, transform under the tree's root]
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh.duplicate() as Mesh
		for s in mesh.get_surface_count():
			mesh.surface_set_material(s, mi.get_active_material(s))
		parts.append([mesh, _under_root(mi, model)])
	model.free()
	var cells := {}
	for t in placements:
		var key := Vector2i(floori(t.origin.x / CELL), floori(t.origin.z / CELL))
		if not cells.has(key):
			cells[key] = [] as Array[Transform3D]
		(cells[key] as Array[Transform3D]).append(t)
	for key: Vector2i in cells:
		var here: Array[Transform3D] = cells[key]
		for part in parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = here.size()
			for i in here.size():
				mm.set_instance_transform(i, here[i] * (part[1] as Transform3D))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Trees_%s_%d_%d" % [model_path.get_file().get_basename(), key.x, key.y]
			mmi.multimesh = mm
			parent.add_child(mmi)
	return true


## One static body with a cylinder per trunk (feet at y = 0 in `parent`'s space).
static func trunks(parent: Node3D, spots: Array[Vector3], radius: float, height: float) -> void:
	if spots.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "Trunks"
	body.collision_layer = PhysicsLayers.WORLD
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	for at in spots:
		var shape := CollisionShape3D.new()
		shape.shape = cyl
		shape.position = at + Vector3(0, height * 0.5, 0)
		body.add_child(shape)
	parent.add_child(body)


static func _under_root(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = n
	while at != null and at != root:
		if at is Node3D:
			t = (at as Node3D).transform * t
		at = at.get_parent()
	return t  # the placement stands in for the root's own transform (as CityKit.prop)
