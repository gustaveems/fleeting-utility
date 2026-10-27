class_name Promises
extends Node
## LOGIC — the promises (docs/STORY.md 8; Ticket-18). The billboards follow him inside:
## Focus+ calls his head with offers that help at once and come due later. Lines in
## PromisesScript; played through the shared DialogueRunner queue, after the friend.
##
##   day 3        the offer: Focus+ Pro, "your dose, lasting longer, first month free"
##                  accept   → the drug wears off 25% slower (the trial)
##                  decline  → it asks once more on day 5; refused twice, it stops
##   trial + 3    the month is "over" (three days in): every way out costs
##                  keep     → billed to the lease: its decay rate ×1.15
##                  cancel   → the tolerance stays: the drug wears off 30% FASTER than
##                             before he ever tried Pro
##
## The depletion scale is a scar: it survives a renewed lease. A declined offer is made
## again in the next cycle. The wall screen (AdScreen) shows the state.
##
## Corporate Care (the promise that comes due at the climax):
##   first collapse   waking from his first collapse dream: "We noticed you collapsed."
##                      enrol    → collapse wakes are gentler (overload 30, not 50, and
##                                 a few seconds of calm)
##                      decline  → after the ransack, once: "Last chance to be covered."
##   the climax       enrolled: the ambulance is his Care plan. Refused: no one comes;
##                    he wakes on his own (AmbulanceInterception asks care_refused();
##                    never asked is not a no). A renewed lease keeps an enrolment and
##                    offers a refused one again.

signal changed

const OFFER_DAY := 3
const OFFER_AGAIN_DAY := 5
const TRIAL_DAYS := 3
## After the friend's morning call (same delay; queued behind it).
const CALL_DELAY := ActOne.CALL_DELAY + 0.2
## Drug depletion rate scale: on Pro, and after cancelling it.
const PRO_SCALE := 0.75
const CANCELLED_SCALE := 1.3
## Keeping Pro: the lease's decay rate.
const BILLED_RATE := 1.15
## Care: a collapse wake lands at this overload, with this much calm.
const CARE_WAKE_OVERLOAD := 30.0
const CARE_WAKE_RELIEF := 6.0

@export var day_cycle: DayCycle
@export var runner: DialogueRunner
@export var state_data: PlayerStateData
@export var entropy_data: WorkspaceEntropyData
@export var hud: CoreHud
## Care: collapses (the state machine's knockout) and their wakes (the dream manager),
## and the ransack (the last chance).
@export var state_machine: PlayerStateMachine
@export var dreamscape_manager: DreamscapeManager
@export var ransacked: RansackedStateManager

## Saved state (Persistence "promises").
## "" (not offered yet) / declined / refused / trial / kept / cancelled.
var pro: String = ""
var pro_day: int = -1
var depletion_scale: float = 1.0
## "" (not offered) / declined / enrolled / refused.
var care: String = ""
var care_day: int = -1
var care_last_offered: bool = false
## An offer or a bill is queued or playing (the screen pitches it).
var calling: bool = false

var _base_depletion: float = -1.0
var _collapsed: bool = false


func _ready() -> void:
	if state_data != null:
		_base_depletion = state_data.chemical_depletion_rate
	if day_cycle != null:
		day_cycle.morning.connect(_on_morning)
	if runner != null:
		runner.choice_made.connect(_on_choice)
		runner.finished.connect(_on_runner_finished)
	if state_machine != null:
		state_machine.dreamscape_transition_requested.connect(func(): _collapsed = true)
	if dreamscape_manager != null:
		dreamscape_manager.transition_completed.connect(_on_dream_done)
	if ransacked != null:
		ransacked.ransacked_applied.connect(_on_ransacked)


func is_care_enrolled() -> bool:
	return care == "enrolled"


## He said no (and it stands): at the climax, no one comes. Never asked is not a no.
func care_refused() -> bool:
	return care in ["declined", "refused"]


## Day the trial "ends" (for the screen).
func trial_ends() -> int:
	return pro_day + TRIAL_DAYS


## Which call this morning brings, if any.
func due_call(day: int) -> Array:
	match pro:
		"":
			return PromisesScript.PRO_OFFER if day >= OFFER_DAY else []
		"declined":
			return PromisesScript.PRO_OFFER_AGAIN if day >= OFFER_AGAIN_DAY else []
		"trial":
			return PromisesScript.PRO_DUE if day >= trial_ends() else []
	return []


