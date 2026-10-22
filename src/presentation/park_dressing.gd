class_name ParkDressing
extends RefCounted
## PRESENTATION — the corporate park, dressed (story beat 13: "leased air, licensed
## trees"). A sterile plaza: polished stone paving, lawn only inside curbed beds, ONE
## tree model cloned in a perfect grid, each tagged "LICENSED FLORA", benches and lamps
## in rows, air vents under a "LEASED AIR" sign, glass corporate walls all round and
## the mega tower over it. CC0 / Fab assets; returns false (greybox stays) if missing.

const TREE := "res://assets/third_party/quaternius_trees/Tree_1.fbx"
const KIT := "res://assets/third_party/quaternius_downtown/models/"
const MEGA := "res://assets/third_party/fab/mega_tower/cyberpunk_skyscraper_3d_model.glb"
## The park sits between the diorama apartment and full scale: props at half size.
const PROP := 0.5
const HALF := 25.0
const TREE_X: Array[float] = [-15.0, -7.5, 7.5, 15.0]
const TREE_Z: Array[float] = [-12.0, -4.0, 4.0, 12.0]
const LICENSED_GREEN := Color(0.32, 0.62, 0.22)


## Dress `root`: re-skin `ground`, swap the return door's box for a real door, add the
## rest. True if dressed (callers then drop their greybox trees).
static func dress(root: Node3D, ground: MeshInstance3D, door: Node3D, door_box: Node3D) -> bool:
	if not ResourceLoader.exists(TREE):
		return false
	_paving(ground)
	var tag_no := 41
	for x in TREE_X:
		for z in TREE_Z:
			_bed(root, Vector3(x, 0, z))
			_licensed_tree(root, Vector3(x, 0, z), tag_no)
			tag_no += 7
	for x in [-11.0, 11.0]:
		for z in [-8.0, 0.0, 8.0]:
			var bench := CityKit.prop(
				CityKit.polyhaven("modular_street_seating"), root, Vector3(x, 0, z), 90.0, 0.0
			)
			if bench != null:
				bench.scale = Vector3.ONE * PROP
	for k in 9:
		var t := -20.0 + k * 5.0
		for at in [Vector3(t, 0, -19), Vector3(t, 0, 19)]:
			var lamp := CityKit.prop(CityKit.polyhaven("street_lamp_01"), root, at, 0.0, 0.0)
			if lamp != null:
				lamp.scale = Vector3.ONE * PROP
	for x in [-2.0, -1.0, 1.0, 2.0]:
		var planter := CityKit.prop(
			CityKit.polyhaven("planter_box_01"), root, Vector3(x, 0, 1.6), 0.0, 0.0
		)
		if planter != null:
			planter.scale = Vector3.ONE * 0.8
	_air_vents(root)
	_walls(root)
	_real_door(door, door_box)
	return true


static func _paving(ground: MeshInstance3D) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.68, 0.71, 0.75)  # cool, sterile grey
	m.roughness = 0.22
	m.metallic = 0.05
	if ResourceLoader.exists(KIT + "T_MarbleFloor_BaseColor.png"):
		m.albedo_texture = load(KIT + "T_MarbleFloor_BaseColor.png")
		m.normal_enabled = true
		m.normal_texture = load(KIT + "T_MarbleFloor_Normal.png")
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.35
	ground.material_override = m


## A lawn bed: a perfect green square in a concrete curb.
static func _bed(root: Node3D, at: Vector3) -> void:
	var lawn := StandardMaterial3D.new()
	lawn.albedo_color = Color(0.3, 0.55, 0.22)
	lawn.roughness = 0.9
	_box(root, at + Vector3(0, 0.04, 0), Vector3(4.6, 0.08, 4.6), lawn)
	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.72, 0.72, 0.7)
	curb.roughness = 0.6
	for side in [-1.0, 1.0]:
		_box(root, at + Vector3(side * 2.4, 0.1, 0), Vector3(0.2, 0.2, 5.0), curb)
		_box(root, at + Vector3(0, 0.1, side * 2.4), Vector3(5.0, 0.2, 0.2), curb)


