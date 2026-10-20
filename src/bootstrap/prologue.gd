class_name Prologue
extends Node3D
## COMPOSITION ROOT + DIRECTOR — the prologue film, Phase A previs (Ticket-15).
##
## scenes/prologue.tscn runs this. It builds a greybox world along the maglev route and
## plays PrologueScript.shots(): train distance, camera mode, gaze moments, subtitles.
## Only what the camera sees is built. Phases B–D replace the greybox; the director
## and the shot data stay.
##
## Hold E (or Esc) for SKIP_HOLD seconds to skip. Either way it ends in the game.

signal shot_started(index: int, shot_name: String, mode: PrologueScript.Mode)
signal gaze_started(target: String)
signal finished

const GAME_SCENE_PATH := "res://scenes/workspace.tscn"
const SKIP_HOLD := 1.0
const CARRIAGES := 4
const CARRIAGE_LENGTH := 18.0
const CARRIAGE_GAP := 1.2
## He sits in the second carriage, right-hand window.
const SEAT_CARRIAGE := 1
const SEAT_OFFSET := Vector3(1.1, 1.25, 0.0)
## The carriage's window band, centred at head height (seated and standing).
const WINDOW_Y := 1.35
const WINDOW_H := 0.9
## Ground area kept free of generated towers for the avenue walk.
const AVENUE_CLEAR := Rect2(Vector2(366, -155), Vector2(136, 120))
## Third-person follow: behind and over his right shoulder.
const WALK_CAM_OFFSET := Vector3(1.3, 2.3, 4.8)

var shot_index: int = -1
var shot_time: float = 0.0
var train_distance: float = 0.0
var is_finished: bool = false

var _shots: Array[Dictionary] = []
var _curve: Curve3D
var _camera: Camera3D
var _overlay: PrologueOverlay
var _world_env: WorldEnvironment
var _env_town: Environment
var _env_city: Environment
var _carriages: Array[Node3D] = []
## His carriage's window glass: hidden in first person (the camera sits behind it).
var _seat_glass: Array[MeshInstance3D] = []
var _gaze_targets: Dictionary = {}
var _avenue: PrologueAvenue
## His carriage's interior (aisle shot only: from inside it would hide the window view).
var _interior: Array[Node3D] = []
var _gaze_fired: bool = false
var _events_fired: int = 0
var _skip_held: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	InputActionData.register()  # this scene runs before the game registers them
	_rng.seed = 731  # the greybox city is the same every run
	_shots = PrologueScript.shots()
	_build_route()
	_build_environment()
	_build_ground()
	_build_track()
	_build_town()
	_build_tunnel()
	_build_city()
	_build_billboards()
	_build_colossus()
	_avenue = PrologueAvenue.new()
	_avenue.name = "Avenue"
	add_child(_avenue)
	_build_train()
	_camera = Camera3D.new()
	_camera.name = "FilmCamera"
	_camera.far = 900.0
	add_child(_camera)
	_camera.make_current()
	_overlay = PrologueOverlay.new()
	_overlay.name = "Overlay"
	add_child(_overlay)
	_start_shot(0)


func _process(delta: float) -> void:
	if is_finished:
		return
	_update_skip(delta)
	if is_finished:
		return
	shot_time += delta
	var shot := _shots[shot_index]
	if shot_time >= float(shot["dur"]):
		if shot_index + 1 >= _shots.size():
			finish()
			return
		_start_shot(shot_index + 1)
		shot = _shots[shot_index]
	var u := clampf(shot_time / float(shot["dur"]), 0.0, 1.0)
	var span: Array = shot["d"]
	train_distance = lerpf(float(span[0]), float(span[1]), u)
	_place_train()
	_update_camera(shot, u)
	_update_lines(shot)
	_update_events(shot)
	_overlay.set_title(clampf((u - 0.3) / 0.4, 0.0, 1.0) if shot.get("title", false) else 0.0)


## Skip or end: straight into the game (the lease signing is Phase E).
func finish() -> void:
	if is_finished:
		return
	is_finished = true
	finished.emit()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


## The track's full length (the train stops at its end).
func route_length() -> float:
	return _curve.get_baked_length()


func gaze_target_position(target: String) -> Vector3:
	var n: Node3D = _gaze_targets.get(target)
	return n.global_position if n != null else Vector3.ZERO


## ----- DIRECTION ---------------------------------------------------------------------


