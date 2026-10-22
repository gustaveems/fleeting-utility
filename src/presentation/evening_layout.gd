class_name EveningLayout
extends Node3D
## PRESENTATION — Night Zero's evening, greybox layout (Ticket-16 Phase 2; graphics come
## after the mechanics). Everything is authored in real metres inside a container scaled
## to the game's diorama (WORLD_SCALE), so the playable walk matches the apartment.
##
##   the other side   a boulevard (z +60 → −60): stylish towers both sides, the
##                    restaurant door at the top, a campaign shoot, a boutique window
##                    with the valley in it, couples, the metro entrance at the bottom
##   the restaurant   a separate stage: one round table, five chairs, five diners
##   the car route    a wide avenue the car glides down (seen from the air)
##   the night train  a carriage interior for the ride home
##
## Walk beats are player sensors: `beat_entered(name)` fires once per zone.

signal beat_entered(beat: String)

const WORLD_SCALE := 0.47
const HALF_WIDTH := 13.0
const HALF_LENGTH := 60.0
const RESTAURANT_DOOR := Vector3(10, 0, 56)
const WALK_START := Vector3(7, 0, 54)
const STATION := Vector3(0, 0, -55)
## Walk beats: name → real position.
const BEATS := {
	"shoot": Vector3(-7, 0, 26),
	"window": Vector3(10, 0, -4),
	"couple": Vector3(-8, 0, -30),
	"station": Vector3(0, 0, -53),
}
## Stages away from the boulevard (real metres).
const DINNER_AT := Vector3(300, 0, 0)
const CAR_ROUTE: Array[Vector3] = [Vector3(-160, 0, 140), Vector3(-160, 0, -120)]
const TRAIN_AT := Vector3(-300, 0, 0)
## Fictional houses on the shopfronts (neon over the podiums).
const BRANDS: Array[String] = [
	"AUREL", "MAISON VÉRIDE", "HERITAGE", "FOCUS+ ELITE", "OSTRA", "LUMEN & SON"
]
const FAB := "res://assets/third_party/fab/"
## Signs on the near (camera-side) shopfronts face the camera, not the street: seen from
## behind, the iso view would read them mirrored.
const NEAR_SIGN_YAW := 90.0

## The seated diners, for the director (friend first).
var diners: Array[StreetFigure] = []
var car: Node3D

var _world: Node3D
var _fired: Dictionary = {}
var _kit := CityKit.new()
var _brand_no: int = 0


func _ready() -> void:
	_world = Node3D.new()
	_world.name = "World"
	_world.scale = Vector3.ONE * WORLD_SCALE
	add_child(_world)
	_build_boulevard()
	_build_beats()
	_build_restaurant()
	_build_car_route()
	_build_train()
	if _has_kit():
		_kit.build(_world)
		_dress_street()
		_dress_shoot()
		_dress_restaurant()
		_dress_train()


## A real-metre layout point in the game's (scaled) world space.
func world(real: Vector3) -> Vector3:
	return real * WORLD_SCALE


## The walkable half-extents in world space (the player's clamp).
func walk_extents() -> Vector2:
	return Vector2(HALF_WIDTH, HALF_LENGTH) * WORLD_SCALE


## ----- THE BOULEVARD ----------------------------------------------------------------------


