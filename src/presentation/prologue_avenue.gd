class_name PrologueAvenue
extends Node3D
## PRESENTATION — the walk from Block 31 station to his building (Ticket-15 A.2), laid
## out after Alain's sketch (docs/references/sketch_walk_layout.png):
##
##   left    the metro's last stretch on its viaduct, in front of massive blocks that hide
##           everything behind them
##   then    he comes down the station stairs (+X) and crosses the whole street, through a
##           group of ten crossing the other way to the metro; a car rides past behind him
##   up      he walks the avenue (−Z) on the glowing median, "DO NOT CROSS THE LINE",
##           between the classes, the rundown block on his right; the street is packed
##   corner  at the left corner of his street an argument turns into a fight (a shove, a
##           stagger, the first swing); he turns right (+X) and leaves it behind
##   end     his apartment complex: the beige tower, one weak bulb over the door
##
## Left (−X): the clean, lit Heritage Collection boutique, a guard, a rope line, suits.
## Right (+X): tents, a trash fire, a stall, people slumped, a dealer huddle.
## Commuters stream past both ways; two suits cross his path without looking at him.
## The director drives it with set_walk_progress(0..1) and trigger("car" / "crowd").

## Emitted when a suit crosses in front of him (tests).
signal suit_crossed
## Emitted when the car passes the station crossing (tests).
signal car_passed
## Emitted on the shove that starts the fight (tests).
signal altercation_started

## His route: platform → top of the stairs → foot of the stairs → the curb → across the
## street to the rundown side → up the avenue → round the corner → the cross street → his door.
const PATH: Array[Vector3] = [
	Vector3(408.5, 6.0, -70),
	Vector3(411.0, 6.0, -70),
	Vector3(419.0, 0.24, -70),
	Vector3(421.8, 0.24, -70.8),
	Vector3(437.0, 0.05, -76),
	Vector3(437.0, 0.05, -104),
	Vector3(440.0, 0.05, -111),
	Vector3(452.0, 0.05, -111),
	Vector3(452.0, 0.05, -116.5),
]
## PATH index of the curb he steps off, and where he starts turning the corner.
const CURB := 3
const CORNER := 5

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
const CROSSINGS: Array = [[0.22, -83.3], [0.37, -96.0]]
const CROSS_SPEED := 2.2
## The car: its lane (between the curb and the median), start z and speed.
const CAR_X := 425.5
const CAR_START_Z := -118.0
const CAR_SPEED := 16.0
## The group of ten crossing to the metro.
const CROWD_SIZE := 10
const CROWD_SPEED := 1.7
## The fight at the left corner of his street; the shove comes this far past the corner.
const FIGHT_AT := Vector3(436.4, 0.24, -117.6)
const FIGHT_SHOVE_PAST_CORNER := 3.0

var hero: StreetFigure
var progress: float = 0.0

var _crossers: Array[StreetFigure] = []
var _crossing_started: Array[bool] = []
var _walkers: Array[Dictionary] = []
var _crowd: Array[Dictionary] = []
var _crowd_started: bool = false
var _car: Node3D
var _car_moving: bool = false
var _car_passed: bool = false
var _fighters: Array[StreetFigure] = []
var _fight_t: float = -1.0
var _fight_stage: int = 0
var _fire_light: OmniLight3D
var _t: float = 0.0


## Distance along PATH to point `index`.
static func path_distance(index: int) -> float:
	var d := 0.0
	for i in mini(index, PATH.size() - 1):
		d += PATH[i].distance_to(PATH[i + 1])
	return d


static func walk_length() -> float:
	return path_distance(PATH.size() - 1)


## Walk progress (0..1) at PATH point `index`.
static func progress_at(index: int) -> float:
	return path_distance(index) / walk_length()


## Walk progress at which the fight starts (just as he begins turning the corner).
static func fight_progress() -> float:
	return (path_distance(CORNER) + FIGHT_SHOVE_PAST_CORNER) / walk_length()


