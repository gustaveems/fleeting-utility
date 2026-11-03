class_name ParkDressing
extends RefCounted
## PRESENTATION — the corporate park, dressed (story beat 13: "leased air, licensed
## trees"). A plantation: ONE tree model cloned hundreds of times in perfect rows on a
## flat licensed lawn (same size, same turn), a straight polished path through it along
## the camera's diagonal, the trees beside the path tagged "LICENSED FLORA", benches
## and lamps in step along it, air vents under a "LEASED AIR" sign, glass corporate
## walls all round and the mega tower over it. (Playtest 2026-11-03, third: sixteen
## trees in beds read as an empty plaza; it wants volume.) CC0 / Fab assets; returns
## false (greybox stays) if missing.

const TREE := "res://assets/third_party/quaternius_trees/Tree_1.fbx"
const KIT := "res://assets/third_party/quaternius_downtown/models/"
const MEGA := "res://assets/third_party/fab/mega_tower/cyberpunk_skyscraper_3d_model.glb"
## The park sits between the diorama apartment and full scale: props at half size.
const PROP := 0.5
const HALF := 25.0
const LICENSED_GREEN := Color(0.32, 0.62, 0.22)
## The path runs from the arrival (+X+Z) through the return door (the origin) to the
## far corner: along the iso camera's view, so it reads as a long avenue.
const PATH_DIR := Vector3(-0.70710678, 0, -0.70710678)
const ACROSS := Vector3(0.70710678, 0, -0.70710678)
const PATH_HALF_WIDTH := 1.6
## Rows: a tree every 3 m along, rows 3 m apart, the first 3.2 m off the path's centre.
const ROW_STEP := 3.0
const TREE_SCALE := 1.0
## Inside the walls; and glades kept for what stands in the park (the campaign board,
## the vents), [centre, radius].
const PLANT_REACH := 23.5
const GLADES: Array = [[Vector3(-6, 0, -9), 3.5], [Vector3(-13.2, 0, -21.5), 3.5]]


## Dress `root`: re-skin `ground`, swap the return door's box for a real door, add the
## rest. True if dressed (callers then drop their greybox trees).
static func dress(root: Node3D, ground: MeshInstance3D, door: Node3D, door_box: Node3D) -> bool:
	if not ResourceLoader.exists(TREE):
		return false
	_lawn(ground)
	_path(root)
	_plantation(root)
	for u in [-14.0, -6.0, 8.0, 15.0]:
		for side in [-1.0, 1.0]:
			var at: Vector3 = PATH_DIR * u + ACROSS * side * (PATH_HALF_WIDTH + 0.7)
			var bench := CityKit.prop(
				CityKit.polyhaven("modular_street_seating"), root, at, 45.0 + 90.0 * side, 0.0
			)
			if bench != null:
				bench.scale = Vector3.ONE * PROP
	for k in 11:
		var u := -30.0 + k * 6.0
		var side := 1.0 if k % 2 == 0 else -1.0
		var at: Vector3 = PATH_DIR * u + ACROSS * side * (PATH_HALF_WIDTH + 0.3)
		if absf(at.x) > PLANT_REACH or absf(at.z) > PLANT_REACH:
			continue
		var lamp := CityKit.prop(CityKit.polyhaven("street_lamp_01"), root, at, 0.0, 0.0)
		if lamp != null:
			lamp.scale = Vector3.ONE * PROP
	_air_vents(root)
	_walls(root)
	_real_door(door, door_box)
	return true


## The lawn: one flat, even, licensed green to the walls.
static func _lawn(ground: MeshInstance3D) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.52, 0.22)
	m.roughness = 0.9
	ground.material_override = m


## The path: polished stone between steel curbs, straight through.
static func _path(root: Node3D) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.68, 0.71, 0.75)  # cool, sterile grey
	stone.roughness = 0.22
	stone.metallic = 0.05
	if ResourceLoader.exists(KIT + "T_MarbleFloor_BaseColor.png"):
		stone.albedo_texture = load(KIT + "T_MarbleFloor_BaseColor.png")
		stone.normal_enabled = true
		stone.normal_texture = load(KIT + "T_MarbleFloor_Normal.png")
		stone.uv1_triplanar = true
		stone.uv1_scale = Vector3.ONE * 0.35
	var length := HALF * 2.0 * sqrt(2.0)
	var walk := _box(root, Vector3(0, 0.01, 0), Vector3(PATH_HALF_WIDTH * 2.0, 0.04, length), stone)
	walk.rotation_degrees.y = 45.0
	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.72, 0.72, 0.7)
	curb.roughness = 0.6
	for side in [-1.0, 1.0]:
		var c := _box(
			root,
			ACROSS * side * PATH_HALF_WIDTH + Vector3(0, 0.06, 0),
			Vector3(0.12, 0.12, length),
			curb
		)
		c.rotation_degrees.y = 45.0


## The trees: the same one, in rows, to the walls. Instanced (Forest); the ones beside
## the path wear their licence plates.
static func _plantation(root: Node3D) -> void:
	var placements: Array[Transform3D] = []
	var trunks: Array[Vector3] = []
	var tag_no := 41
	var rows := int(PLANT_REACH * 2.0 / ROW_STEP)
	for i in range(-rows, rows + 1):
		for j in range(1, rows + 1):
			for side in [-1.0, 1.0]:
				var v: float = side * (PATH_HALF_WIDTH + 1.6 + (j - 1) * ROW_STEP)
				var at: Vector3 = PATH_DIR * (i * ROW_STEP) + ACROSS * v
				if absf(at.x) > PLANT_REACH or absf(at.z) > PLANT_REACH or _in_glade(at):
					continue
				placements.append(Transform3D(Basis().scaled(Vector3.ONE * TREE_SCALE), at))
				trunks.append(at)
				if j == 1:
					_plate(root, at, side, tag_no)
					tag_no += 7
	Forest.plant(root, TREE, placements, _recolour)
	Forest.trunks(root, trunks, 0.18 * TREE_SCALE, 2.0)


static func _in_glade(at: Vector3) -> bool:
	for g in GLADES:
		if at.distance_to(g[0]) < g[1]:
			return true
	return false


## The licence: a steel plate on the tree's path side.
static func _plate(root: Node3D, at: Vector3, side: float, tag_no: int) -> void:
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.85, 0.86, 0.88)
	plate.metallic = 0.7
	plate.roughness = 0.25
	var face := at - ACROSS * side * 0.35 + Vector3(0, 0.45, 0)
	var steel := _box(root, face, Vector3(0.5, 0.22, 0.03), plate)
	steel.look_at(steel.position + ACROSS * side, Vector3.UP)
	var tag := Label3D.new()
	SignType.dress(tag)
	tag.text = "LICENSED FLORA\n#%05d" % tag_no
	tag.font_size = 32
	tag.pixel_size = 0.004
	tag.modulate = Color(0.1, 0.12, 0.14)
	root.add_child(tag)
	tag.position = face - ACROSS * side * 0.02
	tag.look_at(tag.position + ACROSS * side, Vector3.UP)


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
	SignType.dress(sign)
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


static func _box(root: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	root.add_child(mi)
	return mi
