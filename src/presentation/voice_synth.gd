class_name VoiceSynth
extends RefCounted
## PRESENTATION — voices without words (Phase D; the story's calls are voices only, and
## the lines stay subtitles). A small formant babbler: a buzzing source at the speaker's
## pitch, gliding through vowel formants syllable by syllable, with pauses. Rendered once
## per voice as a seamless loop and played under each line for its length.
##
##   VoiceSynth.voice(speaker)      the loop for a speaker (cached), already "placed":
##                                  a call is phone-band, the neighbour muffled by the wall
##   VoiceSynth.walla(seconds)      a party's murmur: several voices, far off
##   VoiceSynth.carriage(seconds)   a metro carriage: rail joints clacking over a rumble

const MIX_RATE := 22050
const LOOP_SECONDS := 4.0
const FADE := 0.2
## Vowel formants (F1, F2) a voice glides between.
const VOWELS: Array[Vector2] = [
	Vector2(730, 1090),
	Vector2(530, 1840),
	Vector2(270, 2290),
	Vector2(570, 840),
	Vector2(440, 1020),
	Vector2(300, 870),
	Vector2(660, 1720),
]
## Per speaker: pitch (Hz), syllables per second, brightness 0..1, "place" (call / room
## / wall / radio), seed. Unlisted speakers get MIDDLE.
const VOICES := {
	"FRIEND": [175.0, 5.6, 0.8, "call", 11],
	"FOCUS+ CARE": [205.0, 4.2, 0.35, "call", 23],
	"NEIGHBOUR": [118.0, 3.4, 0.5, "wall", 31],
	"YOU": [112.0, 4.4, 0.55, "room", 41],
	"VESNA": [228.0, 5.2, 0.75, "room", 53],
	"OKON": [138.0, 5.0, 0.6, "room", 61],
	"LIOR": [198.0, 5.4, 0.7, "room", 71],
	"RADIO": [150.0, 5.8, 0.85, "radio", 83],
	"PA": [128.0, 3.8, 0.4, "radio", 89],
	"SPEAKER": [132.0, 3.6, 0.4, "radio", 97],
	"VENDOR": [160.0, 6.2, 0.7, "room", 101],
	"BOUTIQUE": [210.0, 3.8, 0.4, "radio", 107],
}
const MIDDLE := [150.0, 4.8, 0.6, "room", 7]
## Rendered behind the boot splash: [speaker, on a call]. (The film warms its own.)
const GAME_VOICES: Array = [
	["FRIEND", true],
	["FRIEND", false],
	["FOCUS+ CARE", true],
	["NEIGHBOUR", false],
	["YOU", true],
	["YOU", false],
	["VESNA", false],
	["OKON", false],
	["LIOR", false],
]
const FILM_VOICES: Array = [
	["RADIO", false],
	["PA", false],
	["SPEAKER", false],
	["VENDOR", false],
	["BOUTIQUE", false],
	["FRIEND", true],
	["YOU", true],
]

static var _cache: Dictionary = {}


## The loop for `speaker`, phone-band on a call (`call`), else as the voice is placed.
static func voice(speaker: String, call: bool = false) -> AudioStreamWAV:
	var spec: Array = VOICES.get(speaker, MIDDLE)
	var place: String = "call" if call and spec[3] != "wall" else spec[3]
	var key := "%s|%s" % [speaker, place]
	if not _cache.has(key):
		var buf := _babble(LOOP_SECONDS, spec[0], spec[1], spec[2], int(spec[4]))
		buf = _place(buf, place)
		_cache[key] = _wav(_loop(buf), true)
	return _cache[key]


## Render these voices now (a splash, a black warm-up), not mid-scene.
static func warm(voices: Array) -> void:
	for v: Array in voices:
		voice(str(v[0]), bool(v[1]))


## A party's murmur: five voices at different pitches, softened by distance.
static func walla(seconds: float = 5.0) -> AudioStreamWAV:
	var n := int(MIX_RATE * (seconds + FADE))
	var mix := PackedFloat32Array()
	mix.resize(n)
	var pitches := [120.0, 150.0, 185.0, 215.0, 240.0]
	for k in pitches.size():
		var b := _babble(seconds + FADE, pitches[k], 4.5 + k * 0.4, 0.5, 300 + k)
		for i in n:
			mix[i] += b[i] * 0.32
	mix = _lowpass(mix, 2200.0)
	return _wav(_loop(mix), true)


