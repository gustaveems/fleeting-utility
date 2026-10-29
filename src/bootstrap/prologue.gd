class_name Prologue
extends Node3D
## COMPOSITION ROOT + DIRECTOR — the prologue film, Phase A previs (Ticket-15).
##
## scenes/prologue.tscn runs this. It builds a greybox world along the maglev route and
## plays PrologueScript.shots(): train distance, camera moves, framed beats, subtitles.
## Fully cinematic: one camera glides from each shot into the next (`blend` seconds)
## unless the shot cuts. Only what the camera sees is built. Phases B–D replace the
## greybox; the director and the shot data stay.
##
## Hold E (or Esc) for SKIP_HOLD seconds to skip. Either way it ends in the game.

signal shot_started(index: int, shot_name: String, mode: PrologueScript.Mode)
signal gaze_started(target: String)
## A subtitle line comes up ("" when it clears): PrologueSound voices it.
signal line_spoken(text: String)
signal finished

const GAME_SCENE_PATH := "res://scenes/workspace.tscn"
const SKIP_HOLD := 1.0
const CARRIAGES := 4
const CARRIAGE_LENGTH := 18.0
const CARRIAGE_GAP := 1.2
## He sits in the second carriage, by the right-hand window (carriage-local).
const SEAT_CARRIAGE := 1
const SEAT_AT := Vector3(1.15, 0.5, 4.6)
## A shot glides in over this long unless it sets `blend` or `cut`.
const DEFAULT_BLEND := 2.0
## Handheld shake inside the metro: metres and radians at full motion_scale.
const SHAKE_MOVE := 0.035
const SHAKE_TURN := 0.018
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
## The film's looks, one Environment per stage (PrologueLook), and the low sun they share.
var _looks: Dictionary = {}
var _sun: DirectionalLight3D
var _carriages: Array[Node3D] = []
## His carriage's window glass: hidden for the interior shot (it would glow in the way).
var _seat_glass: Array[MeshInstance3D] = []
var _gaze_targets: Dictionary = {}
var _avenue: PrologueAvenue
## His carriage's interior: shown for the interior and fly-through shots only.
var _interior: Array[Node3D] = []
var _events_fired: int = 0
var _head_call: HeadCall
var _line_text: String = ""
## Pre-warm: before the film starts the camera looks at each heavy area for a few frames
## behind a black screen, so their textures and shaders load up front instead of
## hitching mid-film: [camera transform, look stage].
var _warmup: Array = []
## The glide into the current shot: where the camera was, and over how long.
var _blend_from: Transform3D
var _blend_fov_from: float = 60.0
var _blend_dur: float = 0.0
## For glides into a train-riding shot: the carriage the start pose rides with, so the
## glide only changes framing and never has to chase the moving train.
var _blend_car: Node3D
## The third-person rig's smoothed position (kept apart from the blended camera).
var _follow_pos: Vector3
var _follow_snap: bool = true
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
	_build_landmarks()
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
	_head_call = HeadCall.new()
	_head_call.name = "HeadCall"
	add_child(_head_call)
	_build_audio()
	_overlay.set_black(true)
	for spot in [
		[Vector3(418, 60, -40), Vector3(440, 0, -100)],  # the avenue from above
		[Vector3(440, 3, -60), Vector3(440, 3, -115)],  # down the street, kiosk end
		[Vector3(-60, 230, 330), Vector3(40, 15, -30)],  # the canyon
		[Vector3(150, 20, 120), Vector3(230, 30, 30)],  # the colossus
		[Vector3(-560, 9, 34), Vector3(-610, 10, 0)],  # the town
	]:
		var xf := Transform3D().looking_at(spot[1] - spot[0], Vector3.UP).translated(spot[0])
		# Every spot under every stage's look: each environment compiles its shaders
		# behind the black, not at its first shot (Phase C's glow hitched there).
		for stage: String in PrologueLook.STAGES:
			_warmup.append([xf, stage])
	_start_shot(0)


