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
## SEQUENCE
## --------
##   dream entry (transition_completed true) → arm 15 s timer
##   timer timeout → initiate_interception():
##     1. kill the 30 s auto-return + disable every MemoryAnchor (no peaceful exit)
##     2. start procedural siren + red/blue flashing + ScreenEffects intensity override
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
## No audio assets exist in the project, so the siren is generated procedurally into an
## AudioStreamWAV (two-tone 1080/720 Hz, continuous phase so the tone switch doesn't
## click) and played on an AudioStreamPlayer3D. Swap in a real asset later by replacing
## _build_siren_stream()'s return value.

## Emitted when the defibrillation jolt fires, just before the forced return.
signal defibrillation_triggered

## Emitted the moment the interception begins (sirens/lights on).
signal interception_started

## --- DEPENDENCIES ----------------------------------------------------------------------

@export var dreamscape_manager: DreamscapeManager
@export var screen_effects: ScreenEffects

## The valley root, scanned for MemoryAnchor nodes to disable during the sequence.
@export var valley_root: Node3D

## --- TIMING ----------------------------------------------------------------------------

## Seconds from dream entry to the interception.
@export var interception_delay: float = 15.0

## Seconds of siren/strobe/shake before the defibrillation jolt.
@export var escalation_seconds: float = 4.0

## --- INTERNAL STATE --------------------------------------------------------------------

var _timer: Timer
var _red_light: OmniLight3D
var _blue_light: OmniLight3D
var _siren_player: AudioStreamPlayer3D
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
	_build_siren_player()


func _on_transition_completed(now_in_dreamscape: bool) -> void:
	if now_in_dreamscape:
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
	interception_started.emit()

	# 1. Seal the exits: no peaceful auto-return, no anchor escape.
	dreamscape_manager.cancel_auto_return()
	_disable_anchors()
	dreamscape_manager.clear_anchor_proximity()

	# 2. Escalate: siren, strobes, full-strength screen violence.
	_start_siren()
	_start_flashing()
	if screen_effects != null:
		screen_effects.set_intensity_override(1.0)

	# 3. After the escalation window, the jolt and the forced return.
	await get_tree().create_timer(escalation_seconds).timeout
	defibrillation_triggered.emit()
	_stop_escalation()
	if dreamscape_manager != null:
		dreamscape_manager.force_return_to_workspace()
	_escalating = false


func _disable_anchors() -> void:
	if valley_root == null:
		return
	for child in valley_root.get_children():
		if child is MemoryAnchor:
			(child as MemoryAnchor).set_enabled(false)


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


## ----- SIREN (procedural) --------------------------------------------------------------------

func _build_siren_player() -> void:
	_siren_player = AudioStreamPlayer3D.new()
	_siren_player.name = "SirenPlayer"
	_siren_player.stream = _build_siren_stream()
	_siren_player.max_distance = 60.0
	_siren_player.unit_size = 8.0
	add_child(_siren_player)


func _start_siren() -> void:
	if _siren_player != null:
		_siren_player.play()


## Two-tone siren as a looping 16-bit mono WAV. Phase accumulates continuously so the
## 1080→720 Hz switch is a frequency change, not a discontinuity (no click).
func _build_siren_stream() -> AudioStreamWAV:
	var mix_rate := 22050
	var seconds := 2.0
	var sample_count := int(mix_rate * seconds)
	var data := PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit mono = 2 bytes per sample

	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(mix_rate)
		var freq := 1080.0 if fmod(t, 1.0) < 0.5 else 720.0
		phase += freq / float(mix_rate)
		var value := sin(phase * TAU) * 0.4
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


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
	if _siren_player != null:
		_siren_player.stop()