## A carriage on rails: two clacks per joint every ~1.2 s over a filtered rumble.
static func carriage(seconds: float = 4.8) -> AudioStreamWAV:
	var n := int(MIX_RATE * (seconds + FADE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var y := 0.0
	for i in n:
		y += 0.02 * (randf_range(-1.0, 1.0) - y)
		buf[i] = y * 2.2
	var joint := 1.2
	var t := 0.15
	while t < seconds + FADE:
		for offset in [0.0, 0.11]:
			var start := int((t + offset) * MIX_RATE)
			for j in int(0.06 * MIX_RATE):
				if start + j < n:
					var env := exp(-float(j) / (0.012 * MIX_RATE))
					buf[start + j] += randf_range(-1.0, 1.0) * env * 0.5
		t += joint
	return _wav(_loop(_lowpass(buf, 1800.0)), true)


## ----- SYNTHESIS ----------------------------------------------------------------------


## Syllables: a buzz at `pitch` (with drift and intonation) through two formant filters
## that glide between vowels; a soft consonant hiss at each onset; pauses between phrases.
static func _babble(
	seconds: float, pitch: float, rate: float, bright: float, seed: int
) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := int(MIX_RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var syl_len := int(MIX_RATE / rate)
	var vowel_a: Vector2 = VOWELS[0]
	var vowel_b: Vector2 = VOWELS[1]
	var amp_target := 1.0
	var phrase_left := rng.randi_range(3, 6)  # syllables until a breath
	var f1 := Resonator.new()
	var f2 := Resonator.new()
	var env := 0.0
	for i in n:
		if i % syl_len == 0:
			vowel_a = vowel_b
			vowel_b = VOWELS[rng.randi() % VOWELS.size()]
			# Phrases of 3–6 syllables, then a breath of one or two; within a phrase each
			# syllable a shade louder or softer.
			if phrase_left <= 0:
				amp_target = 0.0
				phrase_left = rng.randi_range(3, 6) + (rng.randi() % 2)
			else:
				amp_target = rng.randf_range(0.6, 1.0)
			phrase_left -= 1
		var k := float(i % syl_len) / syl_len
		var t := float(i) / MIX_RATE
		var f0 := pitch * (1.0 + 0.12 * sin(TAU * 0.6 * t + seed) + 0.05 * sin(TAU * 2.3 * t))
		phase = fmod(phase + f0 / MIX_RATE, 1.0)
		var source := (phase * 2.0 - 1.0) * (0.6 + bright * 0.4)
		var shape := pow(sin(k * PI), 1.6)  # each syllable swells and closes, a gap between
		env += (amp_target * shape - env) * 0.01
		var form := vowel_a.lerp(vowel_b, smoothstep(0.0, 1.0, k))
		var s := f1.step(source, form.x, 6.0) + f2.step(source, form.y, 9.0) * (0.35 + bright * 0.4)
		if k < 0.08:
			s += rng.randf_range(-1.0, 1.0) * 0.25 * bright
		out[i] = s * env * 0.5
	return out


## Where the voice is heard from: a phone line, a room, through a wall, a loudspeaker.
static func _place(buf: PackedFloat32Array, place: String) -> PackedFloat32Array:
	match place:
		"call":
			return _highpass(_lowpass(buf, 3300.0), 320.0)
		"wall":
			return _lowpass(buf, 550.0)
		"radio":
			var r := _highpass(_lowpass(buf, 2800.0), 450.0)
			for i in r.size():
				r[i] = clampf(r[i] * 1.8, -0.6, 0.6) + randf_range(-0.012, 0.012)
			return r
	return buf


static func _lowpass(buf: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * hz / MIX_RATE)
	var out := buf.duplicate()
	var y := 0.0
	for i in out.size():
		y += a * (out[i] - y)
		out[i] = y
	return out


static func _highpass(buf: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var low := _lowpass(buf, hz)
	var out := buf.duplicate()
	for i in out.size():
		out[i] -= low[i]
	return out


## The last FADE seconds crossfaded into the start, so the loop never clicks.
static func _loop(buf: PackedFloat32Array) -> PackedFloat32Array:
	var fade := int(MIX_RATE * FADE)
	var n := buf.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = buf[i]
	for i in fade:
		out[i] = lerpf(buf[n + i], buf[i], float(i) / fade)
	return out


static func _wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := 0.8 / peak
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = buf.size()
	return stream


## A two-pole resonant band-pass (state-variable), for one formant.
class Resonator:
	var low := 0.0
	var band := 0.0

	func step(x: float, hz: float, q: float) -> float:
		var f := 2.0 * sin(PI * minf(hz, 5000.0) / MIX_RATE)
		var damp := 1.0 / q
		low += f * band
		var high := x - low - damp * band
		band += f * high
		return band
