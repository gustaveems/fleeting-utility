class_name SoundBank
extends Resource
## DATA — every sound the game uses, by name.
##
## AudioDirector asks for cues by the names below. ProceduralAudio.default_bank() builds
## the placeholder bank; a designer-authored .tres with real recordings replaces it via
## AudioDirector.bank.

## Ambient beds (looping).
const ROOM_TONE := &"room_tone"
const DECAY_DRONE := &"decay_drone"
const FLUORESCENT_HUM := &"fluorescent_hum"
const COLD_DRAFT := &"cold_draft"
const VALLEY_AIR := &"valley_air"
const PARK_AIR := &"park_air"
const RUMBLE := &"rumble"
const SIREN := &"siren"

## One-shots.
const HEARTBEAT := &"heartbeat"
const DEFIB := &"defib"
const TAP := &"tap"
const DENIED := &"denied"
const STATUE_STING := &"statue_sting"
const BETRAYAL_STING := &"betrayal_sting"
const CHIME := &"chime"
const BRUSH := &"brush"

@export var cues: Dictionary[StringName, SoundCue] = {}

## Consulted for names this bank lacks, so a partial bank of real recordings is fine.
## AudioDirector sets it to the procedural placeholder bank.
var fallback: SoundBank


func cue(cue_name: StringName) -> SoundCue:
	if cues.has(cue_name):
		return cues[cue_name]
	if fallback != null:
		return fallback.cue(cue_name)
	push_warning("SoundBank: no cue named '%s'" % cue_name)
	return null
