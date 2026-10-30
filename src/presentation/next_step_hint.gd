class_name NextStepHint
extends CanvasLayer
## PRESENTATION — one quiet line under the meters saying what he could do next
## (playtest 2026-10-30: "as a completely new player you feel quite lost"). It reads the
## systems and never drives them. Hidden while anything else is talking or asking (the
## lease, the move-in, a call, a choice, a compulsion), so it never competes with a line.
##
## suggest(facts) is the whole policy, a pure function of a facts dictionary, so tests
## can check it without a scene.

const HINT_DREAM := "The dream: walk to a statue. [E] Remember."
const HINT_PARK := "Walk the park. The door takes you back."
const HINT_CRASH_PILL := "You're overloaded. The bench: [E] take a pill."
const HINT_CRASH_COOK := "You're overloaded. The bench: [E] cook a dose."
const HINT_CRASH_METRO := "You're overloaded. Get out of the room: the door, the metro."
const HINT_CRASH_WAIT := "You're overloaded, and there's nothing left. Sleep it off: the cot."
const HINT_LOW := "Your focus is wearing off. The bench: cook a dose, take it."
const HINT_INVITED := "You're invited out tonight. The door."
const HINT_UNBEARABLE := "The room is unbearable. The door: get out, walk."
const HINT_PAINT := "Paint. The easel: hold [E]."
const HINT_SLEEP := "The day is yours to end. The cot: [E] sleep."
## Below this much drug the hint sends him to the bench before it runs out.
const LOW_CHEMICAL := 0.35
const REFRESH_SECONDS := 0.5

@export var state_data: PlayerStateData
@export var bench: BenchStation
@export var easel: Easel
@export var door: ApartmentDoor
@export var day_cycle: DayCycle
@export var dreamscape_manager: DreamscapeManager
@export var park: CorporateParkManager
@export var metro_ride: MetroRide
@export var standing: Standing
@export var dialogue: DialogueRunner
@export var night_zero: NightZero
@export var lease_signing: LeaseSigning
@export var self_soothing: SelfSoothingController

var _label: Label
var _painted_day: int = -1
var _refresh: float = 0.0


## The line for this moment, or "" for none. Facts (all optional):
##   busy, in_dream, in_park, crashed, chemical, pill_ready, can_cook, metro, invited,
##   unbearable, painted_today
static func suggest(facts: Dictionary) -> String:
	if facts.get("busy", false):
		return ""
	if facts.get("in_dream", false):
		return HINT_DREAM
	if facts.get("in_park", false):
		return HINT_PARK
	if facts.get("crashed", false):
		if facts.get("pill_ready", false):
			return HINT_CRASH_PILL
		if facts.get("can_cook", false):
			return HINT_CRASH_COOK
		if facts.get("metro", false):
			return HINT_CRASH_METRO
		return HINT_CRASH_WAIT
	if float(facts.get("chemical", 1.0)) < LOW_CHEMICAL and facts.get("can_cook", false):
		return HINT_LOW
	if facts.get("unbearable", false):
		return HINT_UNBEARABLE
	if facts.get("invited", false):
		return HINT_INVITED
	if not facts.get("painted_today", false):
		return HINT_PAINT
	return HINT_SLEEP


func _ready() -> void:
	layer = 49  # under the HUD's lines (50), over the world
	_label = Label.new()
	_label.name = "NextStep"
	_label.theme = UiTheme.get_theme()
	_label.position = Vector2(20, 168)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.93, 0.9, 0.82, 0.92))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_child(_label)
	if easel != null:
		easel.work_finished.connect(func(_v: String): _painted_day = _day())


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = REFRESH_SECONDS
	var text := suggest(facts())
	_label.text = "" if text.is_empty() else "NEXT  " + text


## What the systems say right now.
func facts() -> Dictionary:
	var in_dream := dreamscape_manager != null and dreamscape_manager.in_dreamscape()
	var busy := (
		(lease_signing != null and lease_signing.is_open)
		or (night_zero != null and night_zero.is_running)
		or (dialogue != null and not dialogue.is_idle())
		or (self_soothing != null and self_soothing.is_in_compulsion())
		or (metro_ride != null and metro_ride.is_riding)
		or (standing != null and standing.is_out)
		or (dreamscape_manager != null and dreamscape_manager.is_busy())
	)
	return {
		"busy": busy,
		"in_dream": in_dream,
		"in_park": park != null and park.is_in_park(),
		"crashed": state_data != null and state_data.is_crashed(),
		"chemical": state_data.chemical_level if state_data != null else 1.0,
		"pill_ready": bench != null and bench.has_pill(),
		"can_cook": bench != null and bench.can_interact(),
		"metro": metro_ride != null and metro_ride.available(),
		"invited": standing != null and standing.invitation() >= 0,
		"unbearable": door != null and door.opens_to_park(),
		"painted_today": _painted_day == _day(),
	}


func _day() -> int:
	return day_cycle.day if day_cycle != null else 1
