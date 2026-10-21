class_name CityKit
extends RefCounted
## PRESENTATION — builds street facades from the Quaternius Downtown City MegaKit (CC0,
## assets/third_party/quaternius_downtown, see docs/references/notes.md).
##
## The kit is modular on a 2 m × 3 m grid: each wall piece is 2 m wide, 3 m tall (one
## floor), its face at local z = 0 facing +Z, its thickness behind it. A CityKit
## collects piece placements and builds ONE MultiMeshInstance3D per piece type, so a
## thousand modules cost a few dozen draw calls.
##
##   var kit := CityKit.new()
##   kit.facade(origin, outward, modules, floors, CityKit.Style.BRICK, seed)
##   kit.build(parent)
##
## `origin` is the facade's bottom-left corner seen from the street; `outward` is the
## direction the facade faces.

enum Style { BRICK, METAL, CONCRETE }

const DIR := "res://assets/third_party/quaternius_downtown/models/"
const MODULE := 2.0
const FLOOR := 3.0

## Per style: ground-floor pieces, upper-floor pieces, the cornice.
const STYLES := {
	Style.BRICK:
	[
		["Brick_Inset", "Brick_Plain_3", "Brick_Inset_Window"],
		[
			"Brick_Window_Square_Single",
			"Brick_Window_Trim_Single",
			"Brick_Plain_3",
			"Brick_Window_Square_Single"
		],
		"Cornice_Brick_Center",
	],
	Style.METAL:
	[
		["Trim_FirstFloor_Window_001", "Trim_FirstFloor_Window_001", "Trim_FirstFloor_Wall"],
		["Metal_FullWindow", "Metal_FullWindow", "Metal_Plain_3"],
		"Cornice_Metal_Center",
	],
	Style.CONCRETE:
	[
		["Trim_FirstFloor_Wall", "Trim_FirstFloor_Wall", "Trim_Window"],
		["Trim_Window", "Trim_Plain_3", "Trim_Window"],
		"Cornice_Trim_Center",
	],
}

static var _meshes: Dictionary = {}

var _batches: Dictionary = {}


## A kit piece as one mesh: every MeshInstance3D in its scene merged (some pieces carry
## separate trim / wear meshes), surfaces and materials kept. Null if missing.
static func mesh(piece: String) -> Mesh:
	if _meshes.has(piece):
		return _meshes[piece]
	var merged: ArrayMesh = null
	var scene := load(DIR + piece + ".gltf") as PackedScene
	if scene == null:
		push_warning("CityKit: missing piece %s" % piece)
	else:
		var root := scene.instantiate()
		merged = ArrayMesh.new()
		_merge(root, Transform3D(), merged)
		root.free()
	_meshes[piece] = merged
	return merged


static func _merge(n: Node, parent_xf: Transform3D, into: ArrayMesh) -> void:
	var xf := parent_xf * ((n as Node3D).transform if n is Node3D else Transform3D())
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] = xf * verts[i]
			arrays[Mesh.ARRAY_VERTEX] = verts
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in normals.size():
					normals[i] = (xf.basis * normals[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = normals
			if arrays[Mesh.ARRAY_TANGENT] != null and xf.basis != Basis():
				arrays[Mesh.ARRAY_TANGENT] = null  # re-derived badly by hand; drop
			into.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat := mi.get_active_material(surface)
			into.surface_set_material(into.get_surface_count() - 1, mat)
	for c in n.get_children():
		_merge(c, xf, into)


## Place one piece.
func add(piece: String, xf: Transform3D) -> void:
	if not _batches.has(piece):
		_batches[piece] = []
	(_batches[piece] as Array).append(xf)


## A whole facade: `modules` wide, `floors` tall, a cornice on top. `skip_ground` lists
## ground-floor module indices left open (a shop window built elsewhere, a door).
func facade(
	origin: Vector3,
	outward: Vector3,
	modules: int,
	floors: int,
	style: Style,
	seed: int,
	skip_ground: Array = []
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var basis := Basis.looking_at(-outward.normalized(), Vector3.UP)
	var along := basis.x
	# Sit 3 cm proud of the massing box behind, or the two faces z-fight in patches.
	origin += outward.normalized() * 0.03
	var spec: Array = STYLES[style]
	for i in modules:
		var x := origin + along * (i * MODULE + MODULE * 0.5)
		for f in floors:
			if f == 0 and skip_ground.has(i):
				continue
			var pool: Array = spec[0] if f == 0 else spec[1]
			var piece: String = pool[rng.randi() % pool.size()]
			add(piece, Transform3D(basis, x + Vector3(0, f * FLOOR, 0)))
		add(spec[2], Transform3D(basis, x + Vector3(0, floors * FLOOR, 0)))


## Build the collected pieces under `parent`, one MultiMeshInstance3D per piece.
func build(parent: Node3D) -> void:
	for piece: String in _batches:
		var m := mesh(piece)
		if m == null:
			continue
		var xfs: Array = _batches[piece]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Kit_" + piece
		mmi.multimesh = mm
		parent.add_child(mmi)
	_batches.clear()
