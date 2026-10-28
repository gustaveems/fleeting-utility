class_name RooftopLounge
extends WorldRoot
## PRESENTATION — the crowd's rooftop (the status loop; Ticket-24): a terrace high on the
## rich side, at the diorama's scale like the carriage, along X and centred on the origin
## (the player's clamp is origin-centred). Teak deck, glass balustrade, a bar, low
## sofas, string lights; the corpo crowd in their veils, the friend among them; the
## towers of the rich side beyond. The banner names the night (set_event). Starts
## dormant; Standing activates it.

const HALF_LENGTH := 4.0
const HALF_WIDTH := 2.0
const RAIL := 0.5
const PERSON_SCALE := 0.47
## Where he arrives (by the stairs, the camera end).
const START := Vector3(-2.8, 0, 1.2)

## The night's Environment (Standing swaps it in).
var environment: Environment

var _banner: Label3D


func _init() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.04, 0.08)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.55, 0.5)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true


func _ready() -> void:
	_build()
	set_active(false)


func set_event(title: String) -> void:
	_banner.text = title


func _build() -> void:
	# The deck: teak boards.
	var teak := _mat(Color(0.3, 0.2, 0.13), 0.6)
	_box(Vector3(0, -0.02, 0), Vector3(HALF_LENGTH * 2, 0.04, HALF_WIDTH * 2), teak)
	var seam := _mat(Color(0.16, 0.1, 0.07), 0.8)
	for k in 16:
		var z := -HALF_WIDTH + 0.25 + k * 0.25
		_box(Vector3(0, 0.001, z), Vector3(HALF_LENGTH * 2, 0.002, 0.01), seam)
	# Glass balustrade on three sides (the camera side stays low and open), a steel cap.
	var glass := _mat(Color(0.7, 0.8, 0.9, 0.18), 0.05)
	glass.metallic = 0.4
	var steel := _mat(Color(0.75, 0.76, 0.78), 0.25)
	steel.metallic = 0.8
	_box(Vector3(0, RAIL * 0.5, -HALF_WIDTH), Vector3(HALF_LENGTH * 2, RAIL, 0.02), glass)
	_box(Vector3(0, RAIL, -HALF_WIDTH), Vector3(HALF_LENGTH * 2, 0.03, 0.05), steel)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * HALF_LENGTH, RAIL * 0.5, 0), Vector3(0.02, RAIL, HALF_WIDTH * 2), glass)
		_box(Vector3(side * HALF_LENGTH, RAIL, 0), Vector3(0.05, 0.03, HALF_WIDTH * 2), steel)
	_box(Vector3(0, 0.06, HALF_WIDTH), Vector3(HALF_LENGTH * 2, 0.12, 0.05), steel)
	_wall_body(Vector3(0, 0.5, -HALF_WIDTH - 0.05), Vector3(HALF_LENGTH * 2, 1.0, 0.1))
	_wall_body(Vector3(0, 0.5, HALF_WIDTH + 0.05), Vector3(HALF_LENGTH * 2, 1.0, 0.1))
	for side in [-1.0, 1.0]:
		_wall_body(Vector3(side * (HALF_LENGTH + 0.05), 0.5, 0), Vector3(0.1, 1.0, HALF_WIDTH * 2))
	_bar()
	_lounge()
	_string_lights()
	_skyline()
	_crowd()
	# The night's banner, over the far rail.
	var board := _mat(Color(0.05, 0.05, 0.06), 0.4)
	board.emission_enabled = true
	board.emission = Color(0.1, 0.08, 0.05)
	_box(Vector3(0.6, 1.05, -HALF_WIDTH - 0.05), Vector3(3.2, 0.42, 0.04), board)
	_banner = Label3D.new()
	_banner.name = "Banner"
	_banner.font_size = 64
	_banner.pixel_size = 0.0035
	_banner.modulate = Color(0.95, 0.78, 0.4)
	_banner.outline_size = 0
	_banner.position = Vector3(0.6, 1.05, -HALF_WIDTH - 0.02)
	add_child(_banner)


## The bar at the far end: a lit counter, bottles on it.
func _bar() -> void:
	var stone := _mat(Color(0.9, 0.88, 0.84), 0.3)
	_box(Vector3(3.2, 0.25, -0.9), Vector3(0.45, 0.5, 1.6), stone)
	var glow := _mat(Color(0.95, 0.7, 0.35), 0.5)
	glow.emission_enabled = true
	glow.emission = Color(0.95, 0.65, 0.3)
	glow.emission_energy_multiplier = 2.0
	_box(Vector3(2.96, 0.03, -0.9), Vector3(0.02, 0.04, 1.6), glow)
	var wine := CityKit.prop(
		CityKit.polyhaven("wine_bottles_01"), self, Vector3(3.2, 0.5, -1.2), 0.0, 0.0
	)
	if wine != null:
		wine.scale = Vector3.ONE * PERSON_SCALE
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.45)
	light.light_energy = 1.2
	light.omni_range = 3.0
	light.position = Vector3(3.0, 0.8, -0.9)
	add_child(light)