func _start_shot(index: int) -> void:
	shot_index = index
	shot_time = 0.0
	_gaze_fired = false
	_events_fired = 0
	var shot := _shots[index]
	var mode: PrologueScript.Mode = shot["mode"]
	_camera.fov = float(shot.get("fov", 60.0))
	_overlay.set_view(_view_for(mode))
	for pane in _seat_glass:
		pane.visible = mode != PrologueScript.Mode.FP
	for n in _interior:
		n.visible = mode == PrologueScript.Mode.FP_AISLE
	_world_env.environment = _env_town if index < 2 else _env_city
	shot_started.emit(index, str(shot["name"]), mode)


func _view_for(mode: PrologueScript.Mode) -> PrologueOverlay.View:
	match mode:
		PrologueScript.Mode.FP:
			return PrologueOverlay.View.WINDOW
		PrologueScript.Mode.FP_AISLE:
			return PrologueOverlay.View.BARE
	return PrologueOverlay.View.LETTERBOX


func _update_camera(shot: Dictionary, u: float) -> void:
	var mode: PrologueScript.Mode = shot["mode"]
	if shot.has("w"):
		var w: Array = shot["w"]
		_avenue.set_walk_progress(lerpf(float(w[0]), float(w[1]), u))
	match mode:
		PrologueScript.Mode.FP_AISLE:
			# Standing in the aisle, looking down the packed carriage.
			var car := _carriages[SEAT_CARRIAGE].global_transform
			var sway := Vector3(sin(shot_time * 1.4) * 0.04, sin(shot_time * 2.3) * 0.02, 0)
			_camera.global_position = car * (Vector3(0.35, 1.65, 7.2) + sway)
			_camera.look_at(car * Vector3(0.0, 1.45, -8.0), car.basis.y)
		PrologueScript.Mode.WALK_FOLLOW:
			# Behind his shoulder, turning with him round the corner.
			var head := _avenue.hero_head()
			var facing := _avenue.hero_basis()
			var target := head + facing * WALK_CAM_OFFSET
			var w := 1.0 - exp(-get_process_delta_time() * 4.0)
			_camera.global_position = (
				target if shot_time < 0.05 else _camera.global_position.lerp(target, w)
			)
			_camera.look_at(head + facing * Vector3(0, -0.2, -4.0), Vector3.UP)
		PrologueScript.Mode.EXT_FIXED:
			_camera.global_position = shot["cam"]
			var look: Vector3 = shot.get("look", _carriages[0].global_position)
			_camera.look_at(look, Vector3.UP)
		PrologueScript.Mode.EXT_FOLLOW:
			var car := _carriages[0]
			_camera.global_position = car.global_transform * (shot["cam"] as Vector3)
			_camera.look_at(car.global_position, Vector3.UP)
		PrologueScript.Mode.FP:
			_update_first_person(shot, u)


func _update_first_person(shot: Dictionary, u: float) -> void:
	var seat := _carriages[SEAT_CARRIAGE].global_transform
	var eye := seat * SEAT_OFFSET
	var right := seat.basis.x.normalized()
	var forward := -seat.basis.z.normalized()
	# Resting gaze: out of the right-hand window, a little ahead and down.
	var rest := Basis.looking_at(right + forward * 0.25 - Vector3.UP * 0.12, Vector3.UP)
	var basis := rest
	var phone := 0.0
	var gaze: Dictionary = shot.get("gaze", {})
	if not gaze.is_empty():
		var w := _gaze_weight(u, float(gaze["from"]), float(gaze["to"]))
		var target := str(gaze["target"])
		if w > 0.0 and not _gaze_fired:
			_gaze_fired = true
			gaze_started.emit(target)
		var look_dir: Vector3
		if target == "phone":
			look_dir = forward * 0.35 + right * 0.2 - Vector3.UP * 1.0
			phone = w
		else:
			look_dir = gaze_target_position(target) - eye
		var gaze_basis := Basis.looking_at(look_dir.normalized(), Vector3.UP)
		basis = Basis(rest.get_rotation_quaternion().slerp(gaze_basis.get_rotation_quaternion(), w))
	_camera.global_transform = Transform3D(basis, eye)
	_overlay.set_phone(phone, PrologueScript.LEASE_TEXT)


