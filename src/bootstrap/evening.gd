class_name Evening
extends Node3D
## COMPOSITION ROOT + DIRECTOR — Night Zero's evening (docs/STORY.md N5–N9, Ticket-16
## Phase 2). scenes/evening.tscn runs it after the move-in's invitation:
##
##   car      a film: the car glides down the other side's avenue, seen from the air
##   dinner   seated at the table; the first dialogue choices
##   gift     outside: the ride he turns down (or doesn't), the drug he takes (or doesn't)
##   walk     playable: through the rich side to the metro, thoughts at what he passes
##   metro    a film: the night train home
##   home     back to the apartment: Day 1 (the gift in his bag either way)
##
## Mechanics and layout first (greybox, EveningLayout); graphics follow.

signal segment_started(segment: String)

const GAME_SCENE_PATH := "res://scenes/workspace.tscn"
const LOCK := &"evening"
const CAR_SECONDS := 9.0
const METRO_SECONDS := 9.0
const METRO_PLATFORM_SECONDS := 2.5
## The diorama's people scale (matches the apartment).
const PERSON_SCALE := 0.47

## Read by the game when he gets home (then cleared): the gift he refused is in his bag.
static var returning: bool = false
static var gift_refused: bool = false

var segment: String = ""
var layout: EveningLayout
var runner: DialogueRunner
var player: PlayerMovement
var friend: StreetFigure

var _film: Camera3D
var _follow: WorkspaceCamera
var _head_call: HeadCall
var _choices: ChoicePanel
var _objective: Label


func _ready() -> void:
	InputActionData.register()
	_build()
	_play.call_deferred()


## Skip to the end of the current film segment (tests, impatience).
func skip_film() -> void:
	set_meta("skip", true)


func _build() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.62)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	layout = EveningLayout.new()
	layout.name = "Layout"
	add_child(layout)
	player = PlayerMovement.new()
	player.name = "Player"
	player.room_half_extents = layout.walk_extents()
	add_child(player)
	player.global_position = layout.world(EveningLayout.WALK_START)
	if StreetFigure.has_rig():
		var avatar := StreetFigure.new()
		avatar.dress = StreetFigure.Dress.HERO
		avatar.pose = StreetFigure.Pose.WALK
		avatar.scale = Vector3.ONE * PERSON_SCALE
		avatar.follow = player
		player.set_body_visual(avatar)
	_follow = WorkspaceCamera.new()
	_follow.name = "FollowCamera"
	add_child(_follow)
	_follow.set_target(player)
	_film = Camera3D.new()
	_film.name = "FilmCamera"
	_film.far = 1200.0
	add_child(_film)
	_head_call = HeadCall.new()
	_head_call.allow_skip = true
	add_child(_head_call)
	_choices = ChoicePanel.new()
	add_child(_choices)
	runner = DialogueRunner.new()
	runner.head_call = _head_call
	runner.choices_ui = _choices
	add_child(runner)
	_objective = Label.new()
	_objective.theme = UiTheme.get_theme()
	_objective.position = Vector2(24, 20)
	_objective.add_theme_font_size_override("font_size", 18)
	var hud := CanvasLayer.new()
	hud.add_child(_objective)
	add_child(hud)
	layout.beat_entered.connect(_on_beat)


func _play() -> void:
	await _warm_up()
	await _car()
	await _dinner()
	await _gift()
	await _walk()
	await _metro()
	_home()


func _start(name: String) -> void:
	segment = name
	if has_meta("skip"):
		remove_meta("skip")
	segment_started.emit(name)


