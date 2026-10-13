class_name AudioDirector
extends Node
## PRESENTATION — the soundscape. Turns narrative phase and gameplay signals into sound;
## no logic script owns an audio node.
##
## AMBIENT BEDS LIVE INSIDE THE WORLDS
## -----------------------------------
## Each world's looping beds are children of its WorldRoot and follow its
## activation_changed signal: paused in place while the world is out of play, resumed
## where they left off when it returns. So every world swap (dream, walk, each Dual
## Visions flash) cuts and restores that world's sound with no per-swap logic here.
## The pause is explicit: process_mode alone does pause a playing stream, but a stream
## started inside an ALREADY-inactive world plays anyway (verified 4.7.2). This node
## otherwise only sets each bed's LEVEL from the GameFlow phase.
##
##   apartment  room tone · decay drone (entropy) · fluorescent hum (3D, clinical) ·
##              cold draft (3D, ransacked)
##   valley     wind + warm pad          park  bright air + sterile triad
##   (head)     hesitation rumble, heartbeat/compulsion pulse, siren, stings
##
## PHASE → APARTMENT MIX
## ---------------------
##   WORKSPACE   room tone, decay drone by entropy
##   CLINICAL    fluorescent hum only, HARD CUT (the violent return)
##   SCARRED     thin room tone, slow fade ("defeated silence")
##   RANSACKED   room tone + cold draft, decay drone by entropy
##   HESITATION  as RANSACKED + rumble
##
## THE BODY
## --------
##   crash         World-bus low-pass closes and overdrive rises with overload ≥ 50
##                 (apartment only; the dream is serene)
##   compulsion    heartbeat pulse whose tempo tracks overload; a tap per soothe
##   hesitation    heartbeat climbing through the dual visions, under the rumble
##
## Dream transitions duck the Ambience bus as the screen whites out, and lift it from
## the world swap (at full white) through the fade-in, so the new world fades in with
## the picture. The forced return does not duck: it cuts.

const SILENT_DB := -60.0
const FADE_SECONDS := 1.5
const SLOW_FADE_SECONDS := 3.0
const DUCK_DB := -24.0
const CRASH_MIN_CUTOFF_HZ := 650.0
const CRASH_MAX_DRIVE := 0.35
const CRASH_SMOOTHING := 4.0
const POOL_SIZE := 6

## Apartment bed names this director mixes per phase.
const APARTMENT_BEDS: Array[StringName] = [
	SoundBank.ROOM_TONE, SoundBank.DECAY_DRONE, SoundBank.FLUORESCENT_HUM, SoundBank.COLD_DRAFT
]

## Real recordings go here; null = the procedural placeholder bank.
@export var bank: SoundBank

@export var game_flow: GameFlow
@export var state_machine: PlayerStateMachine
@export var entropy_data: WorkspaceEntropyData
@export var dreamscape_manager: DreamscapeManager
@export var ambulance: AmbulanceInterception
@export var self_soothing: SelfSoothingController
@export var trivial_object: TrivialObject
@export var hesitation: HesitationController
@export var dual_vision: DualVisionController
@export var interaction_controller: InteractionController
@export var endgame: EndgameLoopManager
@export var ransacked: RansackedStateManager
@export var park_manager: CorporateParkManager
@export var apartment: WorldRoot
@export var valley: DreamscapeEnvironment

## Where the 3D apartment emitters sit (room coordinates).
@export var fluorescent_position: Vector3 = Vector3(0.0, 2.4, 0.0)
@export var draft_position: Vector3 = Vector3(2.0, 1.2, -3.3)

## Compulsion pulse tempo across overload 80 → 100.
@export var compulsion_bpm_range: Vector2 = Vector2(90.0, 160.0)

## Hesitation heartbeat tempo, start → end of the dual visions.
@export var hesitation_bpm_range: Vector2 = Vector2(70.0, 150.0)

## 0..1, smoothed. Read by tests (and later by VFX that want to sync to the crash).
var crash_intensity: float = 0.0

## The most recent one-shot cue name (tests, debugging).
var last_one_shot: StringName = &""

var _beds: Dictionary[StringName, Node] = {}
var _bed_worlds: Dictionary[StringName, WorldRoot] = {}
var _bed_tweens: Dictionary[StringName, Tween] = {}
var _bed_levels: Dictionary[StringName, float] = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_next: int = 0
var _siren: AudioStreamPlayer
var _siren_tween: Tween
var _heart: RhythmicCuePlayer
var _heart_tween: Tween
var _duck_tween: Tween
var _ducked: bool = false
var _phase: GameFlow.Phase = GameFlow.Phase.WORKSPACE

## ----- LIFECYCLE -----------------------------------------------------------------------


