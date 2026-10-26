class_name SelfBelief
extends Node
## LOGIC — self-belief (docs/STORY.md 6, 9; Ticket-19). Hidden: no meter. It starts
## high (Day 1: "sure that life starts here") and each relapse into a compulsion takes
## a chunk. Only a canvas finished OFF the drug gives a little back, and that is hard.
##
## Felt through:
##   the easel     off the drug he paints slower and judges harder as belief falls; at
##                 the bottom he won't paint without it ("Not like this.")
##   relapses      the compulsion triggers at lower overload: each relapse makes the
##                 next easier (80 → 65)
##   people        the neighbour hears it first (doubting), the friend at the bottom
##
## On the drug he is sharp: medicated painting is untouched ("without it he is nothing").
## A renewed lease restores some of it, less each cycle (a scar).

signal changed(value: float)

const START := 1.0
const RELAPSE_COST := 0.15
const SOBER_WORK_GAIN := 0.05
## Below this he won't paint off the drug.
const FLOOR := 0.2
## Stage bounds: sure ≥ 0.66 > doubting ≥ 0.33 > hollow.
const STAGE_BOUNDS: Array[float] = [0.66, 0.33]
## Compulsion threshold: at full belief and at none.
const COMPULSION_AT_FULL := 80.0
const COMPULSION_AT_NONE := 65.0
## Off the drug: paint time × (1 + this × lost belief); verdict quality − this × lost.
const SLOWDOWN := 1.0
const VERDICT_PENALTY := 0.3
## A renewed lease: belief restored to START − this × cycles (never below RENEW_MIN).
const CYCLE_SCAR := 0.15
const RENEW_MIN := 0.4
## After the friend's morning call and the offers.
const NOTICE_DELAY := ActOne.CALL_DELAY + 0.4

@export var state_data: PlayerStateData
@export var soothing: SelfSoothingController
@export var easel: Easel
@export var day_cycle: DayCycle
@export var runner: DialogueRunner
@export var act_one: ActOne

## Saved state (Persistence "self_belief").
var value: float = START
var relapses: int = 0
var cycles: int = 0
var said: Dictionary = {}


func _ready() -> void:
	if soothing != null:
		soothing.compulsion_started.connect(_on_relapse)
	if easel != null:
		easel.work_finished.connect(_on_work_finished)
	if day_cycle != null:
		day_cycle.morning.connect(_on_morning)
	_apply()


## 0 sure, 1 doubting, 2 hollow.
func stage() -> int:
	if value >= STAGE_BOUNDS[0]:
		return 0
	return 1 if value >= STAGE_BOUNDS[1] else 2


func is_off_drug() -> bool:
	return state_data != null and state_data.chemical_level < state_data.recovery_chemical_threshold


## Will he paint right now? Always on the drug; off it, not at the bottom.
func will_paint() -> bool:
	return value >= FLOOR or not is_off_drug()


## Multiplier on the time a canvas takes (1 on the drug).
func paint_time_scale() -> float:
	return 1.0 + SLOWDOWN * (1.0 - value) if is_off_drug() else 1.0


## Subtracted from a finished canvas's quality (0 on the drug).
func verdict_penalty() -> float:
	return VERDICT_PENALTY * (1.0 - value) if is_off_drug() else 0.0


func paint_prompt() -> String:
	return SelfBeliefScript.PAINT_PROMPTS[stage()]


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	_apply()
	changed.emit(value)


func reset_cycle() -> void:
	cycles += 1
	said.clear()
	set_value(maxf(START - CYCLE_SCAR * cycles, RENEW_MIN))


func snapshot() -> Dictionary:
	return {"value": value, "relapses": relapses, "cycles": cycles, "said": said.keys()}


func restore(data: Dictionary) -> void:
	relapses = int(data.get("relapses", 0))
	cycles = int(data.get("cycles", 0))
	said.clear()
	for k in data.get("said", []):
		said[str(k)] = true
	set_value(float(data.get("value", START)))


func _on_relapse() -> void:
	relapses += 1
	set_value(value - RELAPSE_COST)


func _on_work_finished(_verdict: String) -> void:
	if is_off_drug():
		set_value(value + SOBER_WORK_GAIN)


func _on_morning(_day: int) -> void:
	await get_tree().create_timer(NOTICE_DELAY, false).timeout
	if runner == null:
		return
	var s := stage()
	if s >= 1 and not said.has("tired"):
		said["tired"] = true
		runner.enqueue(SelfBeliefScript.NEIGHBOUR_TIRED)
	elif s >= 2 and not said.has("flat"):
		said["flat"] = true
		if act_one != null and not act_one.friend_gone:
			runner.enqueue(SelfBeliefScript.FRIEND_FLAT, true)
		else:
			runner.enqueue(SelfBeliefScript.NEIGHBOUR_FLAT)


## The spiral: the less he believes, the sooner the next relapse.
func _apply() -> void:
	if soothing != null:
		soothing.compulsion_threshold = lerpf(COMPULSION_AT_NONE, COMPULSION_AT_FULL, value)
