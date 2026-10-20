class_name PrologueAvenue
extends Node3D
## PRESENTATION — the walk from Block 31 station to his building (Ticket-15 A.2), laid
## out after Alain's sketch (docs/references/sketch_walk_layout.png):
##
##   left    the metro's last stretch on its viaduct, in front of massive blocks that hide
##           everything behind them
##   then    he comes down the station stairs (+X) to the road and onto the median
##   up      he walks the avenue (−Z) on the glowing median, "DO NOT CROSS THE LINE",
##           between the classes, the rundown block on his right
##   corner  he turns right (+X) into the cross street
##   end     his apartment complex: the beige tower, one weak bulb over the door
##
## Left (−X): the clean, lit Heritage Collection boutique, a guard, a rope line, suits.
## Right (+X): tents, a trash fire, people slumped, a dealer huddle, two men fighting.
## Middle-class commuters pass; two suits cross his path without looking at him.
## The director drives it with set_walk_progress(0..1); everything else animates itself.

## Emitted when a suit crosses in front of him (tests).
signal suit_crossed

## His route: platform → top of the stairs → foot of the stairs → the median → the end
## of the avenue → round the corner → along the cross street → his door.
const PATH: Array[Vector3] = [
	Vector3(408.5, 6.0, -70),
	Vector3(411.0, 6.0, -70),
	Vector3(419.0, 0.24, -70),
	Vector3(430.0, 0.05, -74),
	Vector3(430.0, 0.05, -103),
	Vector3(433.5, 0.05, -109.5),
	Vector3(440.0, 0.05, -111),
	Vector3(452.0, 0.05, -111),
	Vector3(452.0, 0.05, -116.5),
]

const AVENUE_X := 430.0
const AVENUE_START_Z := -60.0
const AVENUE_END_Z := -106.0
const ROAD_HALF := 8.0
const RICH_X := 412.0
const POOR_X := 448.0
const CROSS_Z := -111.0
## His complex: the beige tower across the cross street, its door on the +Z face.
const COMPLEX := Vector3(452, 0, -130)
## The station platform beside the viaduct (top at the carriage floor, y 6).
const PLATFORM := Vector3(408, 5.5, -70)
## Crossing suits: [walk progress that sends them, z where they cross].
const CROSSINGS: Array = [[0.18, -82.0], [0.35, -96.0]]
const CROSS_SPEED := 2.2

var hero: StreetFigure
var progress: float = 0.0

var _lengths: PackedFloat32Array = PackedFloat32Array()
var _total: float = 0.0
var _crossers: Array[StreetFigure] = []
var _crossing_started: Array[bool] = []
var _commuters: Array[Dictionary] = []
var _fire_light: OmniLight3D
var _t: float = 0.0


func _ready() -> void:
	for i in PATH.size() - 1:
		var seg := PATH[i].distance_to(PATH[i + 1])
		_lengths.append(seg)
		_total += seg
	_build_street()
	_build_station()
	_build_left_side()
	_build_right_side()
	_build_cross_street()
	_build_complex()
	_build_people()
	_build_lights()
	set_walk_progress(0.0)


func _process(delta: float) -> void:
	_t += delta
	if _fire_light != null:
		_fire_light.light_energy = 2.2 + sin(_t * 13.0) * 0.4 + sin(_t * 7.3) * 0.3
	for c in _commuters:
		var f: StreetFigure = c["figure"]
		f.position.z += float(c["speed"]) * delta
		if f.position.z > AVENUE_START_Z:
			f.position.z = AVENUE_END_Z
	for i in _crossers.size():
		if not _crossing_started[i]:
			continue
		var s := _crossers[i]
		if s.position.x > RICH_X + 2.0:
			s.position.x -= CROSS_SPEED * delta
			if s.position.x <= AVENUE_X and not s.has_meta("crossed"):
				s.set_meta("crossed", true)
				suit_crossed.emit()


## His route's length in metres.
func walk_length() -> float:
	return _total