func _build_boulevard() -> void:
	_box(
		Vector3(0, -0.05, 0),
		Vector3(HALF_WIDTH * 2 + 40, 0.1, HALF_LENGTH * 2 + 20),
		_mat(Color(0.18, 0.19, 0.21), 0.3)
	)
	for side in [-1.0, 1.0]:
		_box(
			Vector3(side * 11, 0.08, 0),
			Vector3(6, 0.16, HALF_LENGTH * 2),
			_mat(Color(0.75, 0.74, 0.72), 0.3)
		)
	# Towers: slender, varied, lit, styled (greybox: colours and setbacks only).
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var z := HALF_LENGTH
	while z > -HALF_LENGTH:
		var depth := float(rng.randi_range(5, 9) * 2)  # whole 2 m kit modules
		for side in [-1.0, 1.0]:
			# The camera looks from +X: that side stays a low shopfront podium (like the
			# apartment's cut near walls) so the street reads; the far side is the skyline.
			var h := rng.randf_range(40, 110) if side < 0 else rng.randf_range(4, 7)
			var tint := Color(0.55, 0.6, 0.68).lerp(Color(0.85, 0.8, 0.7), rng.randf())
			if _has_kit():
				_real_block(side, z, depth, h, rng)
			else:
				_box(
					Vector3(side * (HALF_WIDTH + 1 + 8), h * 0.5, z - depth * 0.5),
					Vector3(16, h, depth - 1),
					_mat(tint, 0.25)
				)
			# A lit shopfront band at street level.
			var glow := _mat(Color(1.0, 0.92, 0.78), 0.2)
			glow.emission_enabled = true
			glow.emission = Color(1.0, 0.9, 0.72)
			glow.emission_energy_multiplier = 1.2
			_box(
				Vector3(side * (HALF_WIDTH + 1.05), 2.2, z - depth * 0.5),
				Vector3(0.1, 3.2, depth - 2),
				glow
			)
		z -= depth
	# Even, white street light: nothing in shadow on this side.
	z = HALF_LENGTH - 5
	while z > -HALF_LENGTH:
		for side in [-1.0, 1.0]:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(0.96, 0.97, 1.0)
			lamp.light_energy = 1.2
			lamp.omni_range = 16.0
			lamp.position = Vector3(side * 9, 9, z)
			_world.add_child(lamp)
		z -= 14
	# Restaurant door and the metro entrance.
	_box(
		RESTAURANT_DOOR + Vector3(2.4, 1.5, 0),
		Vector3(0.3, 3.0, 2.4),
		_mat(Color(0.12, 0.1, 0.08), 0.4)
	)
	_label(
		"SÉRAC · members",
		RESTAURANT_DOOR + Vector3(2.3, 3.6, 0),
		NEAR_SIGN_YAW,
		Color(0.95, 0.85, 0.6)
	)
	_box(STATION + Vector3(0, 0.6, -1.5), Vector3(6, 1.2, 5), _mat(Color(0.25, 0.27, 0.3), 0.6))
	_label("METRO", STATION + Vector3(0, 3.2, 1), 0.0, Color(0.2, 0.84, 0.9))
	# People: couples and suits strolling, all lit.
	var dresses := [StreetFigure.Dress.SUIT, StreetFigure.Dress.FRIEND, StreetFigure.Dress.SUIT]
	for k in 14:
		var f := StreetFigure.new()
		f.dress = dresses[k % 3]
		f.pose = StreetFigure.Pose.STAND if k % 3 == 0 else StreetFigure.Pose.WALK
		f.position = Vector3(
			(-1.0 if k % 2 == 0 else 1.0) * rng.randf_range(9, 12.5), 0.16, rng.randf_range(-48, 48)
		)
		f.rotation_degrees.y = rng.randf_range(0, 360)
		_world.add_child(f)


## The beats along the walk: the campaign shoot, the window, a couple; the station.
func _build_beats() -> void:
	var shoot: Vector3 = BEATS["shoot"]
	var model := StreetFigure.new()
	model.dress = StreetFigure.Dress.FRIEND
	model.pose = StreetFigure.Pose.STAND
	model.position = shoot + Vector3(-3, 0.16, 0)
	_world.add_child(model)
	var photographer := StreetFigure.new()
	photographer.dress = StreetFigure.Dress.SUIT
	photographer.position = shoot + Vector3(1, 0.16, 0)
	photographer.rotation_degrees.y = 90
	_world.add_child(photographer)
	var fog := _mat(Color(0.9, 0.9, 0.88, 0.35), 0.9)
	fog.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(shoot + Vector3(-3, 0.6, 0), Vector3(4, 1.2, 4), fog)
	for k in 12:
		var leaf := _mat(Color(0.95, 0.6, 0.2), 0.8)
		_box(
			shoot + Vector3(-3 + randf_range(-2, 2), 0.2, randf_range(-2, 2)),
			Vector3(0.15, 0.02, 0.1),
			leaf
		)
	var flash := OmniLight3D.new()
	flash.light_energy = 6.0
	flash.omni_range = 6.0
	flash.position = shoot + Vector3(0, 2.5, 0)
	_world.add_child(flash)
	var window: Vector3 = BEATS["window"]
	var campaign := _mat(Color(0.85, 0.62, 0.3), 0.3)
	campaign.emission_enabled = true
	campaign.emission = Color(0.85, 0.6, 0.3)
	campaign.emission_energy_multiplier = 1.4
	_box(window + Vector3(3, 2.2, 0), Vector3(0.1, 3, 5), campaign)
	_label(
		"HERITAGE COLLECTION", window + Vector3(2.9, 4.2, 0), NEAR_SIGN_YAW, Color(0.2, 0.16, 0.1)
	)
	for b: String in BEATS:
		var zone := Area3D.new()
		zone.name = "Beat_" + b
		PhysicsLayers.make_player_sensor(zone)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 4.0
		cyl.height = 4.0
		shape.shape = cyl
		zone.add_child(shape)
		zone.position = BEATS[b]
		zone.body_entered.connect(func(_body: Node3D): _beat(b))
		_world.add_child(zone)


