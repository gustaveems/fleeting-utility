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
## Phase D: the carriage on its rails, the rooftop's party (murmur, and the music from its
## speakers).
const CARRIAGE := &"carriage"
const PARTY := &"party"
const PARTY_MUSIC := &"party_music"

## One-shots.
const HEARTBEAT := &"heartbeat"
const DEFIB := &"defib"
const TAP := &"tap"
const DENIED := &"denied"
const STATUE_STING := &"statue_sting"
const BETRAYAL_STING := &"betrayal_sting"
const CHIME := &"chime"
const BRUSH := &"brush"
## Phase D: footsteps by surface, the in-head call's line opening and closing, a glass.
const STEP_TILE := &"step_tile"
const STEP_GRASS := &"step_grass"
const STEP_WOOD := &"step_wood"
const STEP_CONCRETE := &"step_concrete"
const STEP_CARPET := &"step_carpet"
const CALL_OPEN := &"call_open"
const CALL_CLOSE := &"call_close"
const GLASS := &"glass"
const DOOR := &"door"

## Music (Phase D; sparse): the dream, the realisation, the end of a cycle.
const MUSIC_DREAM := &"music_dream"
const MUSIC_REVEAL := &"music_reveal"
const MUSIC_END := &"music_end"

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