## Place him `p` (0..1) of the way along his route, facing where he walks; send the
## crossing suits as he passes their marks.
func set_walk_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	if hero != null:
		var at := _sample(progress * _total)
		var ahead := _sample(minf(progress * _total + 1.5, _total)) - at
		ahead.y = 0.0
		hero.position = at
		if ahead.length() > 0.05:
			hero.rotation.y = lerp_angle(hero.rotation.y, atan2(-ahead.x, -ahead.z), 0.2)
		hero.moving = progress < 0.999
	for i in CROSSINGS.size():
		if not _crossing_started[i] and progress >= float(CROSSINGS[i][0]):
			_crossing_started[i] = true


func hero_head() -> Vector3:
	return hero.global_position + Vector3(0, 1.6, 0)


## His facing (yaw only), for a camera that follows him round the corner.
func hero_basis() -> Basis:
	return Basis(Vector3.UP, hero.rotation.y)


func _sample(d: float) -> Vector3:
	var rest := d
	for i in _lengths.size():
		if rest <= _lengths[i] or i == _lengths.size() - 1:
			return PATH[i].lerp(PATH[i + 1], clampf(rest / maxf(_lengths[i], 0.001), 0.0, 1.0))
		rest -= _lengths[i]
	return PATH[PATH.size() - 1]


## ----- BUILD ---------------------------------------------------------------------------


func _build_street() -> void:
	var z_mid := (AVENUE_START_Z + AVENUE_END_Z) * 0.5
	var length := AVENUE_START_Z - AVENUE_END_Z
	var asphalt := _mat(Color(0.08, 0.08, 0.09), 0.6)
	_box(Vector3(AVENUE_X, 0.02, z_mid - 7), Vector3(ROAD_HALF * 2, 0.04, length + 14), asphalt)
	var rich := _mat(Color(0.62, 0.6, 0.56), 0.4)
	_box(Vector3(RICH_X + 5, 0.12, z_mid), Vector3(10, 0.24, length), rich)
	var poor := _mat(Color(0.16, 0.15, 0.14), 1.0)
	_box(Vector3(POOR_X - 5, 0.12, z_mid), Vector3(10, 0.24, length), poor)
	# The median he walks: glowing, the warning repeated along it.
	var line := _mat(Color(0.95, 0.42, 0.08), 0.5)
	line.emission_enabled = true
	line.emission = Color(0.95, 0.42, 0.08)
	line.emission_energy_multiplier = 1.6
	_box(Vector3(AVENUE_X, 0.05, z_mid), Vector3(0.25, 0.02, length), line)
	var z := AVENUE_START_Z - 8.0
	while z > AVENUE_END_Z + 2.0:
		for side in [-1.0, 1.0]:
			var text := Label3D.new()
			text.text = "DO NOT CROSS THE LINE"
			text.font_size = 64
			text.pixel_size = 0.008
			text.modulate = Color(0.95, 0.5, 0.15, 0.85)
			text.rotation_degrees = Vector3(-90, 90 if side > 0 else -90, 0)
			text.position = Vector3(AVENUE_X + side * 1.6, 0.06, z)
			add_child(text)
		z -= 12.0


