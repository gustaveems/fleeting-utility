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
const SEAT_OFFSET := Vector3(1.1, 1.75, 0.0)
const HIS_TOWER := Vector3(458, 0, -78)

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
var _gaze_fired: bool = false
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
	_build_his_tower()
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
	_overlay.set_title(clampf((u - 0.3) / 0.4, 0.0, 1.0) if shot.get("title", false) else 0.0)


## Skip or end: straight into the game (the lease signing is Phase E).
func finish() -> void:
	if is_finished:
		return
	is_finished = true
	finished.emit()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func gaze_target_position(target: String) -> Vector3:
	var n: Node3D = _gaze_targets.get(target)
	return n.global_position if n != null else Vector3.ZERO


## ----- DIRECTION ---------------------------------------------------------------------


func _start_shot(index: int) -> void:
	shot_index = index
	shot_time = 0.0
	_gaze_fired = false
	var shot := _shots[index]
	var mode: PrologueScript.Mode = shot["mode"]
	_camera.fov = float(shot.get("fov", 60.0))
	_overlay.set_first_person(mode == PrologueScript.Mode.FP)
	for pane in _seat_glass:
		pane.visible = mode != PrologueScript.Mode.FP
	_world_env.environment = _env_town if index < 2 else _env_city
	shot_started.emit(index, str(shot["name"]), mode)


func _update_camera(shot: Dictionary, u: float) -> void:
	var mode: PrologueScript.Mode = shot["mode"]
	match mode:
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


func _build_train() -> void:
	var body := _mat(Color(0.62, 0.64, 0.66), 0.5)
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
				car, Vector3(side * 1.62, 2.0, 0), Vector3(0.05, 0.9, CARRIAGE_LENGTH - 2.0), glass
			)
			if i == SEAT_CARRIAGE:
				_seat_glass.append(pane)
		_carriages.append(car)
	_place_train()


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
		box.size = Vector3(2.6, 0.8, 6.4)
		seg.mesh = box
		seg.material_override = beam_mat
		add_child(seg)
		seg.global_transform = Transform3D(f.basis, f.origin - f.basis.y * 0.6)
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
				if at.distance_to(HIS_TOWER) < 48.0:
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


## His building: a beige sliver wedged between two bigger blocks, by the last station.
func _build_his_tower() -> void:
	var at := HIS_TOWER
	_box(at + Vector3(0, 24, 0), Vector3(8, 48, 12), _mat(Color(0.72, 0.64, 0.52), 0.95))
	var block := _mat(Color(0.22, 0.27, 0.29), 0.9)
	_box(at + Vector3(-20, 36, 0), Vector3(32, 72, 30), block)
	_box(at + Vector3(20, 30, 0), Vector3(32, 60, 30), block)
	_box(Vector3(440, 3.2, -52), Vector3(10, 1, 26), _mat(Color(0.3, 0.3, 0.3), 0.9))  # station


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
