class_name PrologueSound
extends Node
## PRESENTATION — the film's sound (Ticket-15 Phase D; Ticket-28). Listens to the
## Prologue and its avenue; owns every player.
##
##   beds       by stage: the town's dusty wind; the city's drone (Cyberwave) over the
##              canyon and the colossus; the street's crowd and drone at night
##   the train  inside: its rumble and the rails clacking; outside: a whoosh as it passes
##   colossus   a sub swell under the reveal; a long tail through its legs
##   voices     a murmur under every subtitle in its speaker's voice: the radio and the
##              PA through a loudspeaker, the vendor in the street; the final call's
##              voice, opening and closing with its tone
##   the street his footsteps on the walk, the car going by, the fight (a shove, a blow)

const WAVE := "res://assets/third_party/fab/cyberwave_audio/Cyberwave/"
const LINE_SECONDS := 4.5
## His stride on the walk, metres (full scale: the avenue isn't a diorama).
const STRIDE := 0.85

@export var prologue: Prologue
@export var avenue: PrologueAvenue
@export var head_call: HeadCall

var _wind: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _rumble: AudioStreamPlayer
var _rails: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _call_voice: AudioStreamPlayer
var _one_shots: Array[AudioStreamPlayer] = []
var _next: int = 0
var _voice_left: float = 0.0
var _call_left: float = 0.0
var _in_call: bool = false
var _last_hero: Vector3
var _walked: float = 0.0
var _walking: bool = false


func _ready() -> void:
	var bank := RealSounds.bank()
	_wind = _bed(ProceduralAudio.cold_draft(), -12.0)
	_drone = _bed(_wav_loop(WAVE + "Sound/Sound - Monol Atmos.wav"), -10.0)
	_crowd = _bed(VoiceSynth.walla(), -14.0)
	_rumble = _bed(_wav_loop(WAVE + "Ambient/Ambient - Amb Sub Dplr.wav"), -6.0)
	_rails = _bed(bank.cue(SoundBank.CARRIAGE).stream, -10.0)
	_voice = _player()
	_call_voice = _player()
	_call_voice.bus = AudioBuses.UI
	for i in 4:
		_one_shots.append(_player())
	VoiceSynth.warm(VoiceSynth.FILM_VOICES)
	if prologue != null:
		prologue.shot_started.connect(_on_shot)
		prologue.line_spoken.connect(_on_line)
		prologue.finished.connect(_fade_all)
	if avenue != null:
		avenue.car_passed.connect(_play.bind(WAVE + "FX/FX - Fx V Streac Low.wav", -8.0))
		avenue.altercation_started.connect(_fight)
	if head_call != null:
		head_call.line_shown.connect(_on_call_line)
		head_call.finished.connect(_on_call_end)


func _process(delta: float) -> void:
	if _voice_left > 0.0:
		_voice_left -= delta
		if _voice_left <= 0.0:
			_voice.stop()
	if _call_left > 0.0:
		_call_left -= delta
		if _call_left <= 0.0:
			_call_voice.stop()
	_drive_steps()


## Each stretch of the film its bed; inside the carriage, the train.
func _on_shot(_index: int, shot_name: String, mode: PrologueScript.Mode) -> void:
	var stage := PrologueLook.stage_for(shot_name)
	var interior := mode == PrologueScript.Mode.INTERIOR or shot_name == "through_train"
	_level(_wind, stage == "town")
	_level(
		_drone,
		stage in ["canyon", "colossus", "descent", "street"],
		1.0 if stage != "street" else 0.5
	)
	_level(_crowd, stage in ["descent", "street"])
	_level(_rumble, interior)
	_level(_rails, interior or shot_name == "tunnel")
	_walking = mode == PrologueScript.Mode.WALK_FOLLOW or mode == PrologueScript.Mode.TOP_TRACK
	if avenue != null:
		_last_hero = avenue.hero_position()
	match shot_name:
		"town_glide", "through_train":
			_play(WAVE + "FX/FX - Fx V Streac Mid.wav", -10.0)
		"colossus_reveal":
			_play(WAVE + "Sub Bass/Sub Bass - Scarlet Sub Dplr.wav", -6.0)
		"through_statue":
			_play(WAVE + "FX/FX - Fx Verber Low.wav", -6.0)