## Ease in over the first 20% of the window, hold, ease out over the last 20%.
func _gaze_weight(u: float, from: float, to: float) -> float:
	if u <= from or u >= to:
		return 0.0
	var span := to - from
	var ramp := span * 0.2
	var w := minf((u - from) / ramp, (to - u) / ramp)
	w = clampf(w, 0.0, 1.0)
	return w * w * (3.0 - 2.0 * w)


func _update_lines(shot: Dictionary) -> void:
	var text := ""
	for line in shot.get("lines", []):
		if shot_time >= float(line[0]) and shot_time < float(line[0]) + 4.5:
			text = str(line[1])
	_overlay.set_subtitle(text)


## A shot's street events ([time, name], in time order) cue the avenue: the car, the crowd.
func _update_events(shot: Dictionary) -> void:
	var events: Array = shot.get("events", [])
	while _events_fired < events.size() and shot_time >= float(events[_events_fired][0]):
		_avenue.trigger(str(events[_events_fired][1]))
		_events_fired += 1


func _update_skip(delta: float) -> void:
	var holding := (
		Input.is_action_pressed(InputActionData.ACTION_INTERACT)
		or Input.is_action_pressed(&"ui_cancel")
	)
	_skip_held = _skip_held + delta if holding else 0.0
	_overlay.set_skip_progress(clampf(_skip_held / SKIP_HOLD, 0.0, 1.0))
	if _skip_held >= SKIP_HOLD:
		finish()


## ----- ROUTE + TRAIN -------------------------------------------------------------------


func _build_route() -> void:
	_curve = Curve3D.new()
	var pts := PrologueScript.ROUTE
	for i in pts.size():
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, pts.size() - 1)]
		var tangent := (next - prev) / 6.0
		_curve.add_point(pts[i], -tangent, tangent)
	_curve.bake_interval = 1.0


## Position and frame (right, up, back) on the track at distance `d`.
func _frame_at(d: float) -> Transform3D:
	var length := _curve.get_baked_length()
	var p := _curve.sample_baked(clampf(d, 0.0, length), true)
	var ahead := _curve.sample_baked(clampf(d + 2.0, 0.0, length), true)
	if ahead.distance_to(p) < 0.01:
		ahead = p + (p - _curve.sample_baked(clampf(d - 2.0, 0.0, length), true))
	var forward := (ahead - p).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	return Transform3D(Basis(right, up, -forward), p)


## Outside: the Transrapid look, sleek white, blue and orange stripes, a rounded nose.
## The future as advertised. Inside his carriage: the future as lived (_build_interior).
func _build_train() -> void:
	var body := _mat(Color(0.92, 0.93, 0.94), 0.35)
	var blue := _mat(Color(0.12, 0.28, 0.62), 0.4)
	var orange := _mat(Color(0.92, 0.48, 0.16), 0.4)
	var glass := _mat(Color(0.95, 0.88, 0.62), 0.3)
	glass.emission_enabled = true
	glass.emission = Color(0.95, 0.85, 0.55)
	glass.emission_energy_multiplier = 0.8
	for i in CARRIAGES:
		var car := Node3D.new()
		car.name = "Carriage_%d" % i
		add_child(car)
		_box_in(car, Vector3(0, 1.7, 0), Vector3(3.2, 3.4, CARRIAGE_LENGTH), body)
		for side in [-1.0, 1.0]:
			var pane := _box_in(
				car,
				Vector3(side * 1.62, WINDOW_Y, 0),
				Vector3(0.05, WINDOW_H, CARRIAGE_LENGTH - 2.0),
				glass
			)
			if i == SEAT_CARRIAGE:
				_seat_glass.append(pane)
			_box_in(car, Vector3(side * 1.61, 0.7, 0), Vector3(0.04, 0.16, CARRIAGE_LENGTH), blue)
			_box_in(car, Vector3(side * 1.61, 0.5, 0), Vector3(0.04, 0.08, CARRIAGE_LENGTH), orange)
		if i == 0:
			_build_nose(car, body)
		if i == SEAT_CARRIAGE:
			_build_interior(car)
		_carriages.append(car)
	_place_train()


func _build_nose(car: Node3D, body: Material) -> void:
	var nose := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.6
	sphere.height = 3.4
	nose.mesh = sphere
	nose.material_override = body
	nose.scale = Vector3(1.0, 1.0, 2.0)
	nose.position = Vector3(0, 1.7, -CARRIAGE_LENGTH * 0.5)
	car.add_child(nose)
	var screen := _mat(Color(0.05, 0.07, 0.1), 0.15)
	_box_in(car, Vector3(0, 2.35, -CARRIAGE_LENGTH * 0.5 - 2.2), Vector3(2.0, 0.7, 0.9), screen)


