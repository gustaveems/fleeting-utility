class_name RhythmicCuePlayer
extends Node
## PRESENTATION — plays one cue on a beat pattern at a live tempo.
##
## Used for the body's rhythms: the compulsion's pulse (tempo follows overload) and the
## hesitation's heartbeat (tempo climbs through the dual visions). Change `bpm` at any
## time; the next beat respects it.
##
## `pattern` holds beat offsets as fractions of one beat, `accents` the linear gain per
## offset. The default is a heartbeat: lub (1.0) then a softer dub 28% of a beat later.

## Emitted on every pattern hit (index into `pattern`). Tests and VFX sync here.
signal beat(index: int)

@export var cue: SoundCue
@export var bpm: float = 70.0
@export var pattern: PackedFloat32Array = PackedFloat32Array([0.0, 0.28])
@export var accents: PackedFloat32Array = PackedFloat32Array([1.0, 0.6])

var is_running: bool = false

var _beat_time: float = 0.0
var _next_hit: int = 0
var _voices: Array[AudioStreamPlayer] = []
var _voice: int = 0


func _ready() -> void:
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		add_child(p)
		_voices.append(p)


func start() -> void:
	is_running = true
	_beat_time = 0.0
	_next_hit = 0


func stop() -> void:
	is_running = false


func _process(delta: float) -> void:
	if not is_running or pattern.is_empty() or bpm <= 0.0:
		return
	_beat_time += delta * bpm / 60.0
	while _next_hit < pattern.size() and _beat_time >= pattern[_next_hit]:
		_hit(_next_hit)
		_next_hit += 1
	if _beat_time >= 1.0:
		_beat_time -= 1.0
		_next_hit = 0


func _hit(index: int) -> void:
	beat.emit(index)
	if cue == null or cue.stream == null:
		return
	var p := _voices[_voice]
	_voice = (_voice + 1) % _voices.size()
	var accent := accents[index] if index < accents.size() else 1.0
	p.stream = cue.stream
	p.bus = cue.bus
	p.volume_db = cue.volume_db + linear_to_db(maxf(accent, 0.001))
	p.pitch_scale = 1.0 + randf_range(-cue.pitch_jitter, cue.pitch_jitter)
	p.play()
