class_name DreamMemory
extends Node
## LOGIC — forgetting and confession (docs/STORY.md 10, 18; Ticket-20).
##
##   forgetting   "[E] Remember" at an anchor: he reaches for the colossi's meaning. Half a
##                sentence comes, then unwrites itself: "It's gone." (reach(): the dream
##                manager awaits it before the flash home.) Each reach takes the next
##                fragment; they're kept, in order, across cycles.
##   confession   after the third lost memory in a cycle, the next dream opens at a
##                colossus's feet (moved under the white). He can't move; the auto-return
##                stops; he's asked "Could you have stood there?" and every answer is a
##                flavour of no: "Selfish animal." Then he wakes. Once per cycle, and
##                never in the climax dream (the ambulance is armed).
##   the payoff   in the dual visions (18) the lost sentences finally finish
##                (lost_fragments()), one per valley flash: the meaning stays.
##
## Logic only: it emits; DreamText draws.

signal reaching(start: String)
signal forgotten
signal confession_started
signal confession_ended(tag: String)

const LOST_FOR_CONFESSION := 3
const LOCK := &"confession"
## Where he comes to: before a colossus, looking up at it. The dream camera looks −X−Z,
## so the statue there stands beyond him in frame (statue 3, +X+Z, would sit behind it).
const STATUE_INDEX := 1
const CONFESSION_DISTANCE := 0.55  # of the way from the valley's centre: it fills the sky

@export var dreamscape_manager: DreamscapeManager
@export var runner: DialogueRunner
@export var player: PlayerMovement
@export var ambulance: AmbulanceInterception
## Snapped onto him after the move, so the valley doesn't open on a swinging camera.
@export var camera: WorkspaceCamera

## Saved state (Persistence "dream_memory").
## Indices into FRAGMENTS of every memory lost, in order (all cycles).
var lost: Array[int] = []
var lost_this_cycle: int = 0
var confession_due: bool = false
var confessed: bool = false
var confession_tag: String = ""

var is_reaching: bool = false
var is_confessing: bool = false


func _ready() -> void:
	if dreamscape_manager != null:
		dreamscape_manager.worlds_swapped.connect(_on_worlds_swapped)
		dreamscape_manager.transition_completed.connect(_on_transition_completed)
	if runner != null:
		runner.choice_made.connect(_on_choice)


## One reach for the meaning; returns when it's gone.
func reach() -> void:
	if is_reaching:
		return
	is_reaching = true
	var index := lost.size() % DreamMemoryScript.FRAGMENTS.size()
	reaching.emit(str(DreamMemoryScript.FRAGMENTS[index][0]))
	await get_tree().create_timer(reach_seconds(), false).timeout
	lost.append(index)
	lost_this_cycle += 1
	if lost_this_cycle >= LOST_FOR_CONFESSION and not confessed:
		confession_due = true
	is_reaching = false
	forgotten.emit()


static func reach_seconds() -> float:
	return (
		DreamMemoryScript.WRITE_SECONDS
		+ DreamMemoryScript.HOLD_SECONDS
		+ DreamMemoryScript.ERASE_SECONDS
		+ DreamMemoryScript.GONE_SECONDS
	)


## The whole sentences he lost, oldest first, each once (the visions give them back).
func lost_fragments() -> Array[String]:
	var out: Array[String] = []
	for i in lost:
		var f: Array = DreamMemoryScript.FRAGMENTS[i]
		var line := "%s %s" % [f[0], f[1]]
		if not out.has(line):
			out.append(line)
	return out


func reset_cycle() -> void:
	lost_this_cycle = 0
	confession_due = false
	confessed = false
	confession_tag = ""


func snapshot() -> Dictionary:
	return {
		"lost": lost.duplicate(),
		"lost_this_cycle": lost_this_cycle,
		"confession_due": confession_due,
		"confessed": confessed,
		"confession_tag": confession_tag,
	}


func restore(data: Dictionary) -> void:
	lost.clear()
	for i in data.get("lost", []):
		lost.append(int(i))
	lost_this_cycle = int(data.get("lost_this_cycle", 0))
	confession_due = bool(data.get("confession_due", false))
	confessed = bool(data.get("confessed", false))
	confession_tag = str(data.get("confession_tag", ""))


func _confession_now() -> bool:
	return confession_due and not confessed and (ambulance == null or not ambulance.armed)


## Under the white, before the valley shows: he comes to at the colossus's feet.
func _on_worlds_swapped(to_dreamscape: bool) -> void:
	if not to_dreamscape or not _confession_now() or player == null:
		return
	var statue := DreamscapeEnvironment.STATUE_POSITIONS[STATUE_INDEX]
	var at := statue * CONFESSION_DISTANCE
	player.global_position = Vector3(at.x, player.global_position.y, at.z)
	player.face(statue - at)
	if camera != null:
		camera.set_dream_framing(true)


func _on_transition_completed(now_in_dreamscape: bool) -> void:
	if not now_in_dreamscape or not _confession_now() or runner == null:
		return
	is_confessing = true
	dreamscape_manager.cancel_auto_return()
	if player != null:
		player.lock_input(LOCK)
	confession_started.emit()
	runner.enqueue(DreamMemoryScript.CONFESSION)
	while not runner.is_idle():
		await runner.finished
	confessed = true
	confession_due = false
	is_confessing = false
	if player != null:
		player.unlock_input(LOCK)
	confession_ended.emit(confession_tag)
	dreamscape_manager.return_to_workspace()


func _on_choice(key: String, tag: String) -> void:
	if key == "confession":
		confession_tag = tag
