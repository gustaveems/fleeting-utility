class_name GameFlow
extends Node
## LOGIC — the narrative phase the game is in, derived from the systems that drive it.
##
## A PURE OBSERVER
## ---------------
## GameFlow never commands anything. It listens to signals the managers already emit and
## keeps one answer to "where are we in the arc?", published as a single
## `phase_changed`. Consumers that care about the whole arc (audio soundscapes,
## save/load, the menu, analytics) listen here instead of wiring to a dozen managers.
##
## ARC (MASTER_BRIEF order)
## -------------------------
##   WORKSPACE ⇄ DREAMSCAPE            early collapses: calm dreams, return to the room
##   WORKSPACE → PARK_WALK → RANSACKED (one walk per cycle; the betrayal)
##   RANSACKED ⇄ DREAMSCAPE            forced detox: calm dreams in the ruined room
##   RANSACKED → HESITATION → RANSACKED   at the door; dual visions arm the ambulance
##   RANSACKED → DREAMSCAPE → INTERCEPTION → CLINICAL → SCARRED   the climax and reset

signal phase_changed(from: Phase, to: Phase)

enum Phase {
	WORKSPACE,
	DREAMSCAPE,
	INTERCEPTION,
	CLINICAL,
	SCARRED,
	PARK_WALK,
	RANSACKED,
	HESITATION,
}

@export var dreamscape_manager: DreamscapeManager
@export var ambulance: AmbulanceInterception
@export var endgame: EndgameLoopManager
@export var park: CorporateParkManager
@export var ransacked: RansackedStateManager
@export var hesitation: HesitationController
@export var dual_vision: DualVisionController

var phase: Phase = Phase.WORKSPACE

## Completed scarred-reset loops. Survives into save data (T12).
var loops_completed: int = 0

## Where a calm dream returns to (the room the collapse happened in).
var _phase_before_dream: Phase = Phase.WORKSPACE


func _ready() -> void:
	if dreamscape_manager != null:
		dreamscape_manager.transition_completed.connect(_on_transition_completed)
		dreamscape_manager.forced_return_completed.connect(_enter_phase.bind(Phase.CLINICAL))
	if ambulance != null:
		ambulance.interception_started.connect(_enter_phase.bind(Phase.INTERCEPTION))
	if endgame != null:
		endgame.loop_reset.connect(_on_loop_reset)
	if park != null:
		park.walk_started.connect(_enter_phase.bind(Phase.PARK_WALK))
	if ransacked != null:
		ransacked.ransacked_applied.connect(_enter_phase.bind(Phase.RANSACKED))
	if hesitation != null:
		hesitation.hesitation_rumble.connect(_enter_phase.bind(Phase.HESITATION))
	if dual_vision != null:
		dual_vision.visions_ended.connect(_enter_phase.bind(Phase.RANSACKED))


func phase_name() -> String:
	return Phase.keys()[phase]


## Save-system view (T12).
func snapshot() -> Dictionary:
	return {"phase": phase_name(), "loops_completed": loops_completed}


## Restore a saved checkpoint: set the phase (announced once, so audio/VFX follow) and
## the loop count.
func restore(saved_phase: Phase, loops: int) -> void:
	loops_completed = loops
	_phase_before_dream = saved_phase
	_enter_phase(saved_phase)


func _on_transition_completed(now_in_dreamscape: bool) -> void:
	if now_in_dreamscape:
		if phase != Phase.DREAMSCAPE:
			_phase_before_dream = phase
		_enter_phase(Phase.DREAMSCAPE)
	elif phase == Phase.DREAMSCAPE:
		# Calm return (timer, statue, anchor) to the room the collapse happened in. The
		# forced return is handled separately and already moved us past DREAMSCAPE.
		_enter_phase(_phase_before_dream)


func _on_loop_reset(_flavor_text: String) -> void:
	loops_completed += 1
	_enter_phase(Phase.SCARRED)


func _enter_phase(to: Phase) -> void:
	if to == phase:
		return
	var from := phase
	phase = to
	phase_changed.emit(from, to)