func _process(delta: float) -> void:
	if is_finished:
		return
	if not _warmup.is_empty():
		var step: Array = _warmup.pop_front()
		_camera.global_transform = step[0]
		_apply_look(step[1])
		if _warmup.is_empty():
			_apply_look(PrologueLook.stage_for(str(_shots[shot_index]["name"])))
			_overlay.set_black(false)
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
	LeaseSigning.pending = true  # he signs the lease as the game begins
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


## The track's full length (the train stops at its end).
func route_length() -> float:
	return _curve.get_baked_length()


func gaze_target_position(target: String) -> Vector3:
	var n: Node3D = _gaze_targets.get(target)
	return n.global_position if n != null else Vector3.ZERO


## ----- DIRECTION ---------------------------------------------------------------------


func _start_shot(index: int) -> void:
	var previous: Dictionary = _shots[shot_index] if shot_index >= 0 else {}
	shot_index = index
	shot_time = 0.0
	_events_fired = 0
	var shot := _shots[index]
	var mode: PrologueScript.Mode = shot["mode"]
	# Glide from wherever the camera is, unless this shot cuts (or it is the first).
	_blend_from = _camera.global_transform
	_blend_car = null
	if mode == PrologueScript.Mode.EXT_FOLLOW:
		_blend_car = _carriages[int(shot.get("car", 0))]
		_blend_from = _blend_car.global_transform.affine_inverse() * _blend_from
	_blend_fov_from = _camera.fov
	var cut: bool = index == 0 or shot.get("cut", false)
	_blend_dur = 0.0 if cut else float(shot.get("blend", DEFAULT_BLEND))
	if previous.get("mode", -1) != PrologueScript.Mode.WALK_FOLLOW:
		_follow_snap = true
	_overlay.set_view(PrologueOverlay.View.LETTERBOX)
	_overlay.set_phone(0.0)
	for pane in _seat_glass:
		pane.visible = mode != PrologueScript.Mode.INTERIOR
	for n in _interior:
		n.visible = mode == PrologueScript.Mode.INTERIOR or shot.get("interior", false)
	_apply_look(PrologueLook.stage_for(str(shot["name"])))
	shot_started.emit(index, str(shot["name"]), mode)
	if shot.has("gaze"):
		gaze_started.emit(str(shot["gaze"]))
	if shot.get("call", "") == "arrival":
		_head_call.play(NightZeroScript.CALL_ARRIVAL)


func _update_camera(shot: Dictionary, u: float) -> void:
	var mode: PrologueScript.Mode = shot["mode"]
	if shot.has("w"):
		var w: Array = shot["w"]
		_avenue.set_walk_progress(lerpf(float(w[0]), float(w[1]), u))
	# Constant speed through each move: no easing in or out (it read as slow-fast-slow).
	var eased := u
	var fov := float(shot.get("fov", 60.0))
	match mode:
		PrologueScript.Mode.EXT_FIXED:
			_aim(shot["cam"], _look_point(shot, eased), Vector3.UP)
		PrologueScript.Mode.EXT_PATH:
			_aim(_along(shot["cam"], eased), _look_point(shot, eased), Vector3.UP)
		PrologueScript.Mode.EXT_FOLLOW:
			var car := _carriages[int(shot.get("car", 0))].global_transform
			_aim(car * _along(shot["cam"], eased), _look_point(shot, eased), Vector3.UP)
		PrologueScript.Mode.INTERIOR:
			_update_interior(shot, eased)
		PrologueScript.Mode.WALK_FOLLOW:
			# Behind his shoulder, turning with him round the corner.
			var head := _avenue.hero_head()
			var facing := _avenue.hero_basis()
			var target := head + facing * WALK_CAM_OFFSET
			var k := 1.0 - exp(-get_process_delta_time() * 4.0)
			_follow_pos = target if _follow_snap else _follow_pos.lerp(target, k)
			_follow_snap = false
			_aim(_follow_pos, head + facing * Vector3(0, -0.2, -4.0), Vector3.UP)
		PrologueScript.Mode.TOP_TRACK:
			# High over the metro side, sliding along the street with him.
			var z := _avenue.hero.global_position.z
			var cam: Vector3 = shot["cam"]
			var look: Vector3 = shot["look"]
			_aim(Vector3(cam.x, cam.y, z + cam.z), Vector3(look.x, look.y, z + look.z), Vector3.UP)
	_camera.fov = fov
	if shot_time < _blend_dur:
		var t := shot_time / _blend_dur
		t = t * t * (3.0 - 2.0 * t)
		var from := _blend_from
		if _blend_car != null:
			from = _blend_car.global_transform * _blend_from
		_camera.global_transform = from.interpolate_with(_camera.global_transform, t)
		_camera.fov = lerpf(_blend_fov_from, fov, t)