func _beat(b: String) -> void:
	if _fired.has(b):
		return
	_fired[b] = true
	beat_entered.emit(b)


## ----- STAGES --------------------------------------------------------------------------


func _build_restaurant() -> void:
	var at := DINNER_AT
	_box(at + Vector3(0, -0.05, 0), Vector3(14, 0.1, 12), _mat(Color(0.3, 0.22, 0.16), 0.4))
	_box(at + Vector3(0, 2.5, -6), Vector3(14, 5, 0.2), _mat(Color(0.2, 0.18, 0.16), 0.6))
	var table := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 1.1
	cyl.height = 0.08
	table.mesh = cyl
	table.material_override = _mat(Color(0.92, 0.9, 0.86), 0.3)
	table.position = at + Vector3(0, 0.75, 0)
	_world.add_child(table)
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.82, 0.6)
	warm.light_energy = 3.0
	warm.omni_range = 7.0
	warm.position = at + Vector3(0, 2.6, 0)
	_world.add_child(warm)
	# Friend, the three corpo friends, and him (last): seated round the table.
	var dresses := [
		StreetFigure.Dress.FRIEND,
		StreetFigure.Dress.SUIT,
		StreetFigure.Dress.SUIT,
		StreetFigure.Dress.SUIT,
		StreetFigure.Dress.HERO
	]
	for k in 5:
		var a := TAU * k / 5.0
		var seat := at + Vector3(sin(a) * 1.7, 0.45, cos(a) * 1.7)
		_box(
			seat + Vector3(0, -0.22, 0), Vector3(0.5, 0.45, 0.5), _mat(Color(0.25, 0.2, 0.16), 0.6)
		)
		var d := StreetFigure.new()
		# The corpo friends wear veils: their faces are a product.
		d.veiled = k in [1, 2, 3]
		d.dress = dresses[k]
		d.pose = StreetFigure.Pose.SLUMP
		d.position = seat
		_world.add_child(d)
		d.look_at(_world.to_global(at + Vector3(0, 0.45, 0)), Vector3.UP)
		diners.append(d)


func _build_car_route() -> void:
	var a: Vector3 = CAR_ROUTE[0]
	var b: Vector3 = CAR_ROUTE[1]
	_box(
		(a + b) * 0.5 + Vector3(0, -0.05, 0),
		Vector3(20, 0.1, a.distance_to(b) + 40),
		_mat(Color(0.2, 0.2, 0.22), 0.3)
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var z := a.z
	while z > b.z:
		for side in [-1.0, 1.0]:
			var h := rng.randf_range(60, 160)
			var tint := Color(0.6, 0.66, 0.75).lerp(Color(0.9, 0.85, 0.75), rng.randf())
			_box(Vector3(a.x + side * 24, h * 0.5, z), Vector3(18, h, 16), _mat(tint, 0.2))
			if _has_kit():
				# Glass curtain walls facing the avenue, over the massing.
				var face_x: float = a.x + side * 15
				var out := Vector3.LEFT if side > 0 else Vector3.RIGHT
				var start_z := z - 8.0 if side > 0 else z + 8.0
				_kit.facade(
					Vector3(face_x, 0, start_z),
					out,
					8,
					int(h / CityKit.FLOOR),
					CityKit.Style.METAL,
					int(z) * 7 + int(side)
				)
		z -= 22
	car = CityKit.prop(CityKit.car("SportsCar"), _world, a, 180.0, 0.0)
	if car == null:
		car = Node3D.new()
		_world.add_child(car)
		car.position = a
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.8, 1.0, 4.2)
		body.mesh = box
		body.position.y = 0.5
		car.add_child(body)


