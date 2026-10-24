extends Node3D
## Asset showcase: one labelled row per third-party pack, lit like a street at golden hour,
## to check the placed assets and their import settings by eye.
##
## Open scenes/asset_showcase.tscn and press F6. Fly: hold right mouse to look, WASD to move,
## Q/E down/up, Shift for speed, 1-8 jump to a row, 0 overview.
## On load it prints "[SHOWCASE] loaded N/M" and every missing file.

const TP := "res://assets/third_party/"
const ROW_GAP := 14.0
const ITEM_GAP := 1.5
const MAX_ITEM_WIDTH := 30.0
const KIT_SETS: Array[String] = [
	"Concrete", "RedBrick", "Dirt", "MarbleFloor", "MetalConcrete", "RoofSlate", "Trim", "Ornaments"
]
## The Downtown pieces the game's CityKit, doors and park use.
const KIT_PIECES: Array[String] = [
	"Brick_Inset",
	"Brick_Plain_3",
	"Brick_Inset_Window",
	"Brick_Window_Square_Single",
	"Brick_Window_Trim_Single",
	"Cornice_Brick_Center",
	"Trim_FirstFloor_Window_001",
	"Trim_FirstFloor_Wall",
	"Metal_FullWindow",
	"Metal_Plain_3",
	"Cornice_Metal_Center",
	"Trim_Window",
	"Trim_Plain_3",
	"Cornice_Trim_Center",
	"DoorFrame_Wooden",
	"Door_1",
	"DoorFrame_Metal_Single",
	"Door_2",
]
const TREES: Array[String] = [
	"Birch_1",
	"Birch_3",
	"Birch_5",
	"Birch_7",
	"DeadBirch_1",
	"DeadBirch_4",
	"Tree_1",
	"Tree_4",
	"Pine_1",
	"Pine_3",
	"DeadTree_2",
]
const PEOPLE: Array[String] = ["UAL1_Standard.glb", "UAL2_Standard.glb", "Mannequin_F.glb"]
const KENNEY_COUNT := 24
const SCIFI_COUNT := 16
const FLY_SPEED := 8.0
const LOOK_SENSITIVITY := 0.003

var loaded := 0
var missing: Array[String] = []
## Camera framing per row: [position, look target]. Index 0 is the overview.
var views: Array = []
## Per row: [title, z, length, tallest], for close-up tours.
var rows_info: Array = []

var _camera: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _looking := false


func _ready() -> void:
	_build_environment()
	var rows: Array = [
		["Downtown materials (colour + normal + ORM)", _materials()],
		["Downtown City MegaKit: pieces the game uses", _scenes(_kit_paths())],
		["Poly Haven (32 models, 1k)", _scenes(_dir_paths("polyhaven", "", true))],
		["Quaternius cars", _scenes(_dir_paths("quaternius_cars", ".fbx"))],
		["Quaternius trees", _scenes(_tree_paths())],
		["Universal Animation Library: street people", _people()],
		[
			"Kenney Retro Urban Kit (sample)",
			_scenes(_dir_paths("kenney_retro_urban", ".glb").slice(0, KENNEY_COUNT))
		],
		[
			"Quaternius Sci-Fi Essentials (sample)",
			_scenes(_dir_paths("quaternius_scifi", ".gltf").slice(0, SCIFI_COUNT))
		],
	]
	var widest := 0.0
	for i in rows.size():
		widest = maxf(widest, _lay_row(rows[i][0], rows[i][1], -i * ROW_GAP))
	_build_ground(widest, rows.size())
	views.push_front(
		[
			Vector3(widest * 0.5, 40.0, 30.0),
			Vector3(widest * 0.5, 0.0, -rows.size() * ROW_GAP * 0.5)
		]
	)
	_build_camera()
	frame(0)
	var total := loaded + missing.size()
	print("[SHOWCASE] loaded %d/%d" % [loaded, total])
	for m in missing:
		print("[SHOWCASE] missing: %s" % m)


## Point the camera at view i (0 overview, 1.. rows).
func frame(i: int) -> void:
	if i < 0 or i >= views.size():
		return
	_camera.position = views[i][0]
	_camera.look_at(views[i][1])
	_yaw = _camera.rotation.y
	_pitch = _camera.rotation.x


## Point the camera from pos at target.
func frame_at(pos: Vector3, target: Vector3) -> void:
	_camera.position = pos
	_camera.look_at(target)
	_yaw = _camera.rotation.y
	_pitch = _camera.rotation.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_looking = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _looking:
		_yaw -= event.relative.x * LOOK_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY, -1.5, 1.5)
		_camera.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.keycode - KEY_0
		if n >= 0 and n <= 9:
			frame(n)


func _process(delta: float) -> void:
	if _camera == null:
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= _camera.global_basis.z
	if Input.is_key_pressed(KEY_S):
		dir += _camera.global_basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= _camera.global_basis.x
	if Input.is_key_pressed(KEY_D):
		dir += _camera.global_basis.x
	if Input.is_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		dir -= Vector3.UP
	var speed := FLY_SPEED * (4.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	_camera.position += dir.normalized() * speed * delta


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#5f7478")
	sky_mat.sky_horizon_color = Color("#c9b49a")
	sky_mat.ground_horizon_color = Color("#8a7a68")
	sky_mat.ground_bottom_color = Color("#2e3b3f")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_density = 0.002
	env.fog_light_color = Color("#c9b49a")
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -35.0, 0.0)
	sun.light_color = Color("#ffe2b8")
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)