## The same tree, again: identical, unnaturally even green, and tagged.
static func _licensed_tree(root: Node3D, at: Vector3, tag_no: int) -> void:
	var tree := CityKit.prop(TREE, root, at, 0.0, 0.0)  # same rotation too: cloned
	if tree == null:
		return
	tree.scale = Vector3.ONE * 0.6
	_recolour(tree)
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.85, 0.86, 0.88)
	plate.metallic = 0.7
	plate.roughness = 0.25
	_box(root, at + Vector3(0, 0.45, 1.0), Vector3(0.5, 0.22, 0.03), plate)
	var tag := Label3D.new()
	tag.text = "LICENSED FLORA\n#%05d" % tag_no
	tag.font_size = 32
	tag.pixel_size = 0.004
	tag.modulate = Color(0.1, 0.12, 0.14)
	tag.position = at + Vector3(0, 0.45, 1.02)
	root.add_child(tag)


## Leaves a flat licensed green; bark a clean grey-brown (the FBX lost its textures).
static func _recolour(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as StandardMaterial3D
			if mat == null:
				continue
			var m := mat.duplicate() as StandardMaterial3D
			var leaves := "eaves" in mat.resource_name
			m.albedo_color = LICENSED_GREEN if leaves else Color(0.36, 0.31, 0.27)
			m.roughness = 0.7
			mi.set_surface_override_material(s, m)
	for c in n.get_children():
		_recolour(c)


## Leased air: vents and ducting under a corporate sign.
static func _air_vents(root: Node3D) -> void:
	for x in [-14.0, -12.5]:
		var box := CityKit.prop(
			CityKit.polyhaven("utility_box_02"), root, Vector3(x, 0, -21.5), 0.0, 0.0
		)
		if box != null:
			box.scale = Vector3.ONE * 0.8
	var pipes := CityKit.prop(
		CityKit.polyhaven("modular_industrial_pipes_01"), root, Vector3(-13.2, 1.0, -22.3), 0.0, 0.0
	)
	if pipes != null:
		pipes.scale = Vector3.ONE * 0.8
	var sign := Label3D.new()
	sign.text = "AIR QUALITY: LEASED\nBreathe responsibly."
	sign.font_size = 64
	sign.pixel_size = 0.01
	sign.modulate = Color(0.2, 0.84, 0.9)
	sign.outline_size = 8
	sign.position = Vector3(-13.2, 2.6, -21.8)
	root.add_child(sign)


## Glass corporate walls on three sides; the mega tower over the north wall.
static func _walls(root: Node3D) -> void:
	var walls := Node3D.new()
	walls.name = "CorporateWalls"
	walls.scale = Vector3.ONE * PROP
	root.add_child(walls)
	var kit := CityKit.new()
	var span := int(HALF * 2.0 / PROP / CityKit.MODULE)
	var reach := HALF / PROP
	kit.facade(Vector3(-reach, 0, -reach), Vector3.BACK, span, 26, CityKit.Style.METAL, 91)
	kit.facade(Vector3(reach, 0, -reach), Vector3.LEFT, span, 22, CityKit.Style.METAL, 92)
	kit.facade(Vector3(-reach, 0, reach), Vector3.RIGHT, span, 24, CityKit.Style.METAL, 93)
	kit.build(walls)
	var tower := CityKit.prop(MEGA, root, Vector3(10, 120, -70), 15.0, 0.0)
	if tower != null:
		tower.scale = Vector3.ONE * 240.0


## The return door: a glass-and-metal corporate door in place of the grey box.
static func _real_door(door: Node3D, door_box: Node3D) -> void:
	var frame := CityKit.prop(
		KIT + "DoorFrame_Metal_Single.gltf", door, Vector3(0, -0.9, 0), 0.0, 0.0
	)
	if frame == null:
		return
	frame.scale = Vector3.ONE * 0.65
	var leaf := CityKit.prop(KIT + "Door_2.gltf", door, Vector3(0.325, -0.9, 0), 0.0, 0.0)
	if leaf != null:
		leaf.scale = Vector3.ONE * 0.65
	door_box.visible = false


static func _box(root: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	root.add_child(mi)