func _build_train() -> void:
	var at := TRAIN_AT
	var wall := _mat(Color(0.3, 0.32, 0.3), 0.9)
	wall.cull_mode = BaseMaterial3D.CULL_FRONT
	var shell := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.1, 3.3, 18)
	shell.mesh = box
	shell.material_override = wall
	shell.position = at + Vector3(0, 1.65, 0)
	_world.add_child(shell)
	var tube := OmniLight3D.new()
	tube.light_color = Color(0.8, 0.95, 1.0)
	tube.light_energy = 1.4
	tube.omni_range = 10.0
	tube.position = at + Vector3(0, 3.0, 0)
	_world.add_child(tube)
	for k in 6:
		var f := StreetFigure.new()
		f.dress = StreetFigure.Dress.POOR if k % 2 == 0 else StreetFigure.Dress.MIDDLE
		f.pose = StreetFigure.Pose.SLUMP if k % 3 == 0 else StreetFigure.Pose.STAND
		f.position = (
			at + Vector3(1.15 if k % 2 == 0 else -0.3, 0.5 if k % 3 == 0 else 0.0, -7 + k * 2.6)
		)
		f.rotation_degrees.y = 90 if k % 2 == 0 else randf_range(0, 360)
		_world.add_child(f)


## ----- HELPERS -------------------------------------------------------------------------


func _box(at: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	_world.add_child(mi)


func _label(text: String, at: Vector3, yaw: float, c: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.02
	l.modulate = c
	l.position = at
	l.rotation_degrees.y = yaw
	_world.add_child(l)


func _mat(c: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## ----- REAL ART (when the asset packs are installed) ----------------------------------------


func _has_kit() -> bool:
	return ResourceLoader.exists(CityKit.DIR + "Metal_FullWindow.gltf")


## One block of the boulevard: far side a glass tower over its massing, near (camera)
## side a two-storey shopfront podium with a roof and a brand in neon.
func _real_block(side: float, z: float, depth: float, h: float, rng: RandomNumberGenerator) -> void:
	var modules := int(depth / CityKit.MODULE)
	var face_x := side * (HALF_WIDTH + 1)
	var dark := _mat(Color(0.08, 0.09, 0.11), 0.3)
	if side < 0:
		var floors := int(h / CityKit.FLOOR)
		_box(
			Vector3(face_x - 8, floors * CityKit.FLOOR * 0.5, z - depth * 0.5),
			Vector3(16, floors * CityKit.FLOOR, depth),
			dark
		)
		_kit.facade(
			Vector3(face_x, 0, z), Vector3.RIGHT, modules, floors, CityKit.Style.METAL, rng.randi()
		)
	else:
		_box(Vector3(face_x + 8, 3.0, z - depth * 0.5), Vector3(16, 6.0, depth), dark)
		_kit.facade(
			Vector3(face_x, 0, z - depth),
			Vector3.LEFT,
			modules,
			2,
			CityKit.Style.METAL,
			rng.randi()
		)
		var brand := BRANDS[_brand_no % BRANDS.size()]
		_brand_no += 1
		var neon: Color = [Color(0.95, 0.85, 0.6), Color(0.2, 0.84, 0.9), Color(0.95, 0.4, 0.7)][
			_brand_no % 3
		]
		_label(brand, Vector3(face_x + 2.0, 6.6, z - depth * 0.5), NEAR_SIGN_YAW, neon)


## Marble pavements, real lamps, planters, parked luxury, the skyline, flying traffic.
func _dress_street() -> void:
	var marble := _mat(Color(0.86, 0.85, 0.83), 0.22)
	var tex := CityKit.DIR + "T_MarbleFloor_BaseColor.png"
	if ResourceLoader.exists(tex):
		marble.albedo_texture = load(tex)
		marble.uv1_triplanar = true
		marble.uv1_scale = Vector3.ONE * 0.3
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 11, 0.17, 0), Vector3(6, 0.02, HALF_LENGTH * 2), marble)
	var z := HALF_LENGTH - 6
	while z > -HALF_LENGTH:
		for side in [-1.0, 1.0]:
			CityKit.prop(
				CityKit.polyhaven("street_lamp_01"),
				_world,
				Vector3(side * 8.6, 0.16, z),
				90.0 * side,
				0.0
			)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.94, 0.82)
			light.light_energy = 1.4
			light.omni_range = 12.0
			light.position = Vector3(side * 8.2, 3.8, z)
			_world.add_child(light)
			CityKit.prop(
				CityKit.polyhaven("planter_box_01"),
				_world,
				Vector3(side * 12.6, 0.16, z - 7),
				0.0,
				0.0
			)
		z -= 14
	for spec in [
		["SportsCar", Vector3(7, 0, 40), 180.0],
		["SUV", Vector3(7, 0, -18), 180.0],
		["SportsCar", Vector3(-7, 0, 8), 0.0]
	]:
		CityKit.prop(CityKit.car(spec[0]), _world, spec[1], spec[2], 0.0)
	var high := CityKit.prop(
		FAB + "highrise_06/high_rise_building.glb", _world, Vector3(-80, 0, -20), 90.0, 0.0
	)
	if high != null:
		high.scale = Vector3.ONE * 1.1
	var tower := CityKit.prop(
		FAB + "mega_tower/cyberpunk_skyscraper_3d_model.glb",
		_world,
		Vector3(-110, 110, 40),
		30.0,
		0.0
	)
	if tower != null:
		tower.scale = Vector3.ONE * 220.0
	var traffic := FlyingTraffic.new()
	_world.add_child(traffic)
	traffic.add_lane(Vector3(-4, 40, 70), Vector3(-4, 40, -70), 30.0, 4, 21)
	traffic.add_lane(Vector3(4, 52, -70), Vector3(4, 52, 70), 36.0, 4, 22)