func _build_ground(width: float, rows: int) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width + 40.0, rows * ROW_GAP + 30.0)
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.position = Vector3(width * 0.5, 0.0, -(rows - 1) * ROW_GAP * 0.5)
	var m := _kit_material("Concrete")
	if m != null:
		m.uv1_scale = Vector3(mesh.size.x / 4.0, mesh.size.y / 4.0, 1.0)
		ground.material_override = m
	add_child(ground)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.far = 800.0
	add_child(_camera)
	_camera.make_current()


## Lays items left to right along +X at depth z; returns the row's length.
func _lay_row(title: String, items: Array, z: float) -> float:
	var label := _label(title, 64)
	label.position = Vector3(-2.0, 4.0, z)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(label)
	var x := 0.0
	var tallest := 2.0
	for it in items:
		var node: Node3D = it[1]
		var box := _aabb(node, Transform3D())
		var w := clampf(box.size.x, 0.4, MAX_ITEM_WIDTH)
		node.position = Vector3(x - box.position.x, -box.position.y, z - box.get_center().z)
		add_child(node)
		var name_tag := _label(it[0], 28)
		name_tag.position = Vector3(x + w * 0.5, box.size.y + 0.5, z + box.size.z * 0.5 + 0.2)
		add_child(name_tag)
		tallest = maxf(tallest, box.size.y)
		x += w + ITEM_GAP
	rows_info.append([title, z, x, tallest])
	var dist := clampf(maxf(x * 0.35, tallest * 2.2), 8.0, 90.0)
	views.append(
		[
			Vector3(x * 0.5, tallest * 0.6 + dist * 0.35, z + dist),
			Vector3(x * 0.5, tallest * 0.4, z)
		]
	)
	return x


func _scenes(paths: Array) -> Array:
	var out: Array = []
	for p in paths:
		var inst := _instance(p)
		if inst != null:
			out.append([p.get_file().get_basename(), inst])
	return out


func _instance(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		missing.append(path)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		missing.append(path + " (not a scene)")
		return null
	var n := scene.instantiate() as Node3D
	if n == null:
		missing.append(path + " (no 3D root)")
		return null
	loaded += 1
	return n


func _people() -> Array:
	var out: Array = []
	for f in PEOPLE:
		var inst := _instance(TP + "quaternius_anim/" + f)
		if inst == null:
			continue
		var player := _find_player(inst)
		if player != null:
			var names := player.get_animation_list()
			var pick := ""
			for a in names:
				if "walk" in String(a).to_lower():
					pick = a
					break
			if pick == "" and names.size() > 0:
				pick = names[0]
			if pick != "":
				player.get_animation(pick).loop_mode = Animation.LOOP_LINEAR
				player.play(pick)
		out.append([f.get_basename(), inst])
	return out


func _materials() -> Array:
	var out: Array = []
	for s in KIT_SETS:
		var m := _kit_material(s)
		if m == null:
			continue
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.9
		sphere.height = 1.8
		ball.mesh = sphere
		ball.material_override = m
		out.append(["T_" + s, ball])
	return out


func _kit_material(set_name: String) -> StandardMaterial3D:
	var base := TP + "quaternius_downtown/models/T_" + set_name
	if not ResourceLoader.exists(base + "_BaseColor.png"):
		missing.append(base + "_BaseColor.png")
		return null
	loaded += 1
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(base + "_BaseColor.png")
	if ResourceLoader.exists(base + "_Normal.png"):
		m.normal_enabled = true
		m.normal_texture = load(base + "_Normal.png")
	if ResourceLoader.exists(base + "_ORM.png"):
		var orm: Texture2D = load(base + "_ORM.png")
		m.ao_enabled = true
		m.ao_texture = orm
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.roughness_texture = orm
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.metallic = 1.0
		m.metallic_texture = orm
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	return m


func _kit_paths() -> Array:
	var out: Array = []
	for p in KIT_PIECES:
		out.append(TP + "quaternius_downtown/models/" + p + ".gltf")
	return out


func _tree_paths() -> Array:
	var out: Array = []
	for t in TREES:
		out.append(TP + "quaternius_trees/" + t + ".fbx")
	return out


## Files with ext in a pack folder, sorted; with per_folder, one <id>/<id>.gltf per subfolder.
func _dir_paths(pack: String, ext: String, per_folder := false) -> Array:
	var out: Array = []
	var dir := DirAccess.open(TP + pack)
	if dir == null:
		missing.append(TP + pack + "/")
		return out
	if per_folder:
		for d in dir.get_directories():
			out.append(TP + pack + "/" + d + "/" + d + ".gltf")
	else:
		for f in dir.get_files():
			if f.ends_with(ext):
				out.append(TP + pack + "/" + f)
	out.sort()
	return out


func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var p := _find_player(c)
		if p != null:
			return p
	return null


## Bounds of every mesh under n, in n's parent space.
func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var has := false
	var local := xf * (n as Node3D).transform if n is Node3D else xf
	if n is VisualInstance3D:
		box = local * (n as VisualInstance3D).get_aabb()
		has = true
	for c in n.get_children():
		var cb := _aabb(c, local)
		if cb.size != Vector3.ZERO:
			box = cb if not has else box.merge(cb)
			has = true
	return box


func _label(text: String, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color("#f2ead8")
	return l
