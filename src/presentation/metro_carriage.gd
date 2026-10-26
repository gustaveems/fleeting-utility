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
## 7d: the Heritage campaign's billboard, sliding past with the city (hidden until the
## campaign wears his canvas: CampaignImage shows it).
var campaign_board: CampaignBoard

var _ads: Array[Label3D] = []
var _skyline: Array[Node3D] = []
var _stopped: bool = false
var _stone_window: Node3D


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
	# The city slides past the window (unless the train is stopped at a station).
	if _stopped:
		return
	for b in _skyline:
		b.position.x += 9.0 * delta
		if b.position.x > 30.0:
			b.position.x -= 60.0
	if campaign_board != null:
		campaign_board.position.x += 9.0 * delta
		if campaign_board.position.x > 8.0:
			campaign_board.position.x -= 16.0


## 18a: the train stops at the Heritage Quarter, and outside the window is a boutique
## display: the fenced stone from his town, lit, priced. Off: back to the moving city.
func show_stone(on: bool) -> void:
	_stopped = on
	if _stone_window == null and on:
		_build_stone_window()
	if _stone_window != null:
		_stone_window.visible = on
	for b in _skyline:
		b.visible = not on


## Stopped at a station (the Heritage window): nothing slides past.
func is_stopped() -> bool:
	return _stopped


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
	# Window frame: mullions every 1.3 m along the band.
	var frame := _mat(Color(0.15, 0.16, 0.17), 0.4)
	for k in 7:
		_box(
			Vector3(-HALF_LENGTH + 0.05 + k * 1.32, 0.8, -HALF_WIDTH + 0.02),
			Vector3(0.04, 0.8, 0.03),
			frame
		)
	# Hanging straps from the grab rail.
	_box(Vector3(0, HEIGHT - 0.18, 0.15), Vector3(HALF_LENGTH * 1.9, 0.02, 0.02), steel)
	for k in 12:
		_box(
			Vector3(-HALF_LENGTH + 0.5 + k * 0.62, HEIGHT - 0.3, 0.15),
			Vector3(0.05, 0.2, 0.01),
			_mat(Color(0.85, 0.82, 0.7), 0.7)
		)
	# Graffiti tags on the end walls and seat backs; litter underfoot.
	var tags := ["NO LEASE", "B31", "WHO OWNS U", "★"]
	for k in tags.size():
		var g := Label3D.new()
		g.text = tags[k]
		g.font_size = 40
		g.pixel_size = 0.004
		g.modulate = [
			Color(0.95, 0.85, 0.2), Color(0.9, 0.3, 0.6), Color(0.3, 0.9, 0.6), Color(0.9, 0.9, 0.9)
		][k]
		g.position = Vector3(-HALF_LENGTH + 1.2 + k * 2.0, 0.3, -HALF_WIDTH + 0.06)
		g.rotation_degrees.z = randf_range(-12, 12)
		add_child(g)
	for k in 6:
		var pack := CityKit.prop(
			CityKit.polyhaven("cigarette_pack"),
			self,
			Vector3(randf_range(-3.6, 3.6), 0.0, randf_range(-0.3, 0.5)),
			randf_range(0, 360),
			0.0
		)
		if pack != null:
			pack.rotation_degrees.x = 90.0
			pack.scale = Vector3.ONE * 0.7
	# Ads above the window, each on a lit panel.
	var panel := _mat(Color(0.06, 0.06, 0.08), 0.4)
	panel.emission_enabled = true
	panel.emission = Color(0.12, 0.12, 0.16)
	for k in 3:
		_box(
			Vector3(-2.6 + k * 2.6, HEIGHT - 0.12, -HALF_WIDTH + 0.03),
			Vector3(2.2, 0.16, 0.01),
			panel
		)
	for k in 3:
		var ad := Label3D.new()
		ad.font_size = 40
		ad.pixel_size = 0.004
		ad.modulate = [Color(0.9, 0.2, 0.6), Color(0.2, 0.84, 0.9), Color(0.95, 0.8, 0.2)][k]
		ad.position = Vector3(-2.6 + k * 2.6, HEIGHT - 0.12, -HALF_WIDTH + 0.045)
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
	var kit_ok := ResourceLoader.exists(CityKit.DIR + "Brick_Window_Square_Single.gltf")
	for k in 14:
		var b := Node3D.new()
		b.position = Vector3(-30 + k * 4.3, 0, -rng.randf_range(6, 14))
		add_child(b)
		var h := rng.randf_range(4, 14)
		_box_in(b, Vector3(0, h * 0.5 - 1.5, 0), Vector3(2.8, h, 2.5), tower)
		if kit_ok:
			# A real block: brick or concrete facade (Downtown kit) at the diorama's scale.
			var holder := Node3D.new()
			holder.scale = Vector3.ONE * 0.47
			holder.position = Vector3(0, -1.5, 1.26)
			b.add_child(holder)
			var kit := CityKit.new()
			var style := CityKit.Style.BRICK if k % 3 != 0 else CityKit.Style.CONCRETE
			kit.facade(Vector3(-3, 0, 0), Vector3.BACK, 3, int(h / 1.41), style, k * 13)
			kit.build(holder)
		else:
			for w in 4:
				var at := Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0, h - 2), 1.26)
				_box_in(b, at, Vector3(0.3, 0.2, 0.02), lit)
		_skyline.append(b)
	# On its own short loop, so it comes round every few seconds of the ride.
	campaign_board = CampaignBoard.new()
	campaign_board.name = "CampaignBoard"
	campaign_board.board_scale = 2.6
	campaign_board.position = Vector3(-7.0, 1.7, -HALF_WIDTH - 3.5)
	add_child(campaign_board)


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


