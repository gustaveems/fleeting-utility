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
## ARC
## ---
##   WORKSPACE ─collapse─▶ DREAMSCAPE ─ambulance─▶ INTERCEPTION ─forced return─▶ CLINICAL
##       ▲            │ (calm return)                                              │
##       └────────────┘                                                    loop reset
##                                                                               ▼
##   RANSACKED ◀─return─ PARK_WALK ◀─door (entropy ≥ 70)─ WORKSPACE / SCARRED ◀───┘
##       │  ▲
##   door│  └─visions end─ HESITATION (incl. dual visions)
##       ▼
##   HESITATION

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


func _on_transition_completed(now_in_dreamscape: bool) -> void:
	if now_in_dreamscape:
		_enter_phase(Phase.DREAMSCAPE)
	elif phase == Phase.DREAMSCAPE:
		# Calm return (timer, statue, anchor). The forced return is handled separately
		# and already moved us past DREAMSCAPE.
		_enter_phase(Phase.WORKSPACE)


func _on_loop_reset(_flavor_text: String) -> void:
	loops_completed += 1
	_enter_phase(Phase.SCARRED)


func _enter_phase(to: Phase) -> void:
	if to == phase:
		return
	var from := phase
	phase = to
	phase_changed.emit(from, to)