## The grimy subway interior (ref sonat-samir-cp-sub2.jpg): poles, ads over the windows,
## graffiti and litter, a fluorescent strip, a neon warning, the packed standing crowd.
## Rendered from inside (front faces culled), visible only during the aisle shot.
func _build_interior(car: Node3D) -> void:
	var shell := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.1, 3.3, CARRIAGE_LENGTH - 0.2)
	shell.mesh = box
	var wall := _mat(Color(0.34, 0.36, 0.33), 0.9)
	wall.cull_mode = BaseMaterial3D.CULL_FRONT
	shell.material_override = wall
	shell.position = Vector3(0, 1.7, 0)
	car.add_child(shell)
	_interior.append(shell)
	var parts := Node3D.new()
	parts.name = "Interior"
	car.add_child(parts)
	_interior.append(parts)
	var steel := _mat(Color(0.7, 0.72, 0.74), 0.25)
	steel.metallic = 0.8
	var seat := _mat(Color(0.42, 0.46, 0.44), 0.7)
	var half := CARRIAGE_LENGTH * 0.5
	var z := -half + 1.5
	while z < half - 1.0:
		for side in [-1.0, 1.0]:
			_box_in(parts, Vector3(side * 1.2, 0.45, z), Vector3(0.6, 0.12, 1.4), seat)
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.03
		cyl.height = 3.2
		pole.mesh = cyl
		pole.material_override = steel
		pole.position = Vector3(0.0, 1.6, z)
		parts.add_child(pole)
		z += 2.6
	# The windows from inside: night glass at head height, between the poles.
	var night := _mat(Color(0.06, 0.09, 0.12), 0.1)
	night.emission_enabled = true
	night.emission = Color(0.1, 0.16, 0.2)
	night.emission_energy_multiplier = 0.6
	z = -half + 1.5
	while z < half - 1.0:
		for side in [-1.0, 1.0]:
			_box_in(
				parts, Vector3(side * 1.5, WINDOW_Y, z + 1.3), Vector3(0.03, WINDOW_H, 2.0), night
			)
		z += 2.6
	var colors := [Color(0.9, 0.2, 0.6), Color(0.2, 0.84, 0.9), Color(0.95, 0.8, 0.2)]
	var k := 0
	z = -half + 1.2
	while z < half - 1.0:
		for side in [-1.0, 1.0]:
			var ad := _mat(colors[k % 3], 0.5)
			ad.emission_enabled = true
			ad.emission = colors[k % 3]
			ad.emission_energy_multiplier = 0.9
			_box_in(parts, Vector3(side * 1.48, 2.85, z), Vector3(0.04, 0.4, 1.8), ad)
			k += 1
		z += 2.2
	var tube := _mat(Color(0.95, 0.97, 1.0), 0.5)
	tube.emission_enabled = true
	tube.emission = Color(0.9, 0.95, 1.0)
	tube.emission_energy_multiplier = 2.0
	_box_in(parts, Vector3(0, 3.28, 0), Vector3(0.2, 0.04, CARRIAGE_LENGTH - 1.0), tube)
	var light := OmniLight3D.new()
	light.light_color = Color(0.85, 0.92, 1.0)
	light.light_energy = 1.6
	light.omni_range = 12.0
	light.position = Vector3(0, 3.0, 0)
	parts.add_child(light)
	var graffiti := _mat(Color(0.95, 0.85, 0.2), 0.8)
	graffiti.emission_enabled = true
	graffiti.emission = Color(0.6, 0.5, 0.1)
	for g in 6:
		var stroke := _box_in(
			parts,
			Vector3(_rng.randf_range(-0.8, 0.8), 0.06, _rng.randf_range(-half + 1, half - 1)),
			Vector3(_rng.randf_range(0.6, 1.4), 0.01, 0.06),
			graffiti
		)
		stroke.rotation_degrees.y = _rng.randf_range(0, 180)
	for g in 8:
		_box_in(
			parts,
			Vector3(_rng.randf_range(-1.1, 1.1), 0.08, _rng.randf_range(-half + 1, half - 1)),
			Vector3(0.12, 0.08, 0.16),
			_mat(Color(0.85, 0.85, 0.8), 0.9)
		)
	var warning := Label3D.new()
	warning.text = "DO NOT\nCROSS\nTHE LINE"
	warning.font_size = 64
	warning.pixel_size = 0.006
	warning.modulate = Color(1.0, 0.55, 0.12)
	warning.position = Vector3(0, 2.0, -half + 0.15)
	parts.add_child(warning)
	# The packed crowd standing in the aisle, and a few on the seats.
	var dresses := [StreetFigure.Dress.MIDDLE, StreetFigure.Dress.POOR, StreetFigure.Dress.MIDDLE]
	for c in 7:
		var f := StreetFigure.new()
		f.dress = dresses[c % 3]
		f.pose = StreetFigure.Pose.STAND
		f.position = Vector3(_rng.randf_range(-0.5, 0.5), 0.0, -half + 2.0 + c * 1.9)
		f.rotation_degrees.y = _rng.randf_range(0, 360)
		parts.add_child(f)
	for c in 4:
		var f := StreetFigure.new()
		f.dress = dresses[(c + 1) % 3]
		f.pose = StreetFigure.Pose.SLUMP
		f.position = Vector3(1.15 if c % 2 == 0 else -1.15, 0.5, -half + 3.0 + c * 3.5)
		f.rotation_degrees.y = -90.0 if c % 2 == 0 else 90.0
		parts.add_child(f)