## Handheld inside his carriage: down the packed aisle to him, over his shoulder at the
## phone, shaking with the train (scaled by the reduce-motion setting).
func _update_interior(shot: Dictionary, eased: float) -> void:
	var car := _carriages[SEAT_CARRIAGE].global_transform
	var motion := GameSettings.current().motion_scale
	var t := shot_time
	var jolt := maxf(sin(t * 0.9) - 0.85, 0.0) * 6.0  # the odd hard bump over a joint
	var shake := (
		Vector3(
			sin(t * 13.1) * 0.6 + sin(t * 7.3) * 0.4,
			sin(t * 17.7) * 0.5 + sin(t * 9.1) * 0.5 + jolt,
			sin(t * 5.3) * 0.3
		)
		* SHAKE_MOVE
		* motion
	)
	var eye := car * (_along(shot["cam"], eased) + shake)
	var look := car * _along(shot["look"], eased)
	_aim(eye, look, car.basis.y)
	_camera.rotate_object_local(Vector3.FORWARD, sin(t * 11.3) * SHAKE_TURN * motion)
	_camera.rotate_object_local(Vector3.RIGHT, (sin(t * 8.7) + jolt) * SHAKE_TURN * 0.6 * motion)
	if shot.has("phone"):
		var span: Array = shot["phone"]
		var shown := _gaze_weight(shot_time / float(shot["dur"]), float(span[0]), float(span[1]))
		_overlay.set_phone(shown, PrologueScript.LEASE_TEXT)


func _aim(eye: Vector3, at: Vector3, up: Vector3) -> void:
	_camera.global_position = eye
	if eye.distance_to(at) > 0.01:
		_camera.look_at(at, up)


## A point, or a path of points travelled at `t` (0..1) at constant speed (by distance,
## so short and long segments move alike).
func _along(points: Variant, t: float) -> Vector3:
	if points is Vector3:
		return points
	var path: Array = points
	if path.size() == 1:
		return path[0]
	var total := 0.0
	for i in path.size() - 1:
		total += (path[i] as Vector3).distance_to(path[i + 1])
	var rest := clampf(t, 0.0, 1.0) * total
	for i in path.size() - 1:
		var seg := (path[i] as Vector3).distance_to(path[i + 1])
		if rest <= seg or i == path.size() - 2:
			return (path[i] as Vector3).lerp(path[i + 1], clampf(rest / maxf(seg, 0.001), 0.0, 1.0))
		rest -= seg
	return path[path.size() - 1]