## The end of the line: a platform beside the viaduct and the stairs down to the road.
func _build_station() -> void:
	var concrete := _mat(Color(0.3, 0.3, 0.31), 0.9)
	_box(PLATFORM, Vector3(6, 1.0, 24), concrete)
	for z in [-60.0, -70.0, -80.0]:
		_box(Vector3(PLATFORM.x + 1.5, 2.5, z), Vector3(0.6, 5.0, 0.6), concrete)
	var steps := 12
	for k in steps:
		var top := PATH[1].lerp(PATH[2], (k + 1.0) / steps)
		_box(Vector3(top.x, top.y * 0.5, top.z), Vector3(0.75, maxf(top.y, 0.2), 3.0), concrete)
	var rail := _mat(Color(0.5, 0.5, 0.5), 0.4)
	for side in [-1.0, 1.0]:
		var a := PATH[1] + Vector3(0, 1.0, side * 1.5)
		var b := PATH[2] + Vector3(0, 1.0, side * 1.5)
		var bar := _box((a + b) * 0.5, Vector3(a.distance_to(b), 0.06, 0.06), rail)
		bar.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
		bar.rotate_object_local(Vector3.UP, PI * 0.5)
	# The canopy over the platform, a grimy light, the station name.
	_box(PLATFORM + Vector3(0, 4.2, 0), Vector3(7, 0.2, 24), _mat(Color(0.2, 0.2, 0.22), 0.8))
	var tube := OmniLight3D.new()
	tube.light_color = Color(0.8, 1.0, 0.9)
	tube.light_energy = 1.6
	tube.omni_range = 10.0
	tube.position = PLATFORM + Vector3(0, 3.6, 0)
	add_child(tube)
	var sign := Label3D.new()
	sign.text = "BLOCK 31"
	sign.font_size = 96
	sign.pixel_size = 0.012
	sign.modulate = Color(0.2, 0.84, 0.9)
	sign.position = PLATFORM + Vector3(3.1, 3.4, 4.0)
	sign.rotation_degrees = Vector3(0, 90, 0)
	add_child(sign)


## Left: the massive blocks behind the viaduct hide everything beyond; the boutique sits
## in a low, clean block past the platform.
func _build_left_side() -> void:
	var mass := _mat(Color(0.2, 0.25, 0.27), 0.85)
	_box(Vector3(382, 75, -112), Vector3(26, 150, 104), mass)
	_box(Vector3(406, 32, -134), Vector3(20, 64, 40), mass)
	_box(Vector3(RICH_X - 3, 8, -96), Vector3(6, 16, 24), _mat(Color(0.74, 0.70, 0.62), 0.5))
	var glass := _mat(Color(0.98, 0.84, 0.55), 0.2)
	glass.emission_enabled = true
	glass.emission = Color(0.98, 0.82, 0.5)
	glass.emission_energy_multiplier = 1.8
	_box(Vector3(RICH_X + 0.05, 2.8, -94), Vector3(0.2, 4.6, 12), glass)
	var sign := Label3D.new()
	sign.text = "HERITAGE COLLECTION"
	sign.font_size = 96
	sign.pixel_size = 0.02
	sign.modulate = Color(0.2, 0.16, 0.1)
	sign.rotation_degrees = Vector3(0, 90, 0)
	sign.position = Vector3(RICH_X + 0.3, 6.0, -94)
	add_child(sign)
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.86, 0.62)
	warm.light_energy = 4.0
	warm.omni_range = 16.0
	warm.position = Vector3(RICH_X + 3, 4, -94)
	add_child(warm)
	var brass := _mat(Color(0.85, 0.66, 0.25), 0.3)
	for k in 4:
		_box(Vector3(RICH_X + 4.5, 0.6, -90 - k * 2.6), Vector3(0.12, 1.0, 0.12), brass)
	var rope := _mat(Color(0.5, 0.06, 0.08), 0.6)
	_box(Vector3(RICH_X + 4.5, 0.95, -93.9), Vector3(0.05, 0.05, 7.8), rope)