func _place_train() -> void:
	for i in _carriages.size():
		var d := train_distance - i * (CARRIAGE_LENGTH + CARRIAGE_GAP) - CARRIAGE_LENGTH * 0.5
		_carriages[i].global_transform = _frame_at(d)


## ----- WORLD (greybox) ------------------------------------------------------------------


func _build_environment() -> void:
	_env_city = _environment(
		Color(0.04, 0.07, 0.09), Color(0.42, 0.26, 0.18), Color(0.18, 0.24, 0.26), 0.0045
	)
	_env_town = _environment(
		Color(0.36, 0.30, 0.24), Color(0.78, 0.52, 0.30), Color(0.55, 0.42, 0.30), 0.0012
	)
	_world_env = WorldEnvironment.new()
	_world_env.environment = _env_town
	add_child(_world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "LowSun"
	sun.light_color = Color(1.0, 0.72, 0.45)
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-12, -60, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _environment(top: Color, horizon: Color, fog: Color, density: float) -> Environment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.darkened(0.4)
	sky_mat.ground_bottom_color = top.darkened(0.5)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = density
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	return env


func _build_ground() -> void:
	var city := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 900)
	city.mesh = plane
	city.material_override = _mat(Color(0.10, 0.11, 0.12), 0.95)
	city.position = Vector3(80, 0, 0)
	add_child(city)


func _build_track() -> void:
	var beam_mat := _mat(Color(0.30, 0.31, 0.32), 0.8)
	var length := _curve.get_baked_length()
	var d := 0.0
	while d < length:
		var f := _frame_at(d)
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.6, 0.3, 6.4)
		seg.mesh = box
		seg.material_override = beam_mat
		add_child(seg)
		seg.global_transform = Transform3D(f.basis, f.origin - f.basis.y * 0.35)
		# T-beam: the web under the plate the train wraps around.
		var web := MeshInstance3D.new()
		var web_box := BoxMesh.new()
		web_box.size = Vector3(1.2, 1.6, 6.4)
		web.mesh = web_box
		web.material_override = beam_mat
		add_child(web)
		web.global_transform = Transform3D(f.basis, f.origin - f.basis.y * 1.3)
		if fmod(d, 30.0) < 6.0:
			var pylon := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.8
			cyl.bottom_radius = 1.1
			cyl.height = f.origin.y
			pylon.mesh = cyl
			pylon.material_override = beam_mat
			pylon.position = Vector3(f.origin.x, f.origin.y * 0.5 - 0.6, f.origin.z)
			add_child(pylon)
		d += 6.0