func _ready() -> void:
	var defaults := ProceduralAudio.default_bank()
	if bank == null:
		bank = defaults
	elif bank.fallback == null and bank != defaults:
		bank.fallback = defaults
	_build_players()
	_build_beds()
	_connect_signals()
	_apply_phase(_phase, 0.0)


func _process(delta: float) -> void:
	_drive_crash(delta)
	_drive_decay()
	_drive_compulsion_tempo()


## Statue narratives exist only after the valley module's post_attach.
func listen_to_statues(narratives: Array[StatueNarrative]) -> void:
	for n in narratives:
		n.statue_truth_revealed.connect(func(_text: String): play_one_shot(SoundBank.STATUE_STING))


## ----- PUBLIC QUERIES (tests, tooling) ---------------------------------------------------


func bed_level(bed: StringName) -> float:
	return _bed_levels.get(bed, 0.0)


## True when the bed is playing un-paused (its world is active) at an audible level.
func bed_audible(bed: StringName) -> bool:
	var p: Node = _beds.get(bed)
	if p == null or not p.get("playing") or p.get("stream_paused"):
		return false
	return float(p.get("volume_db")) > SILENT_DB + 1.0


func heart() -> RhythmicCuePlayer:
	return _heart


func siren_playing() -> bool:
	return _siren != null and _siren.playing


## ----- ONE-SHOTS -------------------------------------------------------------------------


func play_one_shot(cue_name: StringName) -> void:
	var cue := bank.cue(cue_name)
	if cue == null or cue.stream == null:
		return
	var p := _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stream = cue.stream
	p.bus = cue.bus
	p.volume_db = cue.volume_db
	p.pitch_scale = 1.0 + randf_range(-cue.pitch_jitter, cue.pitch_jitter)
	p.play()
	last_one_shot = cue_name


## ----- BUILD ---------------------------------------------------------------------------


func _build_players() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "OneShot%d" % i
		add_child(p)
		_pool.append(p)

	_siren = AudioStreamPlayer.new()
	_siren.name = "Siren"
	var siren_cue := bank.cue(SoundBank.SIREN)
	if siren_cue != null:
		_siren.stream = siren_cue.stream
		_siren.bus = siren_cue.bus
	add_child(_siren)

	_heart = RhythmicCuePlayer.new()
	_heart.name = "Heartbeat"
	_heart.cue = bank.cue(SoundBank.HEARTBEAT)
	add_child(_heart)


func _build_beds() -> void:
	if apartment != null:
		_add_bed(SoundBank.ROOM_TONE, apartment, null)
		_add_bed(SoundBank.DECAY_DRONE, apartment, null)
		_add_bed(SoundBank.FLUORESCENT_HUM, apartment, fluorescent_position)
		_add_bed(SoundBank.COLD_DRAFT, apartment, draft_position)
	if valley != null:
		_add_bed(SoundBank.VALLEY_AIR, valley, null)
		_set_bed(SoundBank.VALLEY_AIR, 1.0, 0.0)
	var park_root := park_manager.get_park_root() if park_manager != null else null
	if park_root != null:
		_add_bed(SoundBank.PARK_AIR, park_root, null)
		_set_bed(SoundBank.PARK_AIR, 1.0, 0.0)
	# The rumble is in his head: not part of any world.
	_add_bed(SoundBank.RUMBLE, self, null)


## A looping bed under `parent`. A Vector3 position makes it a spatial emitter.
func _add_bed(bed: StringName, parent: Node, at: Variant) -> void:
	var cue := bank.cue(bed)
	if cue == null:
		return
	var p: Node
	if at is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.position = at
		p3.unit_size = 6.0
		p3.max_distance = 30.0
		p = p3
	else:
		p = AudioStreamPlayer.new()
	p.name = "Bed_%s" % bed
	p.set("stream", cue.stream)
	p.set("bus", cue.bus)
	p.set("volume_db", SILENT_DB)
	parent.add_child(p)
	p.call("play")
	_beds[bed] = p
	_bed_levels[bed] = 0.0
	if parent is WorldRoot:
		var world := parent as WorldRoot
		_bed_worlds[bed] = world
		p.set("stream_paused", not world.is_active)
		if not world.activation_changed.is_connected(_on_world_activation):
			world.activation_changed.connect(_on_world_activation.bind(world))


func _on_world_activation(active: bool, world: WorldRoot) -> void:
	for bed in _bed_worlds:
		if _bed_worlds[bed] == world:
			_beds[bed].set("stream_paused", not active)
	# A world arriving under the white fade is the moment to lift the duck.
	if active and _ducked:
		_duck_ambience(false)