## Where a shot looks: a world point, a path of points, or a named target.
func _look_point(shot: Dictionary, t: float) -> Vector3:
	var look: Variant = shot.get("look", "train")
	if look is String:
		match look:
			"train":
				return _carriages[0].global_position
			"hero":
				return _avenue.hero_head()
		return gaze_target_position(look)
	return _along(look, t)


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
	if text != _line_text:
		_line_text = text
		line_spoken.emit(text)
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
	# The packed crowd standing in the aisle (leaving the camera a lane on the right),
	# and a few on the seats, facing the aisle.
	var dresses := [StreetFigure.Dress.MIDDLE, StreetFigure.Dress.POOR, StreetFigure.Dress.MIDDLE]
	for c in 9:
		var f := StreetFigure.new()
		f.dress = dresses[c % 3]
		f.pose = StreetFigure.Pose.STAND
		f.position = Vector3(_rng.randf_range(-0.65, -0.15), 0.0, -half + 1.6 + c * 1.6)
		f.rotation_degrees.y = _rng.randf_range(0, 360)
		parts.add_child(f)
	for c in 4:
		var f := StreetFigure.new()
		f.dress = dresses[(c + 1) % 3]
		f.pose = StreetFigure.Pose.SLUMP
		f.position = Vector3(1.15 if c % 2 == 0 else -1.15, 0.5, -half + 3.0 + c * 3.5)
		f.rotation_degrees.y = 90.0 if c % 2 == 0 else -90.0
		parts.add_child(f)
	# Him, by the right-hand window, bag in his lap, the lease lighting up his phone.
	var hero := StreetFigure.new()
	hero.name = "SeatedHero"
	hero.dress = StreetFigure.Dress.HERO
	hero.pose = StreetFigure.Pose.SLUMP
	hero.position = SEAT_AT
	hero.rotation_degrees.y = 90.0
	parts.add_child(hero)
	var screen := _mat(Color(0.6, 0.95, 1.0), 0.3)
	screen.emission_enabled = true
	screen.emission = Color(0.2, 0.84, 0.9)
	screen.emission_energy_multiplier = 2.5
	var phone := _box_in(hero, Vector3(0.0, 0.45, -0.38), Vector3(0.08, 0.02, 0.15), screen)
	phone.rotation_degrees.x = 35.0
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.9, 1.0)
	glow.light_energy = 0.6
	glow.omni_range = 1.2
	glow.position = Vector3(0.0, 0.6, -0.4)
	hero.add_child(glow)


func _place_train() -> void:
	for i in _carriages.size():
		var d := train_distance - i * (CARRIAGE_LENGTH + CARRIAGE_GAP) - CARRIAGE_LENGTH * 0.5
		_carriages[i].global_transform = _frame_at(d)


## ----- WORLD (greybox) ------------------------------------------------------------------


func _build_environment() -> void:
	for stage: String in PrologueLook.STAGES:
		_looks[stage] = _environment(PrologueLook.STAGES[stage])
	_world_env = WorldEnvironment.new()
	add_child(_world_env)
	_sun = DirectionalLight3D.new()
	_sun.name = "LowSun"
	_sun.shadow_enabled = true
	add_child(_sun)
	_apply_look("town")


## A stage's sky, fog, glow and grade, and its sun (PrologueLook).
func _apply_look(stage: String) -> void:
	var spec: Dictionary = PrologueLook.STAGES[stage]
	_world_env.environment = _looks[stage]
	_sun.light_color = spec["sun"]
	_sun.light_energy = spec["sun_energy"]
	_sun.rotation_degrees = spec["sun_angle"]