## The town he leaves: a dust plain, a dead mall, low houses, one fenced stone.
func _build_town() -> void:
	var dust := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(420, 360)
	dust.mesh = plane
	dust.material_override = _mat(Color(0.48, 0.34, 0.22), 1.0)
	dust.position = Vector3(-520, 0.05, 0)
	add_child(dust)
	var concrete := _mat(Color(0.55, 0.47, 0.38), 0.9)
	_box(Vector3(-600, 4, -40), Vector3(90, 8, 30), concrete)  # the dead mall
	# The station platform.
	_box(Vector3(-610, 1.5, 6), Vector3(26, 3, 8), _mat(Color(0.4, 0.37, 0.34), 0.9))
	# Low houses and shuttered lots, densest just beside the line (what the window sees).
	for i in 60:
		var x := _rng.randf_range(-700, -340)
		var z := _rng.randf_range(10, 70) if i % 3 != 0 else _rng.randf_range(-150, 150)
		if absf(z) < 14.0:
			continue
		_box(
			Vector3(x, 2.5, z),
			Vector3(_rng.randf_range(6, 12), 5, _rng.randf_range(6, 10)),
			concrete
		)
	# The fenced stone, a corporate plate bolted to it. Nobody looks.
	var stone_at := Vector3(-585, 0, 22)
	_box(stone_at + Vector3(0, 1.8, 0), Vector3(1.2, 3.6, 0.8), _mat(Color(0.5, 0.49, 0.46), 1.0))
	var fence := _mat(Color(0.2, 0.2, 0.2), 0.6)
	for k in 8:
		var a := TAU * k / 8.0
		_box(stone_at + Vector3(cos(a) * 2.4, 0.7, sin(a) * 2.4), Vector3(0.1, 1.4, 0.1), fence)
	var plate := _mat(Color(0.9, 0.9, 0.92), 0.3)
	plate.emission_enabled = true
	plate.emission = Color(0.2, 0.84, 0.9)
	_box(stone_at + Vector3(0, 2.2, 0.42), Vector3(0.6, 0.3, 0.05), plate)


func _build_tunnel() -> void:
	var rock := _mat(Color(0.08, 0.08, 0.09), 1.0)
	var a := _frame_at(PrologueScript.TUNNEL_START).origin
	var b := _frame_at(PrologueScript.TUNNEL_END).origin
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	_box(mid + Vector3(0, 6.0, 0), Vector3(length, 1.0, 12), rock)
	_box(mid + Vector3(0, -3.0, 0), Vector3(length, 1.0, 12), rock)
	_box(mid + Vector3(0, 1.5, 6.0), Vector3(length, 10, 1.0), rock)
	_box(mid + Vector3(0, 1.5, -6.0), Vector3(length, 10, 1.0), rock)


## Teal-grey monoliths along the route, plus a taller skyline ring behind them.
func _build_city() -> void:
	var length := _curve.get_baked_length()
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var colossus := _frame_at(_colossus_distance()).origin
	var sightlines := _sightlines()
	var boards: Array[Vector3] = []
	for i in PrologueScript.BILLBOARDS.size():
		boards.append(_billboard_anchor(i))
	var d := PrologueScript.TUNNEL_END + 10.0
	while d < length:
		var f := _frame_at(d)
		for side in [-1.0, 1.0]:
			for ring in [0, 1]:
				if _rng.randf() > (0.8 if ring == 0 else 0.5):
					continue
				var lateral := _rng.randf_range(16, 60) if ring == 0 else _rng.randf_range(80, 200)
				var at: Vector3 = f.origin + f.basis.x * side * lateral
				at.y = 0.0
				if (
					_curve.get_closest_point(at + Vector3(0, f.origin.y, 0)).distance_to(
						at + Vector3(0, f.origin.y, 0)
					)
					< 13.0
				):
					continue
				if at.distance_to(Vector3(colossus.x, 0, colossus.z)) < 42.0:
					continue
				if AVENUE_CLEAR.has_point(Vector2(at.x, at.z)):
					continue
				if _blocks_view(at, sightlines, boards):
					continue
				var low := d > PrologueScript.LOW_BLOCKS_START
				var h := _rng.randf_range(12, 34) if low else _rng.randf_range(40, 170)
				if ring == 1:
					h *= 1.4
				var size := Vector3(_rng.randf_range(10, 26), h, _rng.randf_range(10, 26))
				transforms.append(
					Transform3D(
						Basis().rotated(Vector3.UP, _rng.randf_range(0, 0.3)).scaled(size),
						at + Vector3(0, h * 0.5, 0)
					)
				)
				var shade := _rng.randf_range(0.0, 1.0)
				colors.append(Color(0.18, 0.23, 0.25).lerp(Color(0.37, 0.45, 0.47), shade))
		d += 12.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var towers := MultiMeshInstance3D.new()
	towers.name = "Monoliths"
	towers.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	towers.material_override = mat
	add_child(towers)


