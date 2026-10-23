class_name MetroRide
extends Node
## LOGIC — the metro across the city (Act I, 7c; Ticket-17). From the apartment door, once
## a day: blink to black, swap to the carriage (MetroCarriage), ride while the city's
## barometer plays (its ads and his thoughts change as the days pass), then home. Getting
## out takes the edge off: sensory overload eases. It is an outing, not the story's park
## walk; the arc is untouched.

signal ride_started(stage: int)
signal ride_ended

## Seconds of riding after the thoughts end, before his stop.
const LINGER := 2.0
const OVERLOAD_RELIEF := 25.0
const MOVE_SPEED := 2.5
const START := Vector3(-2.5, 0, 0.1)

@export var world_environment: WorldEnvironment
@export var apartment_root: WorldRoot
@export var player: PlayerMovement
@export var state_machine: PlayerStateMachine
@export var day_cycle: DayCycle
@export var runner: DialogueRunner
@export var hud: CoreHud
@export var fader: ScreenFader
@export var carriage: MetroCarriage
## 18a: after the realisation (a completed loop), the stone in the Heritage window.
@export var game_flow: GameFlow

## Saved (Persistence "metro").
var rides_taken: int = 0
var last_ride_day: int = -1
var is_riding: bool = false
var stone_seen: bool = false

var _saved_env: Environment
var _saved_pos: Vector3
var _saved_speed: float
var _saved_extents: Vector2


## One ride a day.
func available() -> bool:
	return not is_riding and (day_cycle == null or last_ride_day != day_cycle.day)


## The barometer: 0 upgrades · 1 the drug gets dearer · 2 the rich side spreads.
func stage() -> int:
	var day := day_cycle.day if day_cycle != null else 1
	return clampi(day / 3, 0, ActOneScript.RIDE_THOUGHTS.size() - 1)


func start_ride() -> void:
	if not available() or player == null or carriage == null:
		return
	is_riding = true
	last_ride_day = day_cycle.day if day_cycle != null else 1
	rides_taken += 1
	if fader != null:
		fader.blink()
	_saved_pos = player.global_position
	_saved_speed = player.move_speed
	_saved_extents = player.room_half_extents
	if apartment_root != null:
		apartment_root.set_active(false)
	carriage.set_stage(stage())
	var stone := _stone_due()
	carriage.show_stone(stone)
	if stone:
		stone_seen = true
	carriage.set_active(true)
	if world_environment != null:
		_saved_env = world_environment.environment
		world_environment.environment = carriage.environment
	player.global_position = START
	player.move_speed = MOVE_SPEED
	player.room_half_extents = Vector2(
		MetroCarriage.HALF_LENGTH - 0.3, MetroCarriage.HALF_WIDTH - 0.25
	)
	ride_started.emit(stage())
	if runner != null:
		# Going out interrupts whatever was being said through the wall.
		# (cancel() finishes the run synchronously: don't await a signal already fired.)
		if runner.is_running:
			runner.cancel()
		while runner.is_running:
			await get_tree().process_frame
		runner.run(ActOneScript.STONE_RIDE if stone else ActOneScript.RIDE_THOUGHTS[stage()])
		await runner.finished
	await get_tree().create_timer(LINGER, false).timeout
	end_ride()


func end_ride() -> void:
	if not is_riding:
		return
	if fader != null:
		fader.blink()
	carriage.set_active(false)
	if apartment_root != null:
		apartment_root.set_active(true)
	if world_environment != null and _saved_env != null:
		world_environment.environment = _saved_env
	player.global_position = _saved_pos
	player.move_speed = _saved_speed
	player.room_half_extents = _saved_extents
	if state_machine != null and state_machine.state_data != null:
		var data := state_machine.state_data
		data.sensory_overload = maxf(data.sensory_overload - OVERLOAD_RELIEF, 0.0)
		data.state_changed.emit(data)
	if hud != null:
		hud.show_line(ActOneScript.RIDE_HOME)
	is_riding = false
	ride_ended.emit()


func snapshot() -> Dictionary:
	return {"rides_taken": rides_taken, "last_ride_day": last_ride_day, "stone_seen": stone_seen}


func restore(data: Dictionary) -> void:
	rides_taken = int(data.get("rides_taken", 0))
	last_ride_day = int(data.get("last_ride_day", -1))
	stone_seen = bool(data.get("stone_seen", false))


## The first ride after the realisation (he has been through a whole loop).
func _stone_due() -> bool:
	return not stone_seen and game_flow != null and game_flow.loops_completed >= 1