func _ready() -> void:
	_build_street()
	_build_station()
	_build_left_side()
	_build_right_side()
	_build_overhead()
	_build_cross_street()
	_build_complex()
	_build_people()
	_build_walkers()
	_build_crowd()
	_build_fight()
	_build_car()
	_build_facades()
	_build_props()
	_build_lights()
	set_walk_progress(0.0)


func _process(delta: float) -> void:
	_t += delta
	if _fire_light != null:
		_fire_light.light_energy = 2.2 + sin(_t * 13.0) * 0.4 + sin(_t * 7.3) * 0.3
	_update_walkers(delta)
	_update_crossers(delta)
	_update_crowd(delta)
	_update_car(delta)
	_update_fight(delta)


## Place him `p` (0..1) of the way along his route, facing where he walks; send the
## crossing suits and start the fight as he passes their marks.
func set_walk_progress(p: float) -> void:
	var was := progress
	progress = clampf(p, 0.0, 1.0)
	if hero != null:
		var total := walk_length()
		var at := _sample(progress * total)
		var ahead := _sample(minf(progress * total + 1.5, total)) - at
		ahead.y = 0.0
		hero.position = at
		if ahead.length() > 0.05:
			hero.rotation.y = lerp_angle(hero.rotation.y, atan2(-ahead.x, -ahead.z), 0.2)
		hero.moving = progress > was + 0.00001 and progress < 0.999
	for i in CROSSINGS.size():
		if not _crossing_started[i] and progress >= float(CROSSINGS[i][0]):
			_crossing_started[i] = true
	if _fight_t < 0.0 and progress >= fight_progress():
		_fight_t = 0.0


## Street events cued by the shot list: "car" rides past the curb, "crowd" crosses.
func trigger(event: String) -> void:
	match event:
		"car":
			_car.visible = true
			_car_moving = true
		"crowd":
			_crowd_started = true


func hero_head() -> Vector3:
	return hero.global_position + Vector3(0, 1.6, 0)


## His facing (yaw only), for a camera that follows him round the corner.
func hero_basis() -> Basis:
	return Basis(Vector3.UP, hero.rotation.y)


## True once every member of the crossing group has climbed to the platform.
func crowd_arrived() -> bool:
	for m in _crowd:
		if int(m["i"]) < (m["points"] as Array).size():
			return false
	return _crowd_started


func _sample(d: float) -> Vector3:
	var rest := d
	for i in PATH.size() - 1:
		var seg := PATH[i].distance_to(PATH[i + 1])
		if rest <= seg or i == PATH.size() - 2:
			return PATH[i].lerp(PATH[i + 1], clampf(rest / maxf(seg, 0.001), 0.0, 1.0))
		rest -= seg
	return PATH[PATH.size() - 1]


## Ground height under x near the station: platform, stairs, sidewalk, road.
func _ground_y(x: float) -> float:
	if x <= PATH[1].x:
		return PATH[1].y
	if x < PATH[2].x:
		return lerpf(PATH[1].y, PATH[2].y, (x - PATH[1].x) / (PATH[2].x - PATH[1].x))
	return 0.24 if x < AVENUE_X - ROAD_HALF else 0.05


## ----- UPDATE --------------------------------------------------------------------------


func _update_walkers(delta: float) -> void:
	for w in _walkers:
		var f: StreetFigure = w["figure"]
		var step := float(w["dir"]) * float(w["speed"]) * delta
		if w["axis"] == "z":
			f.position.z += step
			if f.position.z > float(w["max"]):
				f.position.z = float(w["min"])
			elif f.position.z < float(w["min"]):
				f.position.z = float(w["max"])
		else:
			f.position.x += step
			if f.position.x > float(w["max"]):
				f.position.x = float(w["min"])
			elif f.position.x < float(w["min"]):
				f.position.x = float(w["max"])


