class_name PrologueAvenue
extends Node3D
## PRESENTATION — the walk from Block 31 station to his building (Ticket-15 A.2).
##
## A short avenue along −Z. He walks the median line, the same "DO NOT CROSS THE LINE"
## as in the carriage, between the classes:
##   left  (−X)  the rich: a clean, lit Heritage Collection boutique, a guard, a rope
##               line, suits queuing
##   right (+X)  the poor: tents, a trash fire, people slumped against the wall, a dealer
##               huddle, two men fighting
## Middle-class commuters pass with their heads down. Two suits cross his path ahead of
## him, never looking at him. It ends at the beige sliver wedged between two blocks.
##
## The director drives it with set_walk_distance(); everything else animates itself.

## Emitted when a suit crosses in front of him (tests).
signal suit_crossed

const START := Vector3(430, 0, -62)
const LENGTH := 50.0
## His building: the door is on the sliver's +Z face at the end of the walk.
const TOWER := Vector3(430, 0, -124)
const ROAD_HALF := 8.0
const RICH_X := 412.0
const POOR_X := 448.0
## Crossing suits: [the walk distance that triggers them, z where they cross].
const CROSSINGS: Array = [[8.0, -76.0], [26.0, -96.0]]
const CROSS_SPEED := 2.2

var hero: StreetFigure
var walk_distance: float = 0.0

var _crossers: Array[StreetFigure] = []
var _crossing_started: Array[bool] = []
var _commuters: Array[Dictionary] = []
var _fire_light: OmniLight3D
var _t: float = 0.0


func _ready() -> void:
	_build_street()
	_build_rich_side()
	_build_poor_side()
	_build_tower()
	_build_people()
	_build_lights()
	set_walk_distance(0.0)


func _process(delta: float) -> void:
	_t += delta
	if _fire_light != null:
		_fire_light.light_energy = 2.2 + sin(_t * 13.0) * 0.4 + sin(_t * 7.3) * 0.3
	for c in _commuters:
		var f: StreetFigure = c["figure"]
		f.position.z += float(c["speed"]) * delta
		if f.position.z > START.z + 6.0:
			f.position.z = START.z - LENGTH - 4.0
	for i in _crossers.size():
		if not _crossing_started[i]:
			continue
		var s := _crossers[i]
		if s.position.x > RICH_X + 2.0:
			s.position.x -= CROSS_SPEED * delta
			if s.position.x <= START.x and not s.has_meta("crossed"):
				s.set_meta("crossed", true)
				suit_crossed.emit()


## Place him `metres` down the avenue; trigger the crossings as he passes their marks.
func set_walk_distance(metres: float) -> void:
	walk_distance = clampf(metres, 0.0, LENGTH)
	if hero != null:
		hero.moving = metres < LENGTH - 0.05
		hero.position = START + Vector3(0, 0, -walk_distance)
	for i in CROSSINGS.size():
		if not _crossing_started[i] and walk_distance >= float(CROSSINGS[i][0]):
			_crossing_started[i] = true


func hero_head() -> Vector3:
	return hero.global_position + Vector3(0, 1.6, 0)


func door_position() -> Vector3:
	return TOWER + Vector3(0, 0, 6)


## ----- BUILD ---------------------------------------------------------------------------


func _build_street() -> void:
	var z_mid := START.z - LENGTH * 0.5
	_box(
		Vector3(START.x, 0.02, z_mid),
		Vector3(ROAD_HALF * 2, 0.04, LENGTH + 20),
		_mat(Color(0.08, 0.08, 0.09), 0.6)
	)
	# Sidewalks: clean stone on the rich side, cracked dark on the poor side.
	_box(
		Vector3(RICH_X + 5, 0.12, z_mid),
		Vector3(10, 0.24, LENGTH + 20),
		_mat(Color(0.62, 0.6, 0.56), 0.4)
	)
	_box(
		Vector3(POOR_X - 5, 0.12, z_mid),
		Vector3(10, 0.24, LENGTH + 20),
		_mat(Color(0.16, 0.15, 0.14), 1.0)
	)
	# The median line he walks: glowing, with the warning repeated along it.
	var line := _mat(Color(0.95, 0.42, 0.08), 0.5)
	line.emission_enabled = true
	line.emission = Color(0.95, 0.42, 0.08)
	line.emission_energy_multiplier = 1.6
	_box(Vector3(START.x, 0.05, z_mid), Vector3(0.25, 0.02, LENGTH + 20), line)
	var z := START.z - 4.0
	while z > START.z - LENGTH:
		for side in [-1.0, 1.0]:
			var text := Label3D.new()
			text.text = "DO NOT CROSS THE LINE"
			text.font_size = 64
			text.pixel_size = 0.008
			text.modulate = Color(0.95, 0.5, 0.15, 0.85)
			text.rotation_degrees = Vector3(-90, 90 if side > 0 else -90, 0)
			text.position = Vector3(START.x + side * 1.6, 0.06, z)
			add_child(text)
		z -= 12.0


