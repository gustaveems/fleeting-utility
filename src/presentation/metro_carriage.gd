class_name MetroCarriage
extends WorldRoot
## PRESENTATION — the metro ride's world (Act I, 7c): one carriage at the diorama's scale,
## along X, centred on the origin (the player's clamp is origin-centred). The far wall
## (−Z) is a long window with the city scrolling past; the camera-side wall (+Z) is cut
## to sill height, like the apartment's. Commuters stand and sit; the ads change with the
## city's barometer (set_stage). Starts dormant; MetroRide activates it.

const HALF_LENGTH := 4.0
const HALF_WIDTH := 0.75
const HEIGHT := 1.35
## People at the player's avatar scale.
const PERSON_SCALE := 0.47

## The ride's own Environment (MetroRide swaps it in).
var environment: Environment

var _ads: Array[Label3D] = []
var _skyline: Array[Node3D] = []


func _init() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.04, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.6, 0.62)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC


func _ready() -> void:
	_build()
	set_active(false)


func _process(delta: float) -> void:
	# The city slides past the window.
	for b in _skyline:
		b.position.x += 9.0 * delta
		if b.position.x > 30.0:
			b.position.x -= 60.0


## Show the ads for barometer stage `stage` (ActOneScript.RIDE_ADS).
func set_stage(stage: int) -> void:
	var texts: Array = ActOneScript.RIDE_ADS[clampi(stage, 0, ActOneScript.RIDE_ADS.size() - 1)]
	for i in _ads.size():
		_ads[i].text = str(texts[i % texts.size()])


func _build() -> void:
	var floor_mat := _mat(Color(0.22, 0.23, 0.22), 0.8)
	var wall := _mat(Color(0.34, 0.36, 0.33), 0.9)
	_box(Vector3(0, -0.02, 0), Vector3(HALF_LENGTH * 2, 0.04, HALF_WIDTH * 2), floor_mat)
	# Far wall: a sill, the window band, a header; near wall cut to sill height.
	_box(Vector3(0, 0.2, -HALF_WIDTH), Vector3(HALF_LENGTH * 2, 0.4, 0.05), wall)
	_box(Vector3(0, HEIGHT - 0.1, -HALF_WIDTH), Vector3(HALF_LENGTH * 2, 0.2, 0.05), wall)
	var glass := _mat(Color(0.08, 0.12, 0.16, 0.35), 0.1)
	_box(Vector3(0, 0.8, -HALF_WIDTH), Vector3(HALF_LENGTH * 2, 0.8, 0.02), glass)
	_box(Vector3(0, 0.2, HALF_WIDTH), Vector3(HALF_LENGTH * 2, 0.4, 0.05), wall)
	for side in [-1.0, 1.0]:
		_box(
			Vector3(side * HALF_LENGTH, HEIGHT * 0.5, 0),
			Vector3(0.05, HEIGHT, HALF_WIDTH * 2),
			wall
		)
	# Colliders: you stay in the carriage.
	_wall_body(Vector3(0, 0.5, -HALF_WIDTH - 0.05), Vector3(HALF_LENGTH * 2, 1.0, 0.1))
	_wall_body(Vector3(0, 0.5, HALF_WIDTH + 0.05), Vector3(HALF_LENGTH * 2, 1.0, 0.1))
	for side in [-1.0, 1.0]:
		_wall_body(Vector3(side * (HALF_LENGTH + 0.05), 0.5, 0), Vector3(0.1, 1.0, HALF_WIDTH * 2))
	# Seats along the far wall, poles, the fluorescent strip and its light.
	var seat := _mat(Color(0.42, 0.46, 0.44), 0.7)
	var steel := _mat(Color(0.7, 0.72, 0.74), 0.25)
	for k in 6:
		var x := -HALF_LENGTH + 0.8 + k * 1.3
		_box(Vector3(x, 0.22, -HALF_WIDTH + 0.2), Vector3(0.9, 0.06, 0.3), seat)
		_box(Vector3(x + 0.65, HEIGHT * 0.5, 0.1), Vector3(0.02, HEIGHT, 0.02), steel)
	var tube := _mat(Color(0.9, 0.95, 1.0), 0.5)
	tube.emission_enabled = true
	tube.emission = Color(0.9, 0.95, 1.0)
	tube.emission_energy_multiplier = 1.6
	_box(Vector3(0, HEIGHT - 0.02, 0), Vector3(HALF_LENGTH * 1.8, 0.02, 0.06), tube)
	var light := OmniLight3D.new()
	light.light_color = Color(0.85, 0.94, 1.0)
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.position = Vector3(0, HEIGHT - 0.1, 0)
	add_child(light)
	# Ads above the window.
	for k in 3:
		var ad := Label3D.new()
		ad.font_size = 40
		ad.pixel_size = 0.004
		ad.modulate = [Color(0.9, 0.2, 0.6), Color(0.2, 0.84, 0.9), Color(0.95, 0.8, 0.2)][k]
		ad.position = Vector3(-2.6 + k * 2.6, HEIGHT - 0.12, -HALF_WIDTH + 0.04)
		add_child(ad)
		_ads.append(ad)
	set_stage(0)
	# Commuters: standing in the aisle, slumped on the seats.
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for k in 7:
		var f := StreetFigure.new()
		f.dress = [StreetFigure.Dress.MIDDLE, StreetFigure.Dress.POOR][k % 2]
		var sitting := k % 3 == 0
		f.pose = StreetFigure.Pose.SLUMP if sitting else StreetFigure.Pose.STAND
		f.scale = Vector3.ONE * PERSON_SCALE
		var x := -HALF_LENGTH + 0.6 + k * 1.1
		f.position = Vector3(
			x,
			0.24 if sitting else 0.0,
			-HALF_WIDTH + 0.22 if sitting else rng.randf_range(-0.2, 0.3)
		)
		f.rotation_degrees.y = 0.0 if sitting else rng.randf_range(0, 360)
		add_child(f)
	# The city outside, sliding past the window.
	var tower := _mat(Color(0.22, 0.27, 0.3), 0.85)
	var lit := _mat(Color(0.9, 0.7, 0.35), 0.6)
	lit.emission_enabled = true
	lit.emission = Color(0.9, 0.62, 0.3)
	for k in 14:
		var b := Node3D.new()
		b.position = Vector3(-30 + k * 4.3, 0, -rng.randf_range(6, 14))
		add_child(b)
		var h := rng.randf_range(4, 14)
		_box_in(b, Vector3(0, h * 0.5 - 1.5, 0), Vector3(rng.randf_range(2, 3.5), h, 2.5), tower)
		for w in 4:
			_box_in(
				b,
				Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0, h - 2), 1.26),
				Vector3(0.3, 0.2, 0.02),
				lit
			)
		_skyline.append(b)


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