func _update_crossers(delta: float) -> void:
	for i in _crossers.size():
		if not _crossing_started[i]:
			continue
		var s := _crossers[i]
		if s.position.x > RICH_X + 2.0:
			s.position.x -= CROSS_SPEED * delta
			if s.position.x <= AVENUE_X and not s.has_meta("crossed"):
				s.set_meta("crossed", true)
				suit_crossed.emit()


func _update_crowd(delta: float) -> void:
	if not _crowd_started:
		return
	for m in _crowd:
		var f: StreetFigure = m["figure"]
		var points: Array = m["points"]
		m["delay"] = float(m["delay"]) - delta
		if float(m["delay"]) > 0.0 or int(m["i"]) >= points.size():
			continue
		f.moving = true
		var target: Vector3 = points[int(m["i"])]
		var flat := Vector3(f.position.x, 0, f.position.z)
		var to := Vector3(target.x, 0, target.z) - flat
		var step := CROWD_SPEED * delta
		if to.length() <= step:
			flat = Vector3(target.x, 0, target.z)
			m["i"] = int(m["i"]) + 1
			if int(m["i"]) >= points.size():
				f.moving = false
		else:
			flat += to.normalized() * step
			f.rotation.y = atan2(-to.x, -to.z)
		f.position = Vector3(flat.x, _ground_y(flat.x), flat.z)


func _update_car(delta: float) -> void:
	if not _car_moving:
		return
	_car.position.z += CAR_SPEED * delta
	if not _car_passed and _car.position.z > PATH[CURB].z:
		_car_passed = true
		car_passed.emit()
	if _car.position.z > AVENUE_START_Z + 25.0:
		_car_moving = false
		_car.visible = false


## The beat: A shoves B, B staggers back, then swings back, and they're fighting.
func _update_fight(delta: float) -> void:
	if _fight_t < 0.0:
		return
	_fight_t += delta
	var a := _fighters[0]
	var b := _fighters[1]
	if _fight_stage == 0:
		_fight_stage = 1
		a.shove()
		altercation_started.emit()
	elif _fight_stage == 1 and _fight_t > 0.12:
		_fight_stage = 2
		b.stagger(a.position)
	elif _fight_stage == 2 and _fight_t > 1.0:
		_fight_stage = 3
		b.set_pose(StreetFigure.Pose.FIGHT)
		a.set_pose(StreetFigure.Pose.FIGHT)


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
	# Rundown floors: dark window bands, a few lit ones, rusted AC units.
	var dark := _mat(Color(0.05, 0.05, 0.06), 0.9)
	var lit := _mat(Color(0.9, 0.7, 0.35), 0.6)
	lit.emission_enabled = true
	lit.emission = Color(0.9, 0.62, 0.3)
	lit.emission_energy_multiplier = 0.8
	var rust := _mat(Color(0.32, 0.22, 0.16), 0.9)
	for floor_i in 12:
		var y := 4.0 + floor_i * 3.4
		for k in 3:
			var z := -66.0 - k * 13.0 - (floor_i % 4) * 2.5
			_box(Vector3(POOR_X - 0.35, y - 1.1, z), Vector3(0.7, 0.6, 0.9), rust)
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
	# The Focus+ stall: a counter under a striped awning.
	_box(Vector3(POOR_X - 2.2, 0.75, -81), Vector3(1.2, 1.0, 2.6), _mat(Color(0.3, 0.26, 0.2), 0.9))
	var awning := _mat(Color(0.2, 0.7, 0.75), 0.7)
	_box(Vector3(POOR_X - 2.6, 2.5, -81), Vector3(2.2, 0.08, 3.0), awning)
	var neons: Array = [
		[-68.0, 5.0, Color(0.9, 0.2, 0.6), "ROOMS · HOURLY"],
		[-81.0, 3.2, Color(0.2, 0.84, 0.9), "FOCUS+"],
		[-90.0, 8.5, Color(0.95, 0.8, 0.2), "PAWN · CASH · LEASES"],
		[-96.0, 5.0, Color(0.2, 0.84, 0.9), "FOCUS+ CHEAP"],
		[-75.0, 12.0, Color(0.9, 0.2, 0.6), "CLINIC 24H"],
	]
	for spec in neons:
		var neon := Label3D.new()
		neon.text = spec[3]
		neon.font_size = 96
		neon.pixel_size = 0.018
		neon.modulate = spec[2]
		neon.rotation_degrees = Vector3(0, -90, 0)
		neon.position = Vector3(POOR_X - 0.2, float(spec[1]), float(spec[0]))
		add_child(neon)
	var bag := _mat(Color(0.05, 0.05, 0.05), 0.4)
	for k in 5:
		_box(Vector3(POOR_X - 1.2, 0.5, -63 - k * 8.0), Vector3(0.6, 0.5, 0.5), bag)