func _build_rich_side() -> void:
	var z_mid := START.z - LENGTH * 0.5
	_box(
		Vector3(RICH_X - 8, 30, z_mid),
		Vector3(16, 60, LENGTH + 20),
		_mat(Color(0.74, 0.70, 0.62), 0.5)
	)
	# The Heritage Collection boutique: warm, clean, lit; the campaign's own store.
	var glass := _mat(Color(0.98, 0.84, 0.55), 0.2)
	glass.emission_enabled = true
	glass.emission = Color(0.98, 0.82, 0.5)
	glass.emission_energy_multiplier = 1.8
	_box(Vector3(RICH_X + 0.05, 3.0, -86), Vector3(0.2, 5, 12), glass)
	var sign := Label3D.new()
	sign.text = "HERITAGE COLLECTION"
	sign.font_size = 96
	sign.pixel_size = 0.02
	sign.modulate = Color(0.2, 0.16, 0.1)
	sign.outline_size = 0
	sign.rotation_degrees = Vector3(0, 90, 0)
	sign.position = Vector3(RICH_X + 0.3, 6.3, -86)
	add_child(sign)
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.86, 0.62)
	warm.light_energy = 4.0
	warm.omni_range = 16.0
	warm.position = Vector3(RICH_X + 3, 4, -86)
	add_child(warm)
	# Rope line in front of the door.
	var brass := _mat(Color(0.85, 0.66, 0.25), 0.3)
	for k in 4:
		_box(Vector3(RICH_X + 4.5, 0.6, -82 - k * 2.6), Vector3(0.12, 1.0, 0.12), brass)
	_box(
		Vector3(RICH_X + 4.5, 0.95, -86),
		Vector3(0.05, 0.05, 7.8),
		_mat(Color(0.5, 0.06, 0.08), 0.6)
	)


func _build_poor_side() -> void:
	var z_mid := START.z - LENGTH * 0.5
	_box(
		Vector3(POOR_X + 8, 26, z_mid),
		Vector3(16, 52, LENGTH + 20),
		_mat(Color(0.18, 0.2, 0.21), 1.0)
	)
	var canvas := _mat(Color(0.28, 0.3, 0.26), 1.0)
	for z in [-70.0, -96.0, -104.0]:
		var tent := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(2.4, 1.5, 2.8)
		tent.mesh = prism
		tent.material_override = canvas
		tent.position = Vector3(POOR_X - 3.0, 0.99, z)
		add_child(tent)
	# A trash fire in a barrel.
	_box(Vector3(POOR_X - 6.5, 0.7, -78), Vector3(0.7, 1.2, 0.7), _mat(Color(0.2, 0.12, 0.08), 0.9))
	var flame := _mat(Color(1.0, 0.5, 0.1), 0.5)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.45, 0.08)
	flame.emission_energy_multiplier = 3.0
	_box(Vector3(POOR_X - 6.5, 1.45, -78), Vector3(0.5, 0.4, 0.5), flame)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.5, 0.15)
	_fire_light.omni_range = 9.0
	_fire_light.position = Vector3(POOR_X - 6.5, 2.0, -78)
	add_child(_fire_light)
	# Neon over the poor side, BR '82.
	for spec in [
		[-68.0, Color(0.9, 0.2, 0.6), "ROOMS · HOURLY"],
		[-100.0, Color(0.2, 0.84, 0.9), "FOCUS+ CHEAP"]
	]:
		var neon := Label3D.new()
		neon.text = spec[2]
		neon.font_size = 96
		neon.pixel_size = 0.018
		neon.modulate = spec[1]
		neon.rotation_degrees = Vector3(0, -90, 0)
		neon.position = Vector3(POOR_X - 0.2, 5.0, spec[0])
		add_child(neon)
	for k in 6:
		_box(
			Vector3(POOR_X - 1.2 - randf() * 2.0, 0.3, -64 - k * 8.0),
			Vector3(0.6, 0.5, 0.5),
			_mat(Color(0.05, 0.05, 0.05), 0.4)
		)


## Street lighting tells the split: bright, even, white on the rich side; sparse,
## sodium, one of them dead, on the poor side.
func _build_lights() -> void:
	var z := START.z - 2.0
	var k := 0
	while z > START.z - LENGTH - 2.0:
		var rich := OmniLight3D.new()
		rich.light_color = Color(0.95, 0.97, 1.0)
		rich.light_energy = 2.2
		rich.omni_range = 11.0
		rich.position = Vector3(RICH_X + 6.0, 5.5, z)
		add_child(rich)
		_box(
			Vector3(RICH_X + 6.0, 2.8, z),
			Vector3(0.12, 5.6, 0.12),
			_mat(Color(0.8, 0.8, 0.82), 0.3)
		)
		if k % 2 == 0 and k != 2:
			var poor := OmniLight3D.new()
			poor.light_color = Color(1.0, 0.62, 0.25)
			poor.light_energy = 1.3
			poor.omni_range = 9.0
			poor.position = Vector3(POOR_X - 6.0, 5.0, z)
			add_child(poor)
		_box(
			Vector3(POOR_X - 6.0, 2.5, z),
			Vector3(0.12, 5.0, 0.12),
			_mat(Color(0.25, 0.22, 0.2), 0.8)
		)
		z -= 10.0
		k += 1
	# A soft key on him so the walk reads (the camera's practical, in film terms).
	var key := OmniLight3D.new()
	key.name = "HeroKey"
	key.light_color = Color(0.9, 0.92, 1.0)
	key.light_energy = 0.8
	key.omni_range = 5.0
	key.position = Vector3(0.8, 2.4, 1.6)
	hero.add_child(key)


