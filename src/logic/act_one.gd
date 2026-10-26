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
##   the enclosure      (Act II) the first time the supply runs dry each cycle: Focus+
##                      reclassified (a notice in his head), the neighbour dry too, and the
##                      friend fronts him two compounds. He owes; the ransack collects.
##
## After the betrayal (a renewed lease) the friend never calls again.
## Lives under the apartment WorldRoot (the crate is a room prop).

## 7d: the canvas "sold" (the campaign picks it up from here).
signal sold(day: int)

const CALL_DELAY := 4.0
const COSIGN_RATE := 1.15
const DECAY_THRESHOLDS: Array[int] = [40, 70]
const CRATE_MODEL := "res://assets/third_party/polyhaven/wooden_crate_02/wooden_crate_02.gltf"
const CRATE_AT := Vector3(-1.4, 0, -2.6)
## 16a: where the neighbour stands, in his doorway (the door is at z −3.5).
const DOORWAY := Vector3(0.0, 0, -3.05)
## How long the neighbour stays at the door.
const VISIT_SECONDS := 7.0
## Room props are full scale; the room is a diorama.
const PROP_SCALE := 0.47

@export var day_cycle: DayCycle
@export var easel: Easel
@export var game_flow: GameFlow
@export var entropy_data: WorkspaceEntropyData
@export var runner: DialogueRunner
@export var hud: CoreHud
## Act II: the bench (to notice the supply run dry) and the worktop the friend fronts onto.
@export var bench_station: BenchStation
@export var spatial_grid: SpatialGrid
@export var compound_scene: PackedScene

## Saved state (Persistence "act_one").
var calls_done: Dictionary = {}
var favours: Dictionary = {}
var lent_on_day: int = -1
## The lent canvas's PaintedWork parameters (the campaign's copy is made from it).
var lent_work: Dictionary = {}
var sold_told: bool = false
var neighbour_said: Dictionary = {}
var friend_gone: bool = false
var cycles_seen: int = 0
var enclosure_told: bool = false
var in_debt: bool = false

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
		runner.choice_made.connect(_on_choice)
	if bench_station != null:
		bench_station.interacted.connect(_on_bench_used)


## A renewed lease: the friend is gone for good; the room forgets the crate.
func reset_cycle() -> void:
	friend_gone = true
	cycles_seen += 1
	neighbour_said.erase("decay_40")
	neighbour_said.erase("decay_70")
	neighbour_said.erase("ransack")
	enclosure_told = false
	in_debt = false
	favours.erase("front")
	_remove_crate()
	if runner != null:
		runner.clear_queue()


func snapshot() -> Dictionary:
	return {
		"calls_done": calls_done.keys(),
		"favours": favours,
		"lent_on_day": lent_on_day,
		"lent_work": lent_work,
		"sold_told": sold_told,
		"neighbour_said": neighbour_said.keys(),
		"friend_gone": friend_gone,
		"cycles_seen": cycles_seen,
		"enclosure_told": enclosure_told,
		"in_debt": in_debt,
	}


func restore(data: Dictionary) -> void:
	calls_done.clear()
	for d in data.get("calls_done", []):
		calls_done[int(d)] = true
	favours = data.get("favours", {})
	lent_on_day = int(data.get("lent_on_day", -1))
	lent_work = data.get("lent_work", {})
	sold_told = bool(data.get("sold_told", false))
	neighbour_said.clear()
	for k in data.get("neighbour_said", []):
		neighbour_said[str(k)] = true
	friend_gone = bool(data.get("friend_gone", false))
	cycles_seen = int(data.get("cycles_seen", 0))
	enclosure_told = bool(data.get("enclosure_told", false))
	in_debt = bool(data.get("in_debt", false))
	if favours.get("crate", "") == "gave" and not neighbour_said.has("ransack"):
		_place_crate()


## Play steps now, or after whatever is playing (calls don't talk over each other).
func play(steps: Array, as_call: bool = false) -> void:
	runner.enqueue(steps, as_call)


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
			sold.emit(day)
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
	if in_debt:
		in_debt = false
		_line(ActOneScript.DEBT_COLLECTED)
	if cycles_seen == 0:
		_neighbour_at_door()
		play(ActOneScript.NEIGHBOUR_AFTER_RANSACK)
	else:
		_line(ActOneScript.NEIGHBOUR_SILENT)


func _on_choice(key: String, tag: String) -> void:
	if key not in ActOneScript.FAVOURS:
		return  # someone else's choice (the corporation's offers)
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
		"front":
			in_debt = true
			_front_compounds(ActOneScript.FRONT_COMPOUNDS)
			_line(ActOneScript.FRONT_ARRIVED)
		"lend":
			if easel != null and easel.lend_work():
				lent_on_day = day_cycle.day if day_cycle != null else 1
				lent_work = easel.last_lent.duplicate()
				_line(ActOneScript.LENT_LINE)


## Act II: the first time this cycle he takes the last of it, the enclosure.
func _on_bench_used() -> void:
	await get_tree().process_frame  # the pill leaves the worktop next frame
	if enclosure_told or not bench_station.is_dry():
		return
	enclosure_told = true
	if cycles_seen > 0:
		_line(ActOneScript.ENCLOSURE_AGAIN)
		return
	play(ActOneScript.ENCLOSURE_NOTICE, true)
	play(ActOneScript.ENCLOSURE_NEIGHBOUR)
	if not friend_gone:
		play(ActOneScript.ENCLOSURE_FRIEND, true)


## The friend's fronted compounds, onto the first free worktop cells.
func _front_compounds(count: int) -> void:
	if spatial_grid == null or compound_scene == null:
		return
	var placed := 0
	for y in spatial_grid.grid_depth:
		for x in spatial_grid.grid_width:
			if placed >= count:
				return
			var cell := Vector2i(x, y)
			if not spatial_grid.is_cell_occupied(cell):
				if spatial_grid.place_item(compound_scene, cell) != null:
					placed += 1


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
	# Not his: stencilled, banded, locked.
	var stencil := Label3D.new()
	stencil.text = "DO NOT OPEN"
	stencil.font_size = 48
	stencil.pixel_size = 0.0035
	stencil.modulate = Color(0.12, 0.1, 0.08)
	stencil.position = Vector3(0, 0.36, 0)
	stencil.rotation_degrees = Vector3(-90, 0, 0)
	_crate.add_child(stencil)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.3, 0.3, 0.32)
	steel.metallic = 0.8
	steel.roughness = 0.35
	for x in [-0.12, 0.12]:
		var band := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.02, 0.36, 0.34)
		band.mesh = b
		band.material_override = steel
		band.position = Vector3(x, 0.17, 0)
		_crate.add_child(band)


## 16a staged: the neighbour in the doorway, gaunt, hugging themself, then gone.
func _neighbour_at_door() -> void:
	var n := StreetFigure.new()
	n.name = "NeighbourAtDoor"
	n.dress = StreetFigure.Dress.POOR
	n.pose = StreetFigure.Pose.STAND
	n.position = DOORWAY
	n.scale = Vector3(0.44, 0.45, 0.44)  # a little smaller, thinner than him
	add_child(n)
	await get_tree().create_timer(VISIT_SECONDS, false).timeout
	if is_instance_valid(n):
		n.queue_free()


func _remove_crate() -> void:
	if _crate != null:
		_crate.queue_free()
		_crate = null


func _line(text: String) -> void:
	if hud != null:
		hud.show_line(text)