## Cramped overhead: cables and laundry lines strung across the avenue.
func _build_overhead() -> void:
	var cable := _mat(Color(0.04, 0.04, 0.04), 0.6)
	var z := AVENUE_START_Z - 3.0
	var k := 0
	while z > AVENUE_END_Z:
		var y := 9.0 + float(k % 3) * 1.6
		var wire := _box(
			Vector3(AVENUE_X + 2, y, z), Vector3(POOR_X - RICH_X + 4, 0.04, 0.04), cable
		)
		wire.rotation.y = 0.08 * float((k % 3) - 1)
		z -= 5.5
		k += 1
	var cloth: Array[Color] = [Color(0.7, 0.2, 0.2), Color(0.8, 0.8, 0.7), Color(0.2, 0.3, 0.6)]
	for i in 9:
		var hang := _mat(cloth[i % 3], 0.95)
		_box(Vector3(POOR_X - 1.0 - i * 0.7, 8.4, -71.0), Vector3(0.5, 0.7, 0.03), hang)


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
	var door := _mat(Color(0.12, 0.1, 0.08), 0.8)
	_box(COMPLEX + Vector3(0, 1.1, 12.04), Vector3(1.4, 2.2, 0.05), door)
	var bulb := OmniLight3D.new()
	bulb.light_color = Color(1.0, 0.88, 0.6)
	bulb.light_energy = 1.4
	bulb.omni_range = 6.0
	bulb.position = COMPLEX + Vector3(0, 2.8, 12.8)
	add_child(bulb)


## Him, and the people who stay put: the queue, the guard, the slumped, the huddle.
func _build_people() -> void:
	hero = _figure(StreetFigure.Dress.HERO, StreetFigure.Pose.WALK, PATH[0], -90.0)
	hero.name = "Hero"
	hero.anim_speed = 1.6  # he walks briskly (2.3 m/s)
	var guard_at := Vector3(RICH_X + 5.6, 0.24, -94)
	_figure(StreetFigure.Dress.GUARD, StreetFigure.Pose.STAND, guard_at, -90.0)
	for k in 5:
		var at := Vector3(RICH_X + 3.4, 0.24, -89.0 - k * 1.5)
		_figure(StreetFigure.Dress.SUIT, StreetFigure.Pose.STAND, at, 180.0)
	var poor := StreetFigure.Dress.POOR
	for z in [-64.0, -73.0, -84.0, -97.0, -101.0]:
		_figure(poor, StreetFigure.Pose.SLUMP, Vector3(POOR_X - 0.9, 0.24, z), 90.0)
	for k in 4:
		var a := TAU * k / 4.0
		var at := Vector3(POOR_X - 5.0 + cos(a) * 0.8, 0.24, -89 + sin(a) * 0.8)
		var dress := StreetFigure.Dress.POOR if k > 0 else StreetFigure.Dress.MIDDLE
		var f := _figure(dress, StreetFigure.Pose.HUDDLE, at, 0.0)
		f.look_at(Vector3(POOR_X - 5.0, 0.24, -89.001), Vector3.UP)
	# Warming at the fire; the stall's vendor and his customers.
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var at := Vector3(POOR_X - 6.5 + cos(a) * 1.1, 0.24, -78 + sin(a) * 1.1)
		var f := _figure(poor, StreetFigure.Pose.STAND, at, 0.0)
		f.look_at(Vector3(POOR_X - 6.5, 0.24, -78.001), Vector3.UP)
	_figure(poor, StreetFigure.Pose.HUDDLE, Vector3(POOR_X - 1.3, 0.24, -81), 90.0)
	for z in [-80.2, -81.8]:
		var at := Vector3(POOR_X - 3.6, 0.24, z)
		_figure(StreetFigure.Dress.MIDDLE, StreetFigure.Pose.STAND, at, -90.0)
	for c in CROSSINGS:
		var at := Vector3(POOR_X - 2.0, 0, float(c[1]))
		_crossers.append(_figure(StreetFigure.Dress.SUIT, StreetFigure.Pose.WALK, at, 90.0))
		_crossing_started.append(false)
	# By his door: someone asleep against the wall, two smoking.
	_figure(poor, StreetFigure.Pose.SLUMP, COMPLEX + Vector3(-5, 0.24, 12.6), 180.0)
	_figure(
		StreetFigure.Dress.MIDDLE, StreetFigure.Pose.STAND, COMPLEX + Vector3(4, 0.24, 13), 150.0
	)
	_figure(poor, StreetFigure.Pose.STAND, COMPLEX + Vector3(4.8, 0.24, 13.6), -60.0)