func _build_billboards() -> void:
	for i in PrologueScript.BILLBOARDS.size():
		var spec: Array = PrologueScript.BILLBOARDS[i]
		var f := _frame_at(float(spec[0]))
		var side := float(spec[1])
		var board := Node3D.new()
		board.name = "Billboard_%d" % i
		add_child(board)
		board.global_position = _billboard_anchor(i)
		var toward := f.origin
		toward.y = board.global_position.y
		board.look_at(toward, Vector3.UP)
		var panel := MeshInstance3D.new()
		var quad := QuadMesh.new()
		# The campaign is the gaze moment: it gets the biggest board.
		var scale := 1.8 if i == PrologueScript.CAMPAIGN_BILLBOARD else 1.3
		quad.size = Vector2(26, 10) * scale
		panel.mesh = quad
		var glow := _mat(spec[4], 0.4)
		glow.emission_enabled = true
		glow.emission = spec[4]
		glow.emission_energy_multiplier = 1.6
		glow.cull_mode = BaseMaterial3D.CULL_DISABLED
		panel.material_override = glow
		panel.rotation_degrees = Vector3(0, 180, 0)  # face along +Z → toward the track
		board.add_child(panel)
		var label := Label3D.new()
		label.text = str(spec[3])
		label.font_size = 160
		label.pixel_size = 0.01 * scale
		label.modulate = Color.WHITE
		label.outline_size = 12
		label.position = Vector3(0, 0, -0.2)
		label.rotation_degrees = Vector3(0, 180, 0)
		board.add_child(label)
		if i == PrologueScript.CAMPAIGN_BILLBOARD:
			_gaze_targets["campaign"] = board


## Where billboard `i` hangs: beside the track, at its authored height.
func _billboard_anchor(i: int) -> Vector3:
	var spec: Array = PrologueScript.BILLBOARDS[i]
	var f := _frame_at(float(spec[0]))
	var side := float(spec[1])
	return f.origin + f.basis.x * side * 20.0 + Vector3(0, float(spec[2]) - f.origin.y + 10.0, 0)


## Every external shot's camera→target line (ground plane), plus each gaze line from the
## track to its billboard. Towers on these lines would hide the subject of a shot.
func _sightlines() -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	for shot in _shots:
		if shot["mode"] == PrologueScript.Mode.EXT_FIXED and shot.has("look"):
			var cam: Vector3 = shot["cam"]
			var look: Vector3 = shot["look"]
			lines.append(PackedVector2Array([Vector2(cam.x, cam.z), Vector2(look.x, look.z)]))
	for i in PrologueScript.BILLBOARDS.size():
		var spec: Array = PrologueScript.BILLBOARDS[i]
		var track := _frame_at(float(spec[0]) - 40.0).origin
		var board := _billboard_anchor(i)
		lines.append(PackedVector2Array([Vector2(track.x, track.z), Vector2(board.x, board.z)]))
	return lines


func _blocks_view(
	at: Vector3, sightlines: Array[PackedVector2Array], boards: Array[Vector3]
) -> bool:
	var p := Vector2(at.x, at.z)
	for line in sightlines:
		var c := Geometry2D.get_closest_point_to_segment(p, line[0], line[1])
		if c.distance_to(p) < 22.0:
			return true
	for b in boards:
		if p.distance_to(Vector2(b.x, b.z)) < 20.0:
			return true
	return false


func _colossus_distance() -> float:
	return _curve.get_closest_offset(PrologueScript.ROUTE[8])


func _build_colossus() -> void:
	var d := _colossus_distance()
	var f := _frame_at(d)
	var canal := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(26, 400)
	canal.mesh = plane
	canal.material_override = _mat(Color(0.12, 0.2, 0.24), 0.1)
	add_child(canal)
	canal.global_transform = Transform3D(
		Basis.looking_at(f.basis.x, Vector3.UP), Vector3(f.origin.x, 0.1, f.origin.z)
	)
	var figure := ColossusFigure.new()
	figure.name = "GoldenColossus"
	figure.style = ColossusFigure.Style.GOLD_COPY
	figure.height = 56.0
	figure.stance = 26.0
	add_child(figure)
	# Straddle the track: its legs either side, facing along the line.
	figure.global_transform = Transform3D(f.basis, Vector3(f.origin.x, 0.0, f.origin.z))
	_gaze_targets["colossus"] = figure.head


## ----- HELPERS -----------------------------------------------------------------------


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	return _box_in(self, at, size, mat)


func _box_in(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