func _environment(spec: Dictionary) -> Environment:
	var top: Color = spec["sky_top"]
	var horizon: Color = spec["sky_horizon"]
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
	if spec.has("ambient_color"):
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = spec["ambient_color"]
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = spec["ambient"]
	env.fog_enabled = true
	env.fog_light_color = spec["fog"]
	env.fog_density = spec["fog_density"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = spec["exposure"]
	# Only what glows past white blooms: the ads, the neon, the lit windows.
	env.glow_enabled = float(spec["glow"]) > 0.0
	env.glow_intensity = spec["glow"]
	env.glow_hdr_threshold = 1.0
	env.glow_bloom = 0.02
	env.adjustment_enabled = true
	env.adjustment_saturation = spec["saturation"]
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


## The town he leaves: the dust plain, the station, one fenced stone (its streets, the dead
## mall, the depot and the leased fields are PrologueCity's).
func _build_town() -> void:
	var dust := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(420, 360)
	dust.mesh = plane
	dust.material_override = _mat(Color(0.48, 0.34, 0.22), 1.0)
	dust.position = Vector3(-520, 0.05, 0)
	add_child(dust)
	# The station platform (the town's streets, mall, depot and fields: PrologueCity).
	_box(Vector3(-610, 1.5, 6), Vector3(26, 3, 8), _mat(Color(0.4, 0.37, 0.34), 0.9))
	# Sodium lamps over it, still burning at dawn (the decay palette's one accent).
	var post := _mat(Color(0.18, 0.17, 0.16), 0.7)
	var glass := _mat(PrologueLook.SODIUM, 0.4)
	glass.emission_enabled = true
	glass.emission = PrologueLook.SODIUM
	glass.emission_energy_multiplier = 3.0
	for x in [-620.0, -610.0, -600.0]:
		_box(Vector3(x, 5.0, 9.0), Vector3(0.25, 4.0, 0.25), post)
		_box(Vector3(x, 7.1, 9.0), Vector3(0.6, 0.25, 0.4), glass)
		var lamp := OmniLight3D.new()
		lamp.light_color = PrologueLook.SODIUM
		lamp.light_energy = 2.5
		lamp.omni_range = 14.0
		lamp.position = Vector3(x, 6.8, 9.0)
		add_child(lamp)
	# The fenced stone, a corporate plate bolted to it. Nobody looks.
	var stone_at := Vector3(-585, 0, 22)
	_box(stone_at + Vector3(0, 1.8, 0), Vector3(1.2, 3.6, 0.8), _mat(Color(0.5, 0.49, 0.46), 1.0))
	# The real chain-link fence around it (Poly Haven, CC0); posts if the pack is missing.
	var fence_scene := CityKit.polyhaven("modular_chainlink_fence")
	if CityKit.prop(fence_scene, self, stone_at + Vector3(2.0, 0, 1.0), 0.0) == null:
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


## The city, district by district (Phase B: PrologueCityPlan, built by PrologueCity). It
## keeps every tall thing off the shots' sightlines and the billboards handed to it.
func _build_city() -> void:
	var city := PrologueCity.new()
	city.name = "City"
	city.curve = _curve
	city.sightlines = _sightlines()
	for i in PrologueScript.BILLBOARDS.size():
		city.boards.append(_billboard_anchor(i))
	city.colossus = _frame_at(_colossus_distance()).origin
	city.avenue_clear = AVENUE_CLEAR
	add_child(city)
	city.build()


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
		var campaign := i == PrologueScript.CAMPAIGN_BILLBOARD
		if campaign:
			# The luxury campaign's image: the valley he'll dream of, sold as heritage.
			panel.material_override = CampaignArt.material(quad.size.x / quad.size.y)
		else:
			var glow := _mat(spec[4], 0.4)
			glow.emission_enabled = true
			glow.emission = spec[4]
			glow.emission_energy_multiplier = PrologueLook.AD_GLOW
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
		if campaign:
			# The brand sits low and small: the image sells.
			label.text = PrologueScript.CAMPAIGN_BRAND
			label.pixel_size = 0.0045 * scale
			label.modulate = Color(1.0, 0.93, 0.78)
			label.position = Vector3(0, -quad.size.y * 0.36, -0.2)
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
		var mode: PrologueScript.Mode = shot["mode"]
		var world_cam := (
			mode == PrologueScript.Mode.EXT_FIXED or mode == PrologueScript.Mode.EXT_PATH
		)
		if not world_cam:
			continue
		var cams: Array = shot["cam"] if shot["cam"] is Array else [shot["cam"]]
		for cam: Vector3 in cams:
			if shot.get("look") is Vector3:
				var look: Vector3 = shot["look"]
				lines.append(PackedVector2Array([Vector2(cam.x, cam.z), Vector2(look.x, look.z)]))
			# And to the train while the shot runs: the aerial must see it threading the
			# canyon (Phase B's tower walls hid it).
			var span: Array = shot.get("d", [])
			if span.size() == 2 and float(span[1]) > float(span[0]):
				for k in 3:
					var train := _frame_at(lerpf(span[0], span[1], k / 2.0)).origin
					lines.append(
						PackedVector2Array([Vector2(cam.x, cam.z), Vector2(train.x, train.z)])
					)
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
	# The canal it straddles, its quays and bridges: PrologueCity.
	var figure := ColossusFigure.new()
	figure.name = "GoldenColossus"
	figure.style = ColossusFigure.Style.GOLD_COPY
	figure.height = 56.0
	figure.stance = 26.0
	add_child(figure)
	# Straddle the track: its legs either side, facing along the line.
	figure.global_transform = Transform3D(f.basis, Vector3(f.origin.x, 0.0, f.origin.z))
	_gaze_targets["colossus"] = figure.head


## Real towers among the greybox blocks (Fab, CC-BY / free), the city's horizon,
## flying traffic through the canyon, and the abandoned graffiti tram in the town.
## Anything that would block a shot's sightline or sit on the track is skipped.
func _build_landmarks() -> void:
	var fab := "res://assets/third_party/fab/"
	var towers: Array = [
		["highrise_06/high_rise_building.glb", Vector3(110, 0, -120), 1.0, 30.0],
		# Its pivot is 17 m above its base: lift it by that, scaled.
		["rooftop_3/rooftop_3_hd_jfg_roblox_showcase_prop.glb", Vector3(300, 17.4, 110), 1.0, 0.0],
		["mega_tower/cyberpunk_skyscraper_3d_model.glb", Vector3(195, 100, -95), 200.0, 10.0],
		["mega_tower/cyberpunk_skyscraper_3d_model.glb", Vector3(10, 90, -170), 180.0, 70.0],
	]
	var sightlines := _sightlines()
	var boards: Array[Vector3] = []
	for i in PrologueScript.BILLBOARDS.size():
		boards.append(_billboard_anchor(i))
	for t in towers:
		var at: Vector3 = t[1]
		var ground := Vector3(at.x, 0, at.z)
		var near := _curve.get_closest_point(ground + Vector3(0, 15, 0))
		if Vector2(near.x, near.z).distance_to(Vector2(at.x, at.z)) < 55.0:
			continue
		if _blocks_view(ground, sightlines, boards):
			continue
		var n := CityKit.prop(fab + str(t[0]), self, at, float(t[3]), 0.0)  # skyline: always
		if n != null:
			n.scale = Vector3.ONE * float(t[2])
	var traffic := FlyingTraffic.new()
	traffic.name = "Traffic"
	add_child(traffic)
	traffic.add_lane(Vector3(-220, 75, -110), Vector3(380, 90, -70), 42.0, 4, 11)
	traffic.add_lane(Vector3(380, 110, 110), Vector3(-220, 95, 70), 38.0, 4, 12)
	# The town: an old graffiti tram left to rot by the dead mall.
	CityKit.prop(fab + "graffiti_train/SciFiTram.glb", self, Vector3(-572, 0.4, 28), 12.0)


## The film's sound bed (Cyberwave Audio Pack, CC-BY): a low city atmosphere throughout,
## and the carriage's sub rumble under the metro shot.
func _build_audio() -> void:
	# The film's sound (Phase D) listens to the film, its avenue and the final call.
	var sound := PrologueSound.new()
	sound.name = "Sound"
	sound.prologue = self
	sound.avenue = _avenue
	sound.head_call = _head_call
	add_child(sound)


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