## The stream: commuters both ways on each sidewalk, along the median, and in his street.
## [axis, lane, dir, count, dress cycle, min, max]
func _build_walkers() -> void:
	var suit := StreetFigure.Dress.SUIT
	var mid := StreetFigure.Dress.MIDDLE
	var poor := StreetFigure.Dress.POOR
	var lanes: Array = [
		["z", RICH_X + 7.6, 1.0, 5, [suit, mid]],
		["z", RICH_X + 8.6, -1.0, 5, [mid, suit, suit]],
		["z", POOR_X - 9.0, 1.0, 6, [poor, mid, poor]],
		["z", POOR_X - 8.1, -1.0, 6, [mid, poor]],
		["z", AVENUE_X - 1.6, 1.0, 5, [mid]],
		["z", AVENUE_X + 1.6, -1.0, 5, [mid, poor]],
		["x", CROSS_Z + 2.6, 1.0, 4, [mid, poor]],
		["x", -115.0, -1.0, 4, [poor, mid]],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for lane in lanes:
		var along_z: bool = lane[0] == "z"
		var lo := AVENUE_END_Z - 8.0 if along_z else AVENUE_X + 8.0
		var hi := AVENUE_START_Z if along_z else 470.0
		var count := int(lane[3])
		var dresses: Array = lane[4]
		var dir := float(lane[2])
		for k in count:
			var along := lerpf(lo, hi, (k + rng.randf_range(0.1, 0.9)) / count)
			# Sidewalk lanes stand on the kerb height; road lanes on the asphalt.
			var on_road := not along_z or absf(float(lane[1]) - AVENUE_X) < ROAD_HALF
			var y := 0.05 if on_road else 0.24
			var at := (
				Vector3(float(lane[1]), y, along) if along_z else Vector3(along, y, float(lane[1]))
			)
			var yaw := (0.0 if dir < 0 else 180.0) if along_z else (90.0 if dir < 0 else -90.0)
			var f := _figure(dresses[k % dresses.size()], StreetFigure.Pose.WALK, at, yaw)
			var axis := "z" if along_z else "x"
			var speed := rng.randf_range(1.2, 1.7)
			_walkers.append(
				{"figure": f, "axis": axis, "dir": dir, "speed": speed, "min": lo, "max": hi}
			)


## The group of ten waiting across the road; on "crowd" they cross to the metro around
## him, up the stairs, onto the platform.
func _build_crowd() -> void:
	var dresses := [StreetFigure.Dress.MIDDLE, StreetFigure.Dress.POOR, StreetFigure.Dress.MIDDLE]
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	for k in CROWD_SIZE:
		# Two clusters either side of his line to the median, so they pass around him.
		var north := k % 2 == 0
		var z := rng.randf_range(-68.6, -64.5) if north else rng.randf_range(-82.0, -78.2)
		var at := Vector3(rng.randf_range(431.5, 435.5), 0.05, z)
		var f := _figure(dresses[k % 3], StreetFigure.Pose.WALK, at, 90.0)
		f.moving = false
		var lane_z := -70.0 + clampf((z + 70.0) * 0.25, -1.2, 1.2)
		var points: Array = [
			Vector3(PATH[CURB].x + 0.6, 0, z),
			Vector3(PATH[2].x, 0, lane_z),
			Vector3(PATH[1].x, 0, lane_z),
			Vector3(PLATFORM.x - rng.randf_range(0.5, 2.0), 0, lane_z + rng.randf_range(-6, 6)),
		]
		_crowd.append({"figure": f, "points": points, "i": 0, "delay": rng.randf_range(0, 0.9)})


## Two men squared up at the left corner of his street, arguing until the shove.
func _build_fight() -> void:
	var a := _figure(StreetFigure.Dress.POOR, StreetFigure.Pose.ARGUE, FIGHT_AT, 0.0)
	var b_at := FIGHT_AT + Vector3(1.0, 0, -0.3)
	var b := _figure(StreetFigure.Dress.MIDDLE, StreetFigure.Pose.ARGUE, b_at, 0.0)
	a.look_at(b.position, Vector3.UP)
	b.look_at(a.position, Vector3.UP)
	a.fight_target = b
	b.fight_target = a
	_fighters = [a, b]
	# The corner store they spilled out of: a buzzing sign and a hard white light.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.95, 0.95, 1.0)
	lamp.light_energy = 3.0
	lamp.omni_range = 8.0
	lamp.position = FIGHT_AT + Vector3(0.5, 3.6, 1.2)
	add_child(lamp)
	var sign := Label3D.new()
	sign.text = "LIQUOR · 24H"
	sign.font_size = 96
	sign.pixel_size = 0.014
	sign.modulate = Color(0.95, 0.25, 0.2)
	sign.position = FIGHT_AT + Vector3(0.5, 3.4, -1.3)
	add_child(sign)
	# Onlookers turning to watch.
	for offset in [Vector3(-0.5, 0, -1.1), Vector3(1.9, 0, 1.3)]:
		var f := _figure(StreetFigure.Dress.POOR, StreetFigure.Pose.STAND, FIGHT_AT + offset, 0.0)
		f.look_at(FIGHT_AT + Vector3(0.5, 0, -0.15), Vector3.UP)


## Real facades (the Downtown City kit) over the street-facing faces of the massing
## boxes: the rundown block in worn red brick, the boutique block in metal and glass,
## his complex and its neighbours in concrete trim. The boxes stay behind as mass.
func _build_facades() -> void:
	var kit := CityKit.new()
	var brick := CityKit.Style.BRICK
	var concrete := CityKit.Style.CONCRETE
	# The rundown block: the avenue face and its corner onto the cross street.
	kit.facade(Vector3(POOR_X, 0, -103), Vector3.LEFT, 21, 14, brick, 31)
	kit.facade(Vector3(POOR_X + 18, 0, -103), Vector3.FORWARD, 9, 14, brick, 32)
	# The boutique block: its shop window (modules 2–7) stays the lit glass.
	kit.facade(
		Vector3(RICH_X, 0, -84), Vector3.RIGHT, 12, 5, CityKit.Style.METAL, 33, [2, 3, 4, 5, 6, 7]
	)
	# His complex (its door in module 3) and the blocks either side.
	kit.facade(COMPLEX + Vector3(-7, 0, 12), Vector3.BACK, 7, 16, concrete, 34, [3])
	kit.facade(COMPLEX + Vector3(-35, 0, 11), Vector3.BACK, 14, 22, brick, 35)
	kit.facade(COMPLEX + Vector3(7, 0, 11), Vector3.BACK, 14, 18, concrete, 36)
	kit.build(self)


## Real props (Poly Haven, Quaternius cars; CC0) dressing the street. Missing packs skip.
func _build_props() -> void:
	var ph := CityKit.polyhaven("exterior_aircon_unit")
	# The rundown block: rusted AC units up the facade, roller shutters with graffiti over
	# the dead ground-floor shops, a utility box, pipes by the corner.
	for k in 9:
		var at := Vector3(POOR_X - 0.2, 5.5 + (k % 3) * 6.0, -66.0 - k * 4.3)
		CityKit.prop(ph, self, at, -90.0)
	for z in [-63.5, -84.0, -95.5]:
		CityKit.prop(
			CityKit.polyhaven("rollershutter_window_03"),
			self,
			Vector3(POOR_X - 0.05, 0.6, z),
			-90.0
		)
	CityKit.prop(
		CityKit.polyhaven("rollershutter_window_01"), self, Vector3(POOR_X - 0.1, 0.4, -70.5), -90.0
	)
	for z in [-72.0, -93.0]:
		CityKit.prop(
			CityKit.polyhaven("utility_box_02"), self, Vector3(POOR_X - 0.3, 0.24, z), -90.0
		)
	for y in [2.0, 4.0]:
		CityKit.prop(
			CityKit.polyhaven("modular_industrial_pipes_01"),
			self,
			Vector3(POOR_X - 0.15, y, -101.5),
			-90.0
		)
	# Street clutter: barriers at the dead end, rims and cigarette packs in the gutter.
	for x in [426.0, 428.0, 430.0, 432.0]:
		CityKit.prop(
			CityKit.polyhaven("concrete_road_barrier"), self, Vector3(x, 0.05, -118.5), 0.0
		)
	for at in [Vector3(441.5, 0.24, -67), Vector3(446.2, 0.24, -98.5), Vector3(439, 0.05, -112)]:
		CityKit.prop(CityKit.polyhaven("rusted_wheel_rim_02"), self, at + Vector3(0, 0.17, 0), 30.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 14:
		var at := Vector3(rng.randf_range(438.5, 447.5), 0.24, rng.randf_range(-104, -62))
		var pack := CityKit.prop(
			CityKit.polyhaven("cigarette_pack"), self, at, rng.randf_range(0, 360)
		)
		if pack != null:
			pack.rotation_degrees.x = 90.0  # dropped, lying flat
	# Parked on the rich side; one dumped in his street.
	CityKit.prop(CityKit.car("SportsCar"), self, Vector3(423.2, 0.05, -86), 180.0)
	CityKit.prop(CityKit.car("SUV"), self, Vector3(423.2, 0.05, -101), 180.0)
	CityKit.prop(CityKit.car("NormalCar2"), self, Vector3(470, 0.05, -108.6), 95.0)
	# Fab (CC-BY / free): the noodle kiosk at the dead end of his street, neon signs on
	# the rundown block, a police cruiser outside the boutique, a rooftop rig, and the
	# skyline over everything: a backdrop, the corporate mega tower, flying traffic.
	var fab := "res://assets/third_party/fab/"
	CityKit.prop(
		fab + "noodle_kiosk/cyberpunk_noodle_kiosk_environment_prop.glb",
		self,
		Vector3(478, 0.05, -112),
		-90.0
	)
	for at in [Vector3(POOR_X - 0.6, 3.2, -75), Vector3(POOR_X - 0.6, 3.6, -99)]:
		CityKit.prop(fab + "neon_signs/neon_signs.glb", self, at, -90.0)
	CityKit.prop(
		fab + "rooftop_1/rooftop_1_hd_jfg_roblox_showcase_prop.glb",
		self,
		Vector3(458, 47.8, -72),
		0.0
	)
	CityKit.prop(
		fab + "scifi_buildings_bg/sci_fi_buildings_modular_background.glb",
		self,
		Vector3(440, 117, -330),
		0.0,
		0.0
	)
	var tower := CityKit.prop(
		fab + "mega_tower/cyberpunk_skyscraper_3d_model.glb",
		self,
		Vector3(500, 100, -230),
		20.0,
		0.0
	)
	if tower != null:
		tower.scale = Vector3.ONE * 200.0
	var traffic := FlyingTraffic.new()
	traffic.name = "Traffic"
	add_child(traffic)
	traffic.add_lane(Vector3(372, 36, -128), Vector3(520, 36, -128), 26.0, 3, 1)
	traffic.add_lane(Vector3(520, 48, -150), Vector3(372, 48, -150), 34.0, 3, 2)
	# The boutique's entrance: a marble bust on a plinth, gilt frames either side of the
	# window. Heritage, on display.
	var plinth := _mat(Color(0.12, 0.11, 0.1), 0.3)
	_box(Vector3(RICH_X + 1.2, 0.74, -87), Vector3(0.5, 1.0, 0.5), plinth)
	CityKit.prop(CityKit.polyhaven("marble_bust_01"), self, Vector3(RICH_X + 1.2, 1.24, -87), 90.0)
	for z in [-86.6, -101.4]:
		var frame := CityKit.polyhaven("fancy_picture_frame_01")
		CityKit.prop(frame, self, Vector3(RICH_X + 0.1, 2.4, z), 90.0)


## The car that rides past him at the curb: a boxy cab, headlights, tail lights.
func _build_car() -> void:
	_car = Node3D.new()
	_car.name = "Car"
	# Waiting at the dead end until cued (visible from the start, so it pre-loads).
	_car.position = Vector3(CAR_X, 0.0, CAR_START_Z)
	add_child(_car)
	# A real taxi if the car pack is installed; a box cab otherwise.
	if CityKit.prop(CityKit.car("Taxi"), _car, Vector3.ZERO) == null:
		var paint := _mat(Color(0.75, 0.6, 0.15), 0.4)
		_box_in(_car, Vector3(0, 0.6, 0), Vector3(1.9, 0.75, 4.4), paint)
		var cab := _mat(Color(0.05, 0.06, 0.08), 0.1)
		_box_in(_car, Vector3(0, 1.22, -0.2), Vector3(1.7, 0.55, 2.3), cab)
	var head := _mat(Color(1, 1, 0.9), 0.3)
	head.emission_enabled = true
	head.emission = Color(1, 0.97, 0.85)
	head.emission_energy_multiplier = 4.0
	var tail := _mat(Color(0.8, 0.05, 0.05), 0.3)
	tail.emission_enabled = true
	tail.emission = Color(0.9, 0.05, 0.05)
	tail.emission_energy_multiplier = 2.5
	for side in [-0.7, 0.7]:
		_box_in(_car, Vector3(side, 0.7, 2.21), Vector3(0.35, 0.15, 0.04), head)
		_box_in(_car, Vector3(side, 0.75, -2.21), Vector3(0.35, 0.12, 0.04), tail)
	var beam := OmniLight3D.new()
	beam.light_color = Color(1, 0.95, 0.85)
	beam.light_energy = 3.0
	beam.omni_range = 9.0
	beam.position = Vector3(0, 1.0, 4.0)
	_car.add_child(beam)


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
	for at in [Vector3(440, 5.0, CROSS_Z + 2), Vector3(462, 5.0, CROSS_Z - 3)]:
		var cross := OmniLight3D.new()
		cross.light_color = Color(1.0, 0.62, 0.25)
		cross.light_energy = 1.4
		cross.omni_range = 12.0
		cross.position = at
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
	return m
