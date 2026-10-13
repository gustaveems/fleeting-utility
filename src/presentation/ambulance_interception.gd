class_name AmbulanceInterception
extends Node
## PRESENTATION/LOGIC — the Ticket-06 climax: technological interception.
##
## THE BEAT (MASTER_BRIEF.md §2, "The Climax")
## ------------------------------------------
## Fifteen seconds into the dream the corporate state refuses to let him die. Sirens
## close in, red/blue strobes wash the valley, the screen shakes at full strength, and
## after four seconds of escalation a defibrillation jolt yanks him back — violently,
## not gently. He does not choose to return.
##
## WHEN IT FIRES (MASTER_BRIEF order)
## -----------------------------------
## The climax ends the arc: walk → betrayal → hesitation → dual visions → climax. Early
## collapse dreams are calm. The ambulance stays disarmed until arm() is called (the
## bootstrap wires DualVisionController.visions_ended to it). Only the next dream is
## intercepted, and firing disarms it again.
##
## SEQUENCE
## --------
##   dream entry (transition_completed true) while armed → start 15 s timer
##   timer timeout → initiate_interception():
##     1. kill the 30 s auto-return + disable every MemoryAnchor (no peaceful exit)
##     2. red/blue flashing + ScreenEffects intensity override (siren: AudioDirector)
##     3. after escalation_seconds: emit defibrillation_triggered, force_return_to_workspace()
##
## WHY THE TIMER ARMS ON DREAM ENTRY, NOT IN _ready()
## --------------------------------------------------
## The spec says "start a Timer in _ready()", but a 15 s countdown from scene boot would
## fire before the dream even begins (the dream only starts on collapse, minutes in).
## The Timer node IS created in _ready(); it is *armed* on transition_completed(true) so
## the 15 s counts from the moment the valley appears. That is the only reading that
## matches "15 seconds into the dream."
##
## AUDIO
## -----
## This node owns no sound. AudioDirector plays the siren on interception_started and the
## defibrillation hit on defibrillation_triggered.

## Emitted when the defibrillation jolt fires, just before the forced return.
signal defibrillation_triggered

## Emitted the moment the interception begins (sirens/lights on).
signal interception_started

## --- DEPENDENCIES ----------------------------------------------------------------------

@export var dreamscape_manager: DreamscapeManager
@export var screen_effects: ScreenEffects

## The valley root, scanned for MemoryAnchor nodes to disable during the sequence.
@export var valley_root: DreamscapeEnvironment

## --- TIMING ----------------------------------------------------------------------------

## Seconds from dream entry to the interception.
@export var interception_delay: float = 15.0

## Seconds of siren/strobe/shake before the defibrillation jolt.
@export var escalation_seconds: float = 4.0

## --- INTERNAL STATE --------------------------------------------------------------------

## True once the arc has earned the climax (see class doc). Read-only outside arm().
var armed: bool = false

var _timer: Timer
var _red_light: OmniLight3D
var _blue_light: OmniLight3D
var _flash_tween: Tween
var _escalating: bool = false

## ----- LIFECYCLE ------------------------------------------------------------------------


func _ready() -> void:
	_timer = Timer.new()
	_timer.name = "InterceptionTimer"
	_timer.one_shot = true
	_timer.wait_time = interception_delay
	_timer.timeout.connect(initiate_interception)
	add_child(_timer)

	if dreamscape_manager != null:
		dreamscape_manager.transition_completed.connect(_on_transition_completed)

	_build_lights()


## The forced-detox beat is complete: the next dream is the climax.
func arm() -> void:
	armed = true


func _on_transition_completed(now_in_dreamscape: bool) -> void:
	if now_in_dreamscape and armed:
		# Arm the countdown the moment the valley becomes playable.
		_timer.start(interception_delay)
	else:
		# Leaving the dream by any path disarms a pending interception.
		_timer.stop()
		if _escalating:
			_stop_escalation()


## ----- THE INTERCEPTION ------------------------------------------------------------------


func initiate_interception() -> void:
	if dreamscape_manager == null or not dreamscape_manager.in_dreamscape():
		return
	if _escalating:
		return
	_escalating = true
	armed = false
	interception_started.emit()

	# 1. Seal the exits: no peaceful auto-return, no anchor escape.
	dreamscape_manager.cancel_auto_return()
	_disable_anchors()
	dreamscape_manager.clear_anchor_proximity()

	# 2. Escalate: strobes and full-strength screen violence (AudioDirector: siren).
	_start_flashing()
	if screen_effects != null:
		screen_effects.set_intensity_override(1.0)

	# 3. After the escalation window, the jolt and the forced return.
	await get_tree().create_timer(escalation_seconds, false).timeout
	defibrillation_triggered.emit()
	_stop_escalation()
	if dreamscape_manager != null:
		dreamscape_manager.force_return_to_workspace()
	_escalating = false


func _disable_anchors() -> void:
	if valley_root == null:
		return
	for anchor in valley_root.memory_anchors:
		anchor.set_enabled(false)
		# Keep them glowing but sealed through any later valley activation.
		valley_root.suppress(anchor, false)


## ----- LIGHTS (red/blue strobe) ------------------------------------------------------------


func _build_lights() -> void:
	_red_light = OmniLight3D.new()
	_red_light.name = "AmbulanceRed"
	_red_light.light_color = Color(1.0, 0.10, 0.10)
	_red_light.light_energy = 0.0
	_red_light.omni_range = 14.0
	add_child(_red_light)

	_blue_light = OmniLight3D.new()
	_blue_light.name = "AmbulanceBlue"
	_blue_light.light_color = Color(0.10, 0.30, 1.0)
	_blue_light.light_energy = 0.0
	_blue_light.omni_range = 14.0
	add_child(_blue_light)


func _start_flashing() -> void:
	_flash_tween = create_tween()
	_flash_tween.set_loops()
	# Alternating red then blue, 0.25 s on / 0.25 s off each — a classic emergency strobe.
	_flash_tween.tween_property(_red_light, "light_energy", 8.0, 0.25)
	_flash_tween.tween_property(_red_light, "light_energy", 0.0, 0.25)
	_flash_tween.tween_property(_blue_light, "light_energy", 8.0, 0.25)
	_flash_tween.tween_property(_blue_light, "light_energy", 0.0, 0.25)


## ----- TEARDOWN ------------------------------------------------------------------------------


func _stop_escalation() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
		_flash_tween = null
	if _red_light != null:
		_red_light.light_energy = 0.0
	if _blue_light != null:
		_blue_light.light_energy = 0.0
	if screen_effects != null:
		screen_effects.clear_intensity_override()