func _connect_signals() -> void:
	if game_flow != null:
		game_flow.phase_changed.connect(_on_phase_changed)
	if dreamscape_manager != null:
		dreamscape_manager.transition_started.connect(_duck_ambience.bind(true))
		dreamscape_manager.return_started.connect(_duck_ambience.bind(true))
		dreamscape_manager.transition_completed.connect(_on_transition_completed)
		dreamscape_manager.forced_return_completed.connect(_on_forced_return)
	if ambulance != null:
		ambulance.interception_started.connect(_start_siren)
		ambulance.defibrillation_triggered.connect(_on_defibrillation)
	if self_soothing != null:
		self_soothing.compulsion_started.connect(_on_compulsion.bind(true))
		self_soothing.compulsion_ended.connect(_on_compulsion.bind(false))
	if trivial_object != null:
		trivial_object.soothed.connect(func(_amount: float): play_one_shot(SoundBank.TAP))
	if hesitation != null:
		hesitation.hesitation_rumble.connect(_on_hesitation)
	if dual_vision != null:
		dual_vision.visions_ended.connect(_on_visions_ended)
	if interaction_controller != null:
		interaction_controller.interaction_locked.connect(play_one_shot.bind(SoundBank.DENIED))
	if endgame != null:
		endgame.loop_reset.connect(func(_text: String): play_one_shot(SoundBank.CHIME))
	if ransacked != null:
		ransacked.betrayal_realized.connect(
			func(_text: String): play_one_shot(SoundBank.BETRAYAL_STING)
		)
	if valley != null:
		for anchor in valley.memory_anchors:
			anchor.memory_triggered.connect(play_one_shot.bind(SoundBank.CHIME))


## ----- PHASE MIX ---------------------------------------------------------------------------


func _on_phase_changed(_from: GameFlow.Phase, to: GameFlow.Phase) -> void:
	_phase = to
	var fade := FADE_SECONDS
	match to:
		GameFlow.Phase.CLINICAL:
			fade = 0.0
		GameFlow.Phase.SCARRED:
			fade = SLOW_FADE_SECONDS
	_apply_phase(to, fade)


func _apply_phase(phase: GameFlow.Phase, fade: float) -> void:
	_set_bed(SoundBank.RUMBLE, 1.0 if phase == GameFlow.Phase.HESITATION else 0.0, 0.3)
	var mix: Dictionary
	match phase:
		GameFlow.Phase.WORKSPACE:
			mix = {SoundBank.ROOM_TONE: 1.0, SoundBank.FLUORESCENT_HUM: 0.0}
			mix[SoundBank.COLD_DRAFT] = 0.0
		GameFlow.Phase.CLINICAL:
			mix = {SoundBank.ROOM_TONE: 0.0, SoundBank.DECAY_DRONE: 0.0}
			mix[SoundBank.FLUORESCENT_HUM] = 1.0
			mix[SoundBank.COLD_DRAFT] = 0.0
		GameFlow.Phase.SCARRED:
			mix = {SoundBank.ROOM_TONE: 0.35, SoundBank.DECAY_DRONE: 0.0}
			mix[SoundBank.FLUORESCENT_HUM] = 0.0
			mix[SoundBank.COLD_DRAFT] = 0.0
		GameFlow.Phase.RANSACKED, GameFlow.Phase.HESITATION:
			mix = {SoundBank.ROOM_TONE: 0.7, SoundBank.FLUORESCENT_HUM: 0.0}
			mix[SoundBank.COLD_DRAFT] = 1.0
		_:
			# Dream, interception, walk: the apartment is paused; keep its mix.
			return
	for bed in mix:
		_set_bed(bed, mix[bed], fade)


## Fade a bed to a linear level (0 = silent). fade 0 = cut.
func _set_bed(bed: StringName, level: float, fade: float) -> void:
	var p: Node = _beds.get(bed)
	if p == null:
		return
	_bed_levels[bed] = level
	var cue := bank.cue(bed)
	var target := SILENT_DB if level <= 0.001 else cue.volume_db + linear_to_db(level)
	var old: Tween = _bed_tweens.get(bed)
	if old != null and old.is_valid():
		old.kill()
	if fade <= 0.0:
		p.set("volume_db", target)
		return
	var tween := create_tween()
	tween.tween_property(p, "volume_db", target, fade)
	_bed_tweens[bed] = tween


## Decay drone follows entropy in the apartment phases where the room is decaying.
func _drive_decay() -> void:
	if entropy_data == null:
		return
	var decaying := (
		_phase == GameFlow.Phase.WORKSPACE
		or _phase == GameFlow.Phase.RANSACKED
		or _phase == GameFlow.Phase.HESITATION
	)
	if not decaying:
		return
	var level := clampf(entropy_data.entropy / 100.0, 0.0, 1.0)
	if absf(level - bed_level(SoundBank.DECAY_DRONE)) > 0.01:
		_set_bed(SoundBank.DECAY_DRONE, level, 0.0)


