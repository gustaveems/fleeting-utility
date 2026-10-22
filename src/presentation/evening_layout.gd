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

## The seated diners, for the director (friend first).
var diners: Array[StreetFigure] = []
var car: Node3D

var _world: Node3D
var _fired: Dictionary = {}


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
		var depth := rng.randf_range(10, 18)
		for side in [-1.0, 1.0]:
			# The camera looks from +X: that side stays a low shopfront podium (like the
			# apartment's cut near walls) so the street reads; the far side is the skyline.
			var h := rng.randf_range(40, 110) if side < 0 else rng.randf_range(4, 7)
			var tint := Color(0.55, 0.6, 0.68).lerp(Color(0.85, 0.8, 0.7), rng.randf())
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
	_label("SÉRAC · members", RESTAURANT_DOOR + Vector3(2.3, 3.6, 0), -90.0, Color(0.95, 0.85, 0.6))
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
	_label("HERITAGE COLLECTION", window + Vector3(2.9, 4.2, 0), -90.0, Color(0.2, 0.16, 0.1))
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
