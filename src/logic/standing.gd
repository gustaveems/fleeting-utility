class_name Standing
extends Node
## LOGIC — the status loop (docs/STORY.md 7; Ticket-24). His LeaseLink standing is a
## percentile: everyone else advances every day, faster each day, so it sinks every
## morning. The friend's crowd invites him up (days 3, 5, 8: StandingScript.EVENTS). From
## the door he goes to the rooftop (RooftopLounge) and jockeys: fitting in lifts him,
## the truth costs a little, stumbling costs more. He only lands the smooth lines
## medicated; off the drug they turn into stumbles (StandingScript.perform). Whatever he
## gains, they have already moved on.
##
## After the betrayal (a renewed lease) the invitations stop; the standing keeps sinking.

signal changed(percentile: float)
signal event_started(index: int)
signal event_ended(index: int)

const START := 50.0
## Points lost each morning, and how much faster it gets each day (accelerationism).
const DRIFT_START := 3.0
const DRIFT_GROWTH := 0.5
const CALL_DELAY := ActOne.CALL_DELAY + 0.6
const MOVE_SPEED := 2.5

@export var day_cycle: DayCycle
@export var runner: DialogueRunner
@export var hud: CoreHud
@export var player: PlayerMovement
@export var state_data: PlayerStateData
@export var apartment_root: WorldRoot
@export var world_environment: WorldEnvironment
@export var fader: ScreenFader
@export var lounge: RooftopLounge
@export var act_one: ActOne

## Saved state (Persistence "standing").
var standing: float = START
var drift: float = DRIFT_START
var attended: Array[int] = []
## A night is on (the rooftop is the world).
var is_out: bool = false

var _saved_env: Environment
var _saved_pos: Vector3
var _saved_speed: float
var _saved_extents: Vector2


func _ready() -> void:
	if day_cycle != null:
		day_cycle.morning.connect(_on_morning)
	if runner != null:
		runner.choice_made.connect(_on_choice)


## Tonight's invitation (an index into EVENTS), or -1.
func invitation() -> int:
	if is_out or day_cycle == null or (act_one != null and act_one.friend_gone):
		return -1
	for i in StandingScript.EVENTS.size():
		if int(StandingScript.EVENTS[i][0]) == day_cycle.day and not attended.has(i):
			return i
	return -1


func is_medicated() -> bool:
	return (
		state_data != null and state_data.chemical_level >= state_data.recovery_chemical_threshold
	)


## Up to the rooftop for tonight's invitation; home when the talk is done.
func go_out() -> void:
	var index := invitation()
	if index < 0 or player == null or lounge == null:
		return
	is_out = true
	attended.append(index)
	if fader != null:
		fader.blink()
	_saved_pos = player.global_position
	_saved_speed = player.move_speed
	_saved_extents = player.room_half_extents
	if apartment_root != null:
		apartment_root.set_active(false)
	lounge.set_event(str(StandingScript.EVENTS[index][1]))
	lounge.set_active(true)
	if world_environment != null:
		_saved_env = world_environment.environment
		world_environment.environment = lounge.environment
	player.global_position = RooftopLounge.START
	player.move_speed = MOVE_SPEED
	player.room_half_extents = Vector2(
		RooftopLounge.HALF_LENGTH - 0.3, RooftopLounge.HALF_WIDTH - 0.25
	)
	event_started.emit(index)
	if runner != null:
		if runner.is_running:
			runner.cancel()  # going out interrupts whatever was being said
		while runner.is_running:
			await get_tree().process_frame
		runner.run(StandingScript.perform(StandingScript.NIGHTS[index], is_medicated()))
		while not runner.is_idle():
			await runner.finished
	_come_home(index)


func set_standing(value: float) -> void:
	standing = clampf(value, 0.0, 100.0)
	changed.emit(standing)


func reset_cycle() -> void:
	attended.clear()


func snapshot() -> Dictionary:
	return {"standing": standing, "drift": drift, "attended": attended.duplicate()}


func restore(data: Dictionary) -> void:
	drift = float(data.get("drift", DRIFT_START))
	attended.clear()
	for i in data.get("attended", []):
		attended.append(int(i))
	set_standing(float(data.get("standing", START)))


func _come_home(index: int) -> void:
	if fader != null:
		fader.blink()
	lounge.set_active(false)
	if apartment_root != null:
		apartment_root.set_active(true)
	if world_environment != null and _saved_env != null:
		world_environment.environment = _saved_env
	player.global_position = _saved_pos
	player.move_speed = _saved_speed
	player.room_half_extents = _saved_extents
	is_out = false
	if hud != null:
		hud.show_line(StandingScript.AFTER % int(round(standing)))
	event_ended.emit(index)


## Everyone else advanced overnight; tonight's invitation, if any.
func _on_morning(_day: int) -> void:
	set_standing(standing - drift)
	drift += DRIFT_GROWTH
	await get_tree().create_timer(CALL_DELAY, false).timeout
	var index := invitation()
	if index >= 0 and hud != null:
		hud.show_line(str(StandingScript.EVENTS[index][3]))


func _on_choice(key: String, tag: String) -> void:
	if not is_out or not key.begins_with("s_"):
		return
	set_standing(standing + float(StandingScript.DELTA.get(tag, 0.0)))
