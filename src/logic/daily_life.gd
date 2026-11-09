class_name DailyLife
extends Node
## LOGIC — the small daily things (docs/STORY.md 8a–c): the notice that comes under the
## door, the radio's bulletin, the log of his calls. Presentation (NoticeEnvelope, RadioSet,
## LeasePhone) reads this and owns no state of its own. Saved as "daily_life".

signal notice_arrived

## How much a bulletin eases him (it's company).
const RADIO_RELIEF := 6.0
## Calls the log keeps.
const LOG_SIZE := 40
const NONE := -1
const INCIDENT_NOTICE := 0

@export var day_cycle: DayCycle
@export var state_data: PlayerStateData
@export var ransacked: RansackedStateManager
@export var head_call: HeadCall

## Saved state. `pending`: a notice's day, INCIDENT_NOTICE, or NONE.
var pending: int = NONE
var radio_day: int = 0
var incident_sent: bool = false
var cycles: int = 0
## Each entry is [day, speaker, text].
var call_log: Array = []


func _ready() -> void:
	if day_cycle != null:
		day_cycle.morning.connect(_on_morning)
	if head_call != null:
		head_call.line_shown.connect(_on_line_shown)


func has_notice() -> bool:
	return pending != NONE


## The waiting notice as [from, title, body], or [].
func notice() -> Array:
	if pending == NONE:
		return []
	var n: Array = (
		DailyLifeScript.INCIDENT
		if pending == INCIDENT_NOTICE
		else (DailyLifeScript.NOTICES[pending])
	)
	if cycles == 0:
		return n
	return [n[0], DailyLifeScript.SECOND_NOTICE + str(n[1]), n[2]]


func read_notice() -> void:
	pending = NONE


func radio_broken() -> bool:
	return ransacked != null and ransacked.is_ransacked


func radio_available() -> bool:
	return not radio_broken() and radio_day != _day()


## Today's bulletin (spending the day's), and the ease that comes with it.
func hear_radio() -> Array:
	radio_day = _day()
	if state_data != null:
		state_data.sensory_overload = maxf(0.0, state_data.sensory_overload - RADIO_RELIEF)
	var bulletins := DailyLifeScript.BULLETINS
	return bulletins[clampi(_day() - 1, 0, bulletins.size() - 1)]


func reset_cycle() -> void:
	pending = NONE
	radio_day = 0
	incident_sent = false
	cycles += 1


func snapshot() -> Dictionary:
	return {
		"pending": pending,
		"radio_day": radio_day,
		"incident_sent": incident_sent,
		"cycles": cycles,
		"call_log": call_log.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	pending = int(data.get("pending", NONE))
	radio_day = int(data.get("radio_day", 0))
	incident_sent = bool(data.get("incident_sent", false))
	cycles = int(data.get("cycles", 0))
	call_log = (data.get("call_log", []) as Array).duplicate(true)
	if has_notice():
		notice_arrived.emit()


func _day() -> int:
	return day_cycle.day if day_cycle != null else 1


func _on_morning(day: int) -> void:
	if ransacked != null and ransacked.is_ransacked and not incident_sent:
		incident_sent = true
		pending = INCIDENT_NOTICE
	elif DailyLifeScript.NOTICES.has(day):
		pending = day
	else:
		return
	notice_arrived.emit()


func _on_line_shown(_index: int) -> void:
	if head_call == null or not head_call.is_call():
		return
	var line := head_call.current_line()
	if line.is_empty():
		return
	call_log.append([_day(), line[0], line[1]])
	if call_log.size() > LOG_SIZE:
		call_log.pop_front()