func _build_tower() -> void:
	_box(TOWER + Vector3(0, 24, 0), Vector3(8, 48, 12), _mat(Color(0.72, 0.64, 0.52), 0.95))
	var block := _mat(Color(0.22, 0.27, 0.29), 0.9)
	_box(TOWER + Vector3(-20, 36, 0), Vector3(32, 72, 30), block)
	_box(TOWER + Vector3(20, 30, 0), Vector3(32, 60, 30), block)
	# His door: one weak bulb.
	_box(TOWER + Vector3(0, 1.1, 6.02), Vector3(1.2, 2.2, 0.05), _mat(Color(0.12, 0.1, 0.08), 0.8))
	var bulb := OmniLight3D.new()
	bulb.light_color = Color(1.0, 0.88, 0.6)
	bulb.light_energy = 1.2
	bulb.omni_range = 5.0
	bulb.position = TOWER + Vector3(0, 2.6, 6.6)
	add_child(bulb)


func _build_people() -> void:
	hero = _figure(StreetFigure.Dress.HERO, StreetFigure.Pose.WALK, START, 0.0)
	hero.name = "Hero"
	# The rich: a guard, a queue of suits at the rope.
	_figure(
		StreetFigure.Dress.GUARD, StreetFigure.Pose.STAND, Vector3(RICH_X + 5.6, 0.24, -86), -90.0
	)
	for k in 3:
		_figure(
			StreetFigure.Dress.SUIT,
			StreetFigure.Pose.STAND,
			Vector3(RICH_X + 3.4, 0.24, -82.5 - k * 1.8),
			180.0
		)
	# The poor: slumped against the wall, a dealer huddle, a fight with an onlooker.
	_figure(
		StreetFigure.Dress.POOR, StreetFigure.Pose.SLUMP, Vector3(POOR_X - 1.0, 0.24, -74), 90.0
	)
	_figure(
		StreetFigure.Dress.POOR, StreetFigure.Pose.SLUMP, Vector3(POOR_X - 1.0, 0.24, -101), 90.0
	)
	for k in 3:
		var a := TAU * k / 3.0
		var at := Vector3(POOR_X - 5.0 + cos(a) * 0.8, 0.24, -89 + sin(a) * 0.8)
		var f := _figure(
			StreetFigure.Dress.POOR if k > 0 else StreetFigure.Dress.MIDDLE,
			StreetFigure.Pose.HUDDLE,
			at,
			0.0
		)
		f.look_at(Vector3(POOR_X - 5.0, 0.24, -89) + Vector3(0, 0, 0.001), Vector3.UP)
	var fighter_a := _figure(
		StreetFigure.Dress.POOR, StreetFigure.Pose.FIGHT, Vector3(POOR_X - 6.0, 0.24, -106), 0.0
	)
	var fighter_b := _figure(
		StreetFigure.Dress.POOR, StreetFigure.Pose.FIGHT, Vector3(POOR_X - 4.8, 0.24, -106.8), 0.0
	)
	fighter_a.fight_target = fighter_b
	fighter_b.fight_target = fighter_a
	fighter_a.look_at(fighter_b.position, Vector3.UP)
	fighter_b.look_at(fighter_a.position, Vector3.UP)
	_figure(
		StreetFigure.Dress.MIDDLE, StreetFigure.Pose.STAND, Vector3(POOR_X - 8.5, 0.24, -104), 120.0
	)
	# Middle-class commuters walking toward the station, heads down.
	for k in 5:
		var x := START.x + (-3.0 if k % 2 == 0 else 3.2)
		var f := _figure(
			StreetFigure.Dress.MIDDLE,
			StreetFigure.Pose.WALK,
			Vector3(x, 0, START.z - 6.0 - k * 10.0),
			180.0
		)
		_commuters.append({"figure": f, "speed": 1.4 + k * 0.1})
	# The suits that will cross his path, waiting at the poor-side kerb.
	for c in CROSSINGS:
		var s := _figure(
			StreetFigure.Dress.SUIT,
			StreetFigure.Pose.WALK,
			Vector3(POOR_X - 2.0, 0, float(c[1])),
			90.0
		)
		_crossers.append(s)
		_crossing_started.append(false)


func _figure(
	dress: StreetFigure.Dress, pose: StreetFigure.Pose, at: Vector3, yaw: float
) -> StreetFigure:
	var f := StreetFigure.new()
	f.dress = dress
	f.pose = pose
	f.position = at
	f.rotation_degrees = Vector3(0, yaw, 0)
	add_child(f)
	return f


func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	add_child(mi)
	return mi


func _mat(c: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	return m