## The shoot: light stands and a softbox, a reflector.
func _dress_shoot() -> void:
	var shoot: Vector3 = BEATS["shoot"]
	var steel := _mat(Color(0.15, 0.15, 0.16), 0.4)
	var soft := _mat(Color(1, 1, 1), 0.5)
	soft.emission_enabled = true
	soft.emission = Color(1, 0.98, 0.94)
	soft.emission_energy_multiplier = 2.0
	for x in [-0.5, -5.5]:
		_box(shoot + Vector3(x, 1.2, 2.2), Vector3(0.05, 2.4, 0.05), steel)
		_box(shoot + Vector3(x, 2.4, 2.0), Vector3(1.0, 0.8, 0.1), soft)
	var disc := _mat(Color(0.95, 0.85, 0.4), 0.2)
	disc.metallic = 0.9
	_box(shoot + Vector3(-3, 0.9, -2.2), Vector3(1.2, 1.2, 0.03), disc)


## The members' club: marble, dark panelling, gilt frames, the bust, low lamps, wine.
func _dress_restaurant() -> void:
	var at := DINNER_AT
	var tex := CityKit.DIR + "T_MarbleFloor_BaseColor.png"
	var floor := _mat(Color(0.9, 0.88, 0.85), 0.15)
	if ResourceLoader.exists(tex):
		floor.albedo_texture = load(tex)
		floor.uv1_triplanar = true
		floor.uv1_scale = Vector3.ONE * 0.4
	_box(at + Vector3(0, 0.01, 0), Vector3(14, 0.02, 12), floor)
	for x in [-3.5, 0.0, 3.5]:
		var frame := CityKit.prop(
			CityKit.polyhaven("fancy_picture_frame_01"),
			_world,
			at + Vector3(x, 2.0, -5.85),
			0.0,
			0.0
		)
		if frame != null:
			frame.scale = Vector3.ONE * 2.2
	_box(at + Vector3(-5, 0.6, -4.5), Vector3(0.6, 1.2, 0.6), _mat(Color(0.08, 0.07, 0.06), 0.3))
	CityKit.prop(
		CityKit.polyhaven("marble_bust_01"), _world, at + Vector3(-5, 1.2, -4.5), 30.0, 0.0
	)
	for k in 3:
		var lamp := CityKit.prop(
			CityKit.polyhaven("modern_ceiling_lamp_01"),
			_world,
			at + Vector3(-0.6 + k * 0.6, 2.2, 0),
			0.0,
			0.0
		)
		if lamp != null:
			lamp.scale = Vector3.ONE * 0.8
	CityKit.prop(CityKit.polyhaven("wine_bottles_01"), _world, at + Vector3(0, 0.79, 0), 0.0, 0.0)


## The night train waits at the platform: the old graffiti tram.
func _dress_train() -> void:
	var platform := TRAIN_AT + Vector3(9, 0, 0)
	_box(platform + Vector3(4, 0.5, 0), Vector3(5, 1.0, 26), _mat(Color(0.32, 0.32, 0.33), 0.9))
	CityKit.prop(
		FAB + "graffiti_train/SciFiTram.glb", _world, platform + Vector3(0, 0.4, 0), 90.0, 0.0
	)