## Low cream sofas round a table, planters at the corners.
func _lounge() -> void:
	var cream := _mat(Color(0.86, 0.82, 0.74), 0.8)
	var dark := _mat(Color(0.12, 0.11, 0.1), 0.4)
	for spec in [
		[Vector3(-0.6, 0.1, -1.4), Vector3(1.4, 0.2, 0.45)],
		[Vector3(-1.6, 0.1, -0.5), Vector3(0.45, 0.2, 1.2)]
	]:
		_box(spec[0], spec[1], cream)
	_box(Vector3(-0.6, 0.12, -0.6), Vector3(0.7, 0.04, 0.5), dark)
	for at in [Vector3(-3.5, 0, -1.6), Vector3(3.5, 0, 1.5), Vector3(-3.5, 0, 1.5)]:
		var p := CityKit.prop(CityKit.polyhaven("planter_box_01"), self, at, 0.0, 0.0)
		if p != null:
			p.scale = Vector3.ONE * PERSON_SCALE


## Three runs of warm bulbs over the deck, and the light they give.
func _string_lights() -> void:
	var bulb := _mat(Color(1.0, 0.85, 0.55), 0.5)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.8, 0.5)
	bulb.emission_energy_multiplier = 3.0
	var wire := _mat(Color(0.05, 0.05, 0.05), 0.8)
	for z in [-1.2, 0.0, 1.2]:
		_box(Vector3(0, 1.3, z), Vector3(HALF_LENGTH * 2, 0.006, 0.006), wire)
		for k in 14:
			var x := -HALF_LENGTH + 0.3 + k * 0.57
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.025
			sm.height = 0.05
			s.mesh = sm
			s.material_override = bulb
			s.position = Vector3(x, 1.27 - 0.04 * sin(k * 0.55), z)
			add_child(s)
	for x in [-2.0, 1.5]:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.55)
		light.light_energy = 1.0
		light.omni_range = 4.0
		light.position = Vector3(x, 1.2, 0)
		add_child(light)


## The rich side beyond the rail: glass towers, lit, close and high.
func _skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	var tower := _mat(Color(0.1, 0.13, 0.17), 0.3)
	var kit_ok := ResourceLoader.exists(CityKit.DIR + "Metal_FullWindow.gltf")
	for k in 9:
		var b := Node3D.new()
		b.position = Vector3(-16 + k * 4.0, -6.0, -rng.randf_range(7, 15))
		add_child(b)
		var h := rng.randf_range(10, 24)
		_box_in(b, Vector3(0, h * 0.5, 0), Vector3(2.8, h, 2.5), tower)
		if kit_ok:
			var holder := Node3D.new()
			holder.scale = Vector3.ONE * PERSON_SCALE
			holder.position = Vector3(0, 0, 1.26)
			b.add_child(holder)
			var kit := CityKit.new()
			kit.facade(
				Vector3(-3, 0, 0), Vector3.BACK, 3, int(h / 1.41), CityKit.Style.METAL, k * 7
			)
			kit.build(holder)


## The crowd: veiled, in clusters; the friend by the bar.
func _crowd() -> void:
	var spots: Array = [
		[Vector3(0.6, 0, -0.2), 200.0, StreetFigure.Pose.HUDDLE],
		[Vector3(1.0, 0, 0.3), 250.0, StreetFigure.Pose.STAND],
		[Vector3(1.4, 0, -0.4), 160.0, StreetFigure.Pose.HUDDLE],
		[Vector3(-0.9, 0, -1.4), 0.0, StreetFigure.Pose.SLUMP],
		[Vector3(2.4, 0, 0.8), 220.0, StreetFigure.Pose.STAND],
	]
	for spec in spots:
		var f := StreetFigure.new()
		f.dress = StreetFigure.Dress.SUIT
		f.veiled = true
		f.solid = true
		f.pose = spec[2]
		f.position = spec[0]
		f.rotation_degrees.y = spec[1]
		f.scale = Vector3.ONE * PERSON_SCALE
		add_child(f)
	var friend := StreetFigure.new()
	friend.name = "Friend"
	friend.dress = StreetFigure.Dress.FRIEND
	friend.pose = StreetFigure.Pose.HUDDLE
	friend.position = Vector3(2.6, 0, -0.5)
	friend.rotation_degrees.y = 260.0
	friend.scale = Vector3.ONE * PERSON_SCALE
	friend.solid = true
	add_child(friend)


func _wall_body(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	return _box_in(self, at, size, mat)


func _box_in(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


func _mat(c: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