## A subtitle "NAME: text": the murmur in NAME's voice (radio and PA through a speaker).
func _on_line(text: String) -> void:
	if text.is_empty():
		return
	var colon := text.find(":")
	if colon <= 0 or text.begins_with("—"):
		return  # the fight's shouting, unattributed: the crowd carries it
	var speaker := text.substr(0, colon).strip_edges()
	var stream := VoiceSynth.voice(speaker)
	_voice.stream = stream
	_voice.volume_db = -12.0
	_voice.play(randf() * maxf(stream.get_length() - 1.0, 0.0))
	_voice_left = LINE_SECONDS * 0.85


func _on_call_line(_index: int) -> void:
	var line := head_call.current_line()
	if line.is_empty():
		return
	if head_call.is_call() and not _in_call:
		_in_call = true
		_play_cue(SoundBank.CALL_OPEN)
	if str(line[0]) == NightZeroScript.THOUGHT:
		_call_voice.stop()
		return
	var stream := VoiceSynth.voice(str(line[0]), head_call.is_call())
	_call_voice.stream = stream
	_call_voice.volume_db = -12.0
	_call_voice.play(randf() * maxf(stream.get_length() - 1.0, 0.0))
	_call_left = float(line[2]) * 0.85


func _on_call_end() -> void:
	_call_voice.stop()
	if _in_call:
		_in_call = false
		_play_cue(SoundBank.CALL_CLOSE)


## His footsteps on the walk.
func _drive_steps() -> void:
	if not _walking or avenue == null:
		return
	var at := avenue.hero_position()
	var moved := Vector2(at.x - _last_hero.x, at.z - _last_hero.z).length()
	_last_hero = at
	if moved > 2.0:
		return
	_walked += moved
	if _walked >= STRIDE:
		_walked = 0.0
		_play_cue(SoundBank.STEP_CONCRETE)


func _fight() -> void:
	_play_cue(SoundBank.DEFIB, -10.0)  # the shove lands (a heavy punch)
	await get_tree().create_timer(1.0).timeout
	_play(RealSounds.KENNEY + "impact/impactPunch_medium_002.ogg", -6.0)


func _fade_all() -> void:
	for p in [_wind, _drone, _crowd, _rumble, _rails]:
		_level(p, false)


## ----- PLAYERS ---------------------------------------------------------------------------


func _bed(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := _player()
	p.set_meta("db", db)
	p.volume_db = -60.0
	if stream != null:
		p.stream = stream
		p.play()
	return p


func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = AudioBuses.SFX if AudioBuses.index(AudioBuses.SFX) != -1 else &"Master"
	add_child(p)
	return p


func _level(p: AudioStreamPlayer, on: bool, scale: float = 1.0) -> void:
	if p == null or p.stream == null:
		return
	var target: float = float(p.get_meta("db")) + linear_to_db(scale) if on else -60.0
	create_tween().tween_property(p, "volume_db", target, 1.2)


func _play(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := _one_shots[_next]
	_next = (_next + 1) % _one_shots.size()
	p.stream = load(path)
	p.volume_db = db
	p.play()


func _play_cue(cue_name: StringName, db: float = 0.0) -> void:
	var cue := RealSounds.bank().cue(cue_name)
	if cue == null or cue.stream == null:
		return
	var p := _one_shots[_next]
	_next = (_next + 1) % _one_shots.size()
	p.stream = cue.stream
	p.volume_db = cue.volume_db + db
	p.play()


func _wav_loop(path: String) -> AudioStream:
	return RealSounds._loop(path)
