class_name DayCycle
extends Node
## LOGIC — days (Ticket-14, loop 1): wake → try → sleep → dream → wake.
##
## Sleeping (the Cot) starts a NIGHT: the same calm valley dream as a collapse, but when
## it returns calmly it is MORNING. The day advances, he wakes gentle, and listeners
## (the Easel) let the lease reclaim yesterday's works. A collapse dream is a crash,
## not a night: it never advances the day. If the ambulance is armed, the night dream
## is the climax ("as he fades out and feels at peace…").

## Morning after a slept night.
signal morning(day: int)
## Any change of day, including restores and renewals (HUD).
signal day_changed(day: int)
## A renewed lease: Day 1 again, yesterday's works gone.
signal cycle_reset

## Morning calm: overload ceiling and relief window on waking.
const WAKE_OVERLOAD := 15.0
const WAKE_RELIEF_SECONDS := 10.0

@export var dreamscape_manager: DreamscapeManager
@export var state_machine: PlayerStateMachine

var day: int = 1

var _sleeping: bool = false


func _ready() -> void:
	if dreamscape_manager != null:
		dreamscape_manager.transition_completed.connect(_on_transition_completed)
		dreamscape_manager.forced_return_completed.connect(func(): _sleeping = false)
	day_changed.emit.call_deferred(day)


func can_sleep() -> bool:
	return (
		dreamscape_manager != null
		and not dreamscape_manager.in_dreamscape()
		and not dreamscape_manager.is_busy()
	)


func sleep() -> bool:
	if not can_sleep():
		return false
	_sleeping = true
	dreamscape_manager.transition_to_dreamscape()
	return true


func restore(saved_day: int) -> void:
	day = maxi(saved_day, 1)
	day_changed.emit(day)


func reset_cycle() -> void:
	day = 1
	_sleeping = false
	cycle_reset.emit()
	day_changed.emit(day)


func _on_transition_completed(now_in_dreamscape: bool) -> void:
	if now_in_dreamscape or not _sleeping:
		return
	_sleeping = false
	day += 1
	if state_machine != null and state_machine.state_data != null:
		var data := state_machine.state_data
		data.sensory_overload = minf(data.sensory_overload, WAKE_OVERLOAD)
		data.grant_relief(WAKE_RELIEF_SECONDS)
		data.state_changed.emit(data)
	day_changed.emit(day)
	morning.emit(day)
