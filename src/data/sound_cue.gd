class_name SoundCue
extends Resource
## DATA — one named sound: what to play, on which bus, how loud, how varied.
##
## The default SoundBank fills `stream` with ProceduralAudio placeholders. Swapping in a
## real recording is an Inspector edit on a SoundBank .tres; no code changes.

@export var stream: AudioStream
@export var bus: StringName = AudioBuses.SFX
@export_range(-60.0, 12.0) var volume_db: float = 0.0

## Random pitch spread per play (0.05 = ±5%), so repeated one-shots don't machine-gun.
@export_range(0.0, 0.5) var pitch_jitter: float = 0.0


static func make(
	cue_stream: AudioStream, cue_bus: StringName, db: float = 0.0, jitter: float = 0.0
) -> SoundCue:
	var cue := SoundCue.new()
	cue.stream = cue_stream
	cue.bus = cue_bus
	cue.volume_db = db
	cue.pitch_jitter = jitter
	return cue