## ----- THE BODY ------------------------------------------------------------------------


func _drive_crash(delta: float) -> void:
	var target := 0.0
	var in_room := apartment == null or apartment.is_active
	if in_room and state_machine != null and state_machine.state_data != null:
		var overload := state_machine.state_data.sensory_overload
		target = clampf((overload - 50.0) / 50.0, 0.0, 1.0)
	crash_intensity = lerpf(crash_intensity, target, 1.0 - exp(-delta * CRASH_SMOOTHING))
	var world := AudioBuses.index(AudioBuses.WORLD)
	if world == -1:
		return
	var lowpass := AudioServer.get_bus_effect(world, AudioBuses.WORLD_LOWPASS)
	var distortion := AudioServer.get_bus_effect(world, AudioBuses.WORLD_DISTORTION)
	if lowpass is AudioEffectLowPassFilter:
		# Exponential sweep: equal steps of intensity sound like equal steps of muffle.
		var ratio := CRASH_MIN_CUTOFF_HZ / AudioBuses.OPEN_CUTOFF_HZ
		lowpass.cutoff_hz = AudioBuses.OPEN_CUTOFF_HZ * pow(ratio, crash_intensity)
	if distortion is AudioEffectDistortion:
		distortion.drive = CRASH_MAX_DRIVE * crash_intensity
		AudioServer.set_bus_effect_enabled(
			world, AudioBuses.WORLD_DISTORTION, crash_intensity > 0.01
		)


func _on_compulsion(active: bool) -> void:
	if active:
		_kill(_heart_tween)
		_heart.start()
	else:
		_heart.stop()


func _drive_compulsion_tempo() -> void:
	if self_soothing == null or not self_soothing.is_in_compulsion():
		return
	if state_machine == null or state_machine.state_data == null:
		return
	var t := clampf((state_machine.state_data.sensory_overload - 80.0) / 20.0, 0.0, 1.0)
	_heart.bpm = lerpf(compulsion_bpm_range.x, compulsion_bpm_range.y, t)


func _on_hesitation() -> void:
	_kill(_heart_tween)
	_heart.bpm = hesitation_bpm_range.x
	_heart.start()
	var duration := 10.0
	if dual_vision != null and not dual_vision.flash_sequence.is_empty():
		duration = 0.0
		for entry in dual_vision.flash_sequence:
			duration += float(entry[1])
	_heart_tween = create_tween()
	_heart_tween.tween_property(_heart, "bpm", hesitation_bpm_range.y, duration)


func _on_visions_ended() -> void:
	_kill(_heart_tween)
	_heart.stop()


## ----- DREAM, AMBULANCE ----------------------------------------------------------------


func _duck_ambience(duck: bool, seconds: float = FADE_SECONDS) -> void:
	var bus := AudioBuses.index(AudioBuses.AMBIENCE)
	if bus == -1:
		return
	var amp := AudioServer.get_bus_effect(bus, AudioBuses.AMBIENCE_DUCK) as AudioEffectAmplify
	if amp == null:
		return
	_kill(_duck_tween)
	_ducked = duck
	var to := DUCK_DB if duck else 0.0
	if seconds <= 0.0:
		amp.volume_db = to
		return
	_duck_tween = create_tween()
	_duck_tween.tween_property(amp, "volume_db", to, seconds)


func _on_transition_completed(now_in_dreamscape: bool) -> void:
	if _ducked:
		_duck_ambience(false)
	if not now_in_dreamscape:
		_stop_siren()


## The violent return cuts straight in, no fade.
func _on_forced_return() -> void:
	_duck_ambience(false, 0.0)
	_stop_siren()


func _start_siren() -> void:
	if _siren.stream == null:
		return
	var cue := bank.cue(SoundBank.SIREN)
	var seconds := ambulance.escalation_seconds if ambulance != null else 4.0
	_siren.volume_db = cue.volume_db - 24.0
	_siren.pitch_scale = 0.94
	_siren.play()
	# Approach: louder and slightly higher (a cheap Doppler) across the escalation.
	_kill(_siren_tween)
	_siren_tween = create_tween().set_parallel()
	_siren_tween.tween_property(_siren, "volume_db", cue.volume_db, seconds)
	_siren_tween.tween_property(_siren, "pitch_scale", 1.06, seconds)


func _stop_siren() -> void:
	_kill(_siren_tween)
	if _siren != null:
		_siren.stop()


func _on_defibrillation() -> void:
	_stop_siren()
	play_one_shot(SoundBank.DEFIB)


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