## A renewed lease: the scale (his body) stays; a declined offer comes round again; a
## trial restarts its clock on Day 1.
func reset_cycle() -> void:
	calling = false
	if pro in ["declined", "refused"]:
		pro = ""
	elif pro == "trial":
		pro_day = 1
	if care != "enrolled":
		care = ""
	care_last_offered = false
	changed.emit()


func snapshot() -> Dictionary:
	return {
		"pro": pro,
		"pro_day": pro_day,
		"depletion_scale": depletion_scale,
		"care": "" if care == "asking" else care,  # mid-offer: not asked yet
		"care_day": care_day,
		"care_last_offered": care_last_offered,
	}


func restore(data: Dictionary) -> void:
	pro = str(data.get("pro", ""))
	pro_day = int(data.get("pro_day", -1))
	depletion_scale = float(data.get("depletion_scale", 1.0))
	care = str(data.get("care", ""))
	if care == "asking":
		care = ""
	care_day = int(data.get("care_day", -1))
	care_last_offered = bool(data.get("care_last_offered", false))
	calling = false
	_apply_scale()
	changed.emit()


func _on_morning(day: int) -> void:
	await get_tree().create_timer(CALL_DELAY, false).timeout
	var steps := due_call(day)
	if steps.is_empty() or runner == null:
		return
	calling = true
	changed.emit()
	runner.enqueue(steps, true)


func _on_choice(key: String, tag: String) -> void:
	match key:
		"pro":
			pro = "trial" if tag == "accepted" else tag
			if pro == "trial":
				pro_day = day_cycle.day if day_cycle != null else 1
				_set_scale(PRO_SCALE, PromisesScript.PRO_STARTED)
		"care", "care_last":
			care = tag
			if tag == "declined" and _is_ransacked():
				care_last_offered = true  # asked after the ransack: that was the last chance
			if tag == "enrolled":
				care_day = day_cycle.day if day_cycle != null else 1
				_line(PromisesScript.CARE_ENROLLED)
			return
		"pro_due":
			pro = tag
			if tag == "kept":
				if entropy_data != null:
					entropy_data.entropy_growth_rate *= BILLED_RATE
				_line(PromisesScript.PRO_KEPT)
			else:
				_set_scale(CANCELLED_SCALE, PromisesScript.PRO_CANCELLED)
		_:
			return
	calling = false
	changed.emit()


## A collapse dream ended calmly: Care's benefit, and maybe its offer.
func _on_dream_done(now_in_dreamscape: bool) -> void:
	if now_in_dreamscape or not _collapsed:
		return
	_collapsed = false
	if dreamscape_manager.is_forced_return:
		return
	if is_care_enrolled() and state_data != null:
		state_data.sensory_overload = minf(state_data.sensory_overload, CARE_WAKE_OVERLOAD)
		state_data.grant_relief(CARE_WAKE_RELIEF)
		state_data.state_changed.emit(state_data)
	await get_tree().create_timer(CALL_DELAY, false).timeout
	_offer_care()


func _on_ransacked() -> void:
	await get_tree().create_timer(CALL_DELAY, false).timeout
	_offer_care()


## First offer if never asked; the last chance once, after the ransack, if he declined.
## (Declined for the first time after the ransack, that was his last chance.)
func _offer_care() -> void:
	if runner == null:
		return
	if care == "":
		care = "asking"
		runner.enqueue(PromisesScript.CARE_OFFER, true)
	elif care == "declined" and _is_ransacked() and not care_last_offered:
		care_last_offered = true
		runner.enqueue(PromisesScript.CARE_LAST, true)


func _is_ransacked() -> bool:
	return ransacked != null and ransacked.is_ransacked


func _on_runner_finished() -> void:
	if care == "asking" and runner.is_idle():
		care = ""  # cut off before he answered: ask again next time
	if calling and runner.is_idle():
		calling = false  # cancelled under its lines (a ride, a scene change)
		changed.emit()


func _set_scale(scale: float, line: String) -> void:
	depletion_scale = scale
	_apply_scale()
	_line(line)


func _apply_scale() -> void:
	if state_data != null and _base_depletion > 0.0:
		state_data.chemical_depletion_rate = _base_depletion * depletion_scale


func _line(text: String) -> void:
	if hud != null:
		hud.show_line(text)