## Right: the rundown block all the way to the corner.
func _build_right_side() -> void:
	_box(Vector3(POOR_X + 9, 22, -82), Vector3(18, 44, 42), _mat(Color(0.2, 0.21, 0.2), 1.0))
	# Rundown floors: dark window bands, a few lit ones.
	var dark := _mat(Color(0.05, 0.05, 0.06), 0.9)
	var lit := _mat(Color(0.9, 0.7, 0.35), 0.6)
	lit.emission_enabled = true
	lit.emission = Color(0.9, 0.62, 0.3)
	lit.emission_energy_multiplier = 0.8
	for floor_i in 12:
		var y := 4.0 + floor_i * 3.4
		_box(Vector3(POOR_X - 0.02, y, -82), Vector3(0.05, 1.2, 40), dark)
		_box(Vector3(POOR_X + 9, y, -103.02), Vector3(16, 1.2, 0.05), dark)
		if floor_i % 3 == 1:
			_box(Vector3(POOR_X - 0.04, y, -70 - floor_i * 1.7), Vector3(0.05, 1.1, 2.2), lit)
	var canvas := _mat(Color(0.28, 0.3, 0.26), 1.0)
	for z in [-66.0, -86.0, -99.0]:
		var tent := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(2.4, 1.5, 2.8)
		tent.mesh = prism
		tent.material_override = canvas
		tent.position = Vector3(POOR_X - 2.5, 0.99, z)
		add_child(tent)
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
	var neons: Array = [
		[-68.0, Color(0.9, 0.2, 0.6), "ROOMS · HOURLY"],
		[-96.0, Color(0.2, 0.84, 0.9), "FOCUS+ CHEAP"],
	]
	for spec in neons:
		var neon := Label3D.new()
		neon.text = spec[2]
		neon.font_size = 96
		neon.pixel_size = 0.018
		neon.modulate = spec[1]
		neon.rotation_degrees = Vector3(0, -90, 0)
		neon.position = Vector3(POOR_X - 0.2, 5.0, spec[0])
		add_child(neon)
	var bag := _mat(Color(0.05, 0.05, 0.05), 0.4)
	for k in 5:
		_box(Vector3(POOR_X - 1.2, 0.5, -63 - k * 8.0), Vector3(0.6, 0.5, 0.5), bag)


## The corner and the cross street he turns into; blocks framing his complex.
func _build_cross_street() -> void:
	var asphalt := _mat(Color(0.08, 0.08, 0.09), 0.6)
	_box(Vector3(458, 0.015, CROSS_Z), Vector3(56, 0.04, 10), asphalt)
	var pavement := _mat(Color(0.16, 0.15, 0.14), 1.0)
	_box(Vector3(458, 0.12, -117.5), Vector3(56, 0.24, 3), pavement)
	var block := _mat(Color(0.22, 0.27, 0.29), 0.9)
	_box(COMPLEX + Vector3(-21, 34, -4), Vector3(28, 68, 30), block)
	_box(COMPLEX + Vector3(21, 28, -4), Vector3(28, 56, 30), block)


## His complex, after the Soviet beige tower ref: beige concrete, a weak bulb at the door.
func _build_complex() -> void:
	_box(COMPLEX + Vector3(0, 24, 0), Vector3(14, 48, 24), _mat(Color(0.72, 0.64, 0.52), 0.95))
	var dark := _mat(Color(0.18, 0.16, 0.14), 0.9)
	for floor_i in 13:
		_box(COMPLEX + Vector3(0, 3.0 + floor_i * 3.4, 12.03), Vector3(10, 1.0, 0.05), dark)
	var door := _mat(Color(0.12, 0.1, 0.08), 0.8)
	_box(COMPLEX + Vector3(0, 1.1, 12.04), Vector3(1.4, 2.2, 0.05), door)
	var bulb := OmniLight3D.new()
	bulb.light_color = Color(1.0, 0.88, 0.6)
	bulb.light_energy = 1.4
	bulb.omni_range = 6.0
	bulb.position = COMPLEX + Vector3(0, 2.8, 12.8)
	add_child(bulb)