## Behind black, look once at each heavy area so its textures and shaders load before the
## film starts (the prologue's lesson: first sight of a heavy model hitches).
func _warm_up() -> void:
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(black)
	add_child(layer)
	_film.make_current()
	var spots: Array = [
		[EveningLayout.CAR_ROUTE[0] + Vector3(0, 95, 75), EveningLayout.CAR_ROUTE[0]],
		[EveningLayout.DINNER_AT + Vector3(3.4, 2.6, 3.4), EveningLayout.DINNER_AT],
		[Vector3(30, 40, 60), Vector3(0, 0, 0)],
		[Vector3(30, 40, -40), Vector3(0, 0, -50)],
		[
			EveningLayout.TRAIN_AT + Vector3(14, 2.2, 14),
			EveningLayout.TRAIN_AT + Vector3(9, 1.8, 0)
		],
	]
	for spot in spots:
		_film.global_position = layout.world(spot[0])
		_film.look_at(layout.world(spot[1]), Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
	layer.queue_free()


## ----- SEGMENTS ----------------------------------------------------------------------------


func _car() -> void:
	_start("car")
	player.lock_input(LOCK)
	_film.make_current()
	runner.run(NightZeroScript.CAR)
	var a := EveningLayout.CAR_ROUTE[0]
	var b := EveningLayout.CAR_ROUTE[1]
	var t := 0.0
	while t < CAR_SECONDS and not has_meta("skip"):
		t += get_process_delta_time()
		var u := t / CAR_SECONDS
		var at := a.lerp(b, u)
		layout.car.position = at
		# High over the avenue, gliding with the car.
		_film.global_position = layout.world(at + Vector3(0, 95, 75))  # above the avenue
		_film.look_at(layout.world(at + Vector3(0, 0, -40)), Vector3.UP)
		await get_tree().process_frame
	runner.cancel()


func _dinner() -> void:
	_start("dinner")
	var c := EveningLayout.DINNER_AT
	_film.global_position = layout.world(c + Vector3(3.4, 2.6, 3.4))
	_film.look_at(layout.world(c + Vector3(0, 0.8, 0)), Vector3.UP)
	_film.make_current()
	await runner.run(NightZeroScript.DINNER)


func _gift() -> void:
	_start("gift")
	_follow.make_current()
	player.global_position = layout.world(EveningLayout.WALK_START)
	friend = StreetFigure.new()
	friend.dress = StreetFigure.Dress.FRIEND
	friend.pose = StreetFigure.Pose.HUDDLE
	friend.scale = Vector3.ONE * PERSON_SCALE
	add_child(friend)
	friend.global_position = layout.world(EveningLayout.WALK_START + Vector3(2.2, 0, -0.6))
	friend.look_at(player.global_position, Vector3.UP)
	await runner.run(NightZeroScript.GIFT)
	gift_refused = runner.choices.get("gift", "") == "refused"
	friend.queue_free()
	friend = null


func _walk() -> void:
	_start("walk")
	player.unlock_input(LOCK)
	_objective.text = NightZeroScript.WALK_OBJECTIVE
	await _wait_station()
	_objective.text = ""
	player.lock_input(LOCK)


func _wait_station() -> void:
	while not has_meta("at_station"):
		await get_tree().process_frame


func _metro() -> void:
	_start("metro")
	_film.make_current()
	runner.run(NightZeroScript.METRO)
	var c := EveningLayout.TRAIN_AT
	var t := 0.0
	while t < METRO_SECONDS and not has_meta("skip"):
		t += get_process_delta_time()
		if t < METRO_PLATFORM_SECONDS:
			# On the platform: the night train pulls in, graffiti and all.
			_film.global_position = layout.world(c + Vector3(14, 2.2, 14))
			_film.look_at(layout.world(c + Vector3(9, 1.8, 0)), Vector3.UP)
		else:
			var shake := Vector3(sin(t * 13.0), sin(t * 17.0), 0) * 0.03
			_film.global_position = layout.world(c + Vector3(0.4, 1.7, 8.0)) + shake
			_film.look_at(layout.world(c + Vector3(0, 1.4, -8)), Vector3.UP)
		await get_tree().process_frame
	runner.cancel()


func _home() -> void:
	_start("home")
	returning = true
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


## Thoughts at what he passes; the station ends the walk.
func _on_beat(beat: String) -> void:
	if segment != "walk":
		return
	if beat == "station":
		set_meta("at_station", true)
		return
	if not runner.is_running:
		runner.run(NightZeroScript.WALK_BEATS.get(beat, []))
