class_name ActOne
extends Node3D
## LOGIC — Act I's people (docs/STORY.md 7a, 7b, 7d, 16a; Ticket-17). Lines in
## ActOneScript; played through the DialogueRunner.
##
##   the friend (7a)    a head call a few seconds after he wakes on days 2, 3, 4, 6.
##                      Warm, funny, busy, and every favour costs him something:
##                        co-sign "a formality"  → the lease's decay rate rises
##                        store "a crate"        → it sits by the door; it vanishes in
##                                                 the ransack (they cased the room)
##   the painting (7d)  from day 5, finishing a canvas prompts a call: lend it to "a
##                      client"; it leaves the wall; two mornings later "it SOLD",
##                      and he gets nothing
##   the neighbour (7b) through the wall: hello on day 2, a night sound on every third
##                      morning, a word when the room crosses into decay (40, 70)
##   after the ransack  (16a) the neighbour comes to the door the first time; on later
##                      cycles, silence. The crate is gone too.
##
## After the betrayal (a renewed lease) the friend never calls again.
## Lives under the apartment WorldRoot (the crate is a room prop).

const CALL_DELAY := 4.0
const COSIGN_RATE := 1.15
const DECAY_THRESHOLDS: Array[int] = [40, 70]
const CRATE_MODEL := "res://assets/third_party/polyhaven/wooden_crate_02/wooden_crate_02.gltf"
const CRATE_AT := Vector3(-1.4, 0, -2.6)
## Room props are full scale; the room is a diorama.
const PROP_SCALE := 0.47

@export var day_cycle: DayCycle
@export var easel: Easel
@export var game_flow: GameFlow
@export var entropy_data: WorkspaceEntropyData
@export var runner: DialogueRunner
@export var hud: CoreHud

## Saved state (Persistence "act_one").
var calls_done: Dictionary = {}
var favours: Dictionary = {}
var lent_on_day: int = -1
var sold_told: bool = false
var neighbour_said: Dictionary = {}
var friend_gone: bool = false
var cycles_seen: int = 0

var _queue: Array = []
var _crate: Node3D


func _ready() -> void:
	if day_cycle != null:
		day_cycle.morning.connect(_on_morning)
	if easel != null:
		easel.work_finished.connect(_on_work_finished)
	if entropy_data != null:
		entropy_data.entropy_changed.connect(_on_entropy)
	if game_flow != null:
		game_flow.phase_changed.connect(_on_phase)
	if runner != null:
		runner.finished.connect(_next_in_queue)
		runner.choice_made.connect(_on_choice)


## A renewed lease: the friend is gone for good; the room forgets the crate.
func reset_cycle() -> void:
	friend_gone = true
	cycles_seen += 1
	neighbour_said.erase("decay_40")
	neighbour_said.erase("decay_70")
	_remove_crate()
	_queue.clear()


func snapshot() -> Dictionary:
	return {
		"calls_done": calls_done.keys(),
		"favours": favours,
		"lent_on_day": lent_on_day,
		"sold_told": sold_told,
		"neighbour_said": neighbour_said.keys(),
		"friend_gone": friend_gone,
		"cycles_seen": cycles_seen,
	}


func restore(data: Dictionary) -> void:
	calls_done.clear()
	for d in data.get("calls_done", []):
		calls_done[int(d)] = true
	favours = data.get("favours", {})
	lent_on_day = int(data.get("lent_on_day", -1))
	sold_told = bool(data.get("sold_told", false))
	neighbour_said.clear()
	for k in data.get("neighbour_said", []):
		neighbour_said[str(k)] = true
	friend_gone = bool(data.get("friend_gone", false))
	cycles_seen = int(data.get("cycles_seen", 0))
	if favours.get("crate", "") == "gave" and not neighbour_said.has("ransack"):
		_place_crate()


## Play steps now, or after whatever is playing (calls don't talk over each other).
func play(steps: Array, as_call: bool = false) -> void:
	if steps.is_empty():
		return
	if runner.is_running:
		_queue.append([steps, as_call])
		return
	runner.run(steps, as_call)


## ----- TRIGGERS -----------------------------------------------------------------------


func _on_morning(day: int) -> void:
	await get_tree().create_timer(CALL_DELAY, false).timeout
	if not friend_gone:
		if ActOneScript.CALLS.has(day) and not calls_done.has(day):
			calls_done[day] = true
			play(ActOneScript.CALLS[day], true)
		if lent_on_day > 0 and not sold_told and day >= lent_on_day + 2:
			sold_told = true
			play(ActOneScript.SOLD_CALL, true)
	if day == 2 and not neighbour_said.has("hello"):
		neighbour_said["hello"] = true
		play(ActOneScript.NEIGHBOUR_HELLO)
	elif day >= 3 and day % 3 == 0:
		play(ActOneScript.NEIGHBOUR_NIGHT)
	if favours.get("cosign", "") == "gave" and not neighbour_said.has("cosign_cost"):
		neighbour_said["cosign_cost"] = true
		_line(ActOneScript.COSIGN_COST)


func _on_work_finished(_verdict: String) -> void:
	if friend_gone or favours.has("lend") or day_cycle == null or day_cycle.day < 5:
		return
	play(ActOneScript.BORROW, true)


func _on_entropy(value: float) -> void:
	for t in DECAY_THRESHOLDS:
		var key := "decay_%d" % t
		if value >= t and not neighbour_said.has(key):
			neighbour_said[key] = true
			play(ActOneScript.NEIGHBOUR_DECAY[t])


func _on_phase(_from: GameFlow.Phase, to: GameFlow.Phase) -> void:
	if to != GameFlow.Phase.RANSACKED or neighbour_said.has("ransack"):
		return
	neighbour_said["ransack"] = true
	if _crate != null:
		_remove_crate()
		_line(ActOneScript.CRATE_GONE)
	if cycles_seen == 0:
		play(ActOneScript.NEIGHBOUR_AFTER_RANSACK)
	else:
		_line(ActOneScript.NEIGHBOUR_SILENT)


func _on_choice(key: String, tag: String) -> void:
	favours[key] = tag
	if tag != "gave":
		return
	match key:
		"cosign":
			if entropy_data != null:
				entropy_data.entropy_growth_rate *= COSIGN_RATE
		"crate":
			_place_crate()
			_line(ActOneScript.CRATE_ARRIVED)
		"lend":
			if easel != null and easel.lend_work():
				lent_on_day = day_cycle.day if day_cycle != null else 1
				_line(ActOneScript.LENT_LINE)


func _next_in_queue() -> void:
	if _queue.is_empty():
		return
	var next: Array = _queue.pop_front()
	runner.run(next[0], next[1])


## ----- THE CRATE --------------------------------------------------------------------------


func _place_crate() -> void:
	if _crate != null:
		return
	_crate = CityKit.prop(CRATE_MODEL, self, CRATE_AT, 20.0, 0.0)
	if _crate == null:
		_crate = Node3D.new()
		add_child(_crate)
		_crate.position = CRATE_AT
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.4, 0.3, 0.3)
		mi.mesh = b
		mi.position.y = 0.15
		_crate.add_child(mi)
	else:
		_crate.scale = Vector3.ONE * PROP_SCALE


func _remove_crate() -> void:
	if _crate != null:
		_crate.queue_free()
		_crate = null


func _line(text: String) -> void:
	if hud != null:
		hud.show_line(text)