func _build_people() -> void:
	hero = _figure(StreetFigure.Dress.HERO, StreetFigure.Pose.WALK, PATH[0], -90.0)
	hero.name = "Hero"
	_figure(
		StreetFigure.Dress.GUARD, StreetFigure.Pose.STAND, Vector3(RICH_X + 5.6, 0.24, -94), -90.0
	)
	for k in 3:
		var at := Vector3(RICH_X + 3.4, 0.24, -90.5 - k * 1.8)
		_figure(StreetFigure.Dress.SUIT, StreetFigure.Pose.STAND, at, 180.0)
	for z in [-73.0, -97.0]:
		_figure(
			StreetFigure.Dress.POOR, StreetFigure.Pose.SLUMP, Vector3(POOR_X - 1.0, 0.24, z), 90.0
		)
	for k in 3:
		var a := TAU * k / 3.0
		var at := Vector3(POOR_X - 5.0 + cos(a) * 0.8, 0.24, -89 + sin(a) * 0.8)
		var dress := StreetFigure.Dress.POOR if k > 0 else StreetFigure.Dress.MIDDLE
		var f := _figure(dress, StreetFigure.Pose.HUDDLE, at, 0.0)
		f.look_at(Vector3(POOR_X - 5.0, 0.24, -89.001), Vector3.UP)
	# The fight, at the corner where he turns.
	var fight := StreetFigure.Pose.FIGHT
	var poor := StreetFigure.Dress.POOR
	var fighter_a := _figure(poor, fight, Vector3(POOR_X - 6.0, 0.24, -101.5), 0.0)
	var fighter_b := _figure(poor, fight, Vector3(POOR_X - 4.8, 0.24, -102.3), 0.0)
	fighter_a.fight_target = fighter_b
	fighter_b.fight_target = fighter_a
	fighter_a.look_at(fighter_b.position, Vector3.UP)
	fighter_b.look_at(fighter_a.position, Vector3.UP)
	_figure(
		StreetFigure.Dress.MIDDLE,
		StreetFigure.Pose.STAND,
		Vector3(POOR_X - 8.5, 0.24, -99.5),
		120.0
	)
	for k in 4:
		var x := AVENUE_X + (-3.0 if k % 2 == 0 else 3.2)
		var at := Vector3(x, 0, AVENUE_START_Z - 8.0 - k * 10.0)
		var f := _figure(StreetFigure.Dress.MIDDLE, StreetFigure.Pose.WALK, at, 180.0)
		_commuters.append({"figure": f, "speed": 1.4 + k * 0.1})
	for c in CROSSINGS:
		var at := Vector3(POOR_X - 2.0, 0, float(c[1]))
		_crossers.append(_figure(StreetFigure.Dress.SUIT, StreetFigure.Pose.WALK, at, 90.0))
		_crossing_started.append(false)
	# Someone asleep against the wall beside his door.
	_figure(poor, StreetFigure.Pose.SLUMP, COMPLEX + Vector3(-5, 0.24, 12.6), 180.0)


## Street light tells the split: bright, even, white on the left; sparse sodium (one dead)
## on the right. A soft key rides with him so the walk reads.
func _build_lights() -> void:
	var z := AVENUE_START_Z - 4.0
	var k := 0
	while z > AVENUE_END_Z:
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
			var sodium := OmniLight3D.new()
			sodium.light_color = Color(1.0, 0.62, 0.25)
			sodium.light_energy = 1.3
			sodium.omni_range = 9.0
			sodium.position = Vector3(POOR_X - 6.0, 5.0, z)
			add_child(sodium)
		_box(
			Vector3(POOR_X - 6.0, 2.5, z),
			Vector3(0.12, 5.0, 0.12),
			_mat(Color(0.25, 0.22, 0.2), 0.8)
		)
		z -= 10.0
		k += 1
	var cross := OmniLight3D.new()
	cross.light_color = Color(1.0, 0.62, 0.25)
	cross.light_energy = 1.2
	cross.omni_range = 12.0
	cross.position = Vector3(442, 5.0, CROSS_Z + 2)
	add_child(cross)
	var key := OmniLight3D.new()
	key.name = "HeroKey"
	key.light_color = Color(0.9, 0.92, 1.0)
	key.light_energy = 0.8
	key.omni_range = 5.0
	key.position = Vector3(0.8, 2.4, 1.6)
	hero.add_child(key)


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