## The Heritage window, just beyond the carriage glass: warm light, a plinth, the stone
## in its little fence with the corporate plate, a price card.
func _build_stone_window() -> void:
	_stone_window = Node3D.new()
	_stone_window.name = "HeritageWindow"
	# Raised above the carriage's wall line: the camera looks down over it, not through it.
	_stone_window.position = Vector3(0.6, 1.05, -HALF_WIDTH - 1.4)
	add_child(_stone_window)
	var back := _mat(Color(0.9, 0.85, 0.75), 0.6)
	_box_in(_stone_window, Vector3(0, 0.9, -0.6), Vector3(3.0, 2.2, 0.05), back)
	_box_in(
		_stone_window,
		Vector3(0, 0.15, 0),
		Vector3(1.0, 0.3, 0.8),
		_mat(Color(0.12, 0.1, 0.08), 0.3)
	)
	var stone := CityKit.prop(
		CityKit.polyhaven("boulder_01"), _stone_window, Vector3(0, 0.3, 0), 30.0, 0.0
	)
	if stone != null:
		stone.scale = Vector3.ONE * 0.38
	else:
		_box_in(
			_stone_window,
			Vector3(0, 0.55, 0),
			Vector3(0.3, 0.5, 0.22),
			_mat(Color(0.5, 0.49, 0.46), 1.0)
		)
	var post := _mat(Color(0.2, 0.2, 0.2), 0.5)
	for k in 6:
		var a := TAU * k / 6.0
		_box_in(
			_stone_window,
			Vector3(cos(a) * 0.38, 0.45, sin(a) * 0.3),
			Vector3(0.02, 0.3, 0.02),
			post
		)
	var plate := _mat(Color(0.9, 0.9, 0.92), 0.3)
	plate.emission_enabled = true
	plate.emission = Color(0.2, 0.84, 0.9)
	_box_in(_stone_window, Vector3(0, 0.62, 0.13), Vector3(0.16, 0.06, 0.01), plate)
	# The shop glass, and the price card on its own little brass stand.
	var shop_glass := _mat(Color(0.8, 0.85, 0.9, 0.15), 0.05)
	shop_glass.metallic = 0.5
	_box_in(_stone_window, Vector3(0, 0.9, 0.55), Vector3(3.0, 2.2, 0.02), shop_glass)
	var brass := _mat(Color(0.85, 0.66, 0.25), 0.3)
	brass.metallic = 0.8
	_box_in(_stone_window, Vector3(1.05, 0.15, 0.25), Vector3(0.02, 0.3, 0.02), brass)
	var card := _mat(Color(0.95, 0.93, 0.88), 0.6)
	_box_in(_stone_window, Vector3(1.05, 0.32, 0.25), Vector3(0.42, 0.24, 0.01), card)
	var price := Label3D.new()
	price.text = ActOneScript.STONE_PRICE
	price.font_size = 32
	price.pixel_size = 0.0035
	price.modulate = Color(0.2, 0.16, 0.1)
	price.position = Vector3(1.05, 0.32, 0.26)
	_stone_window.add_child(price)
	var heritage := Label3D.new()
	heritage.text = "HERITAGE COLLECTION"
	heritage.font_size = 48
	heritage.pixel_size = 0.005
	heritage.modulate = Color(0.3, 0.22, 0.12)
	heritage.position = Vector3(0, 1.75, -0.55)
	_stone_window.add_child(heritage)
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.86, 0.62)
	warm.light_energy = 2.5
	warm.omni_range = 3.0
	warm.position = Vector3(0, 1.4, 0.4)
	_stone_window.add_child(warm)
