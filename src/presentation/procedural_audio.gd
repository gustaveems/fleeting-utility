class_name ProceduralAudio
extends RefCounted
## PRESENTATION — placeholder sound synthesis. No audio assets exist yet, so every cue in
## the default SoundBank is generated here as a 16-bit mono AudioStreamWAV.
##
## LOOPS ARE SEAMLESS BY CONSTRUCTION
## ----------------------------------
## Tonal loops snap each frequency to a whole number of cycles per loop, so the waveform
## ends exactly where it began. Noise loops are rendered with a short tail and the tail is
## crossfaded into the head, so the loop point never clicks.
##
## Replace any cue with a real file by assigning its `stream` in a SoundBank .tres; no
## code changes needed.

const MIX_RATE := 22050
const CROSSFADE_SECONDS := 0.25

static var _default_bank: SoundBank

## --- THE DEFAULT BANK ---------------------------------------------------------------


## The placeholder bank. Built once per run (~0.5 s of synthesis), then shared.
static func default_bank() -> SoundBank:
	if _default_bank != null:
		return _default_bank
	var bank := SoundBank.new()
	var amb := AudioBuses.AMBIENCE
	var sfx := AudioBuses.SFX
	bank.cues = {
		SoundBank.ROOM_TONE: SoundCue.make(room_tone(), amb, -14.0),
		SoundBank.DECAY_DRONE: SoundCue.make(decay_drone(), amb, -10.0),
		SoundBank.FLUORESCENT_HUM: SoundCue.make(fluorescent_hum(), amb, -16.0),
		SoundBank.COLD_DRAFT: SoundCue.make(cold_draft(), amb, -8.0),
		SoundBank.VALLEY_AIR: SoundCue.make(valley_air(), amb, -8.0),
		SoundBank.PARK_AIR: SoundCue.make(park_air(), amb, -10.0),
		SoundBank.RUMBLE: SoundCue.make(rumble(), amb, -4.0),
		SoundBank.SIREN: SoundCue.make(siren(), sfx, -6.0),
		SoundBank.HEARTBEAT: SoundCue.make(heartbeat(), sfx, -2.0, 0.03),
		SoundBank.DEFIB: SoundCue.make(defib(), sfx, 0.0),
		SoundBank.TAP: SoundCue.make(tap(), sfx, -8.0, 0.12),
		SoundBank.DENIED: SoundCue.make(denied(), AudioBuses.UI, -10.0),
		SoundBank.STATUE_STING: SoundCue.make(statue_sting(), sfx, -6.0),
		SoundBank.BETRAYAL_STING: SoundCue.make(betrayal_sting(), sfx, -4.0),
		SoundBank.CHIME: SoundCue.make(chime(), sfx, -10.0),
	}
	_default_bank = bank
	return bank


## --- LOOPS (ambient beds) ------------------------------------------------------------


## Two-tone siren, 1080/720 Hz alternating each half second. The phase accumulates
## continuously, so the tone switch is a frequency change, not a click.
static func siren() -> AudioStreamWAV:
	var n := MIX_RATE * 2
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += (1080.0 if fmod(t, 1.0) < 0.5 else 720.0) / MIX_RATE
		buf[i] = sin(phase * TAU) * 0.4
	return _wav(buf, true)


## Fluorescent tube: 120 Hz mains buzz with odd harmonics, slightly clipped.
static func fluorescent_hum() -> AudioStreamWAV:
	var buf := _tones(1.0, [[120.0, 0.35], [240.0, 0.12], [360.0, 0.10], [600.0, 0.05]])
	for i in buf.size():
		buf[i] = clampf(buf[i] * 1.4, -0.45, 0.45)
	return _wav(buf, true)


## Apartment room tone: dull low noise plus a faint 50 Hz fridge hum.
static func room_tone() -> AudioStreamWAV:
	var noise := _noise(4.0, 380.0, 0.22, 0.0, 0.0)
	var hum := _tones(4.0, [[50.0, 0.05], [100.0, 0.02]])
	return _wav(_mix(noise, hum), true)


## Decay: a beating, dissonant low drone. Its level follows entropy.
static func decay_drone() -> AudioStreamWAV:
	return _wav(_tones(8.0, [[55.0, 0.16], [58.25, 0.14], [77.75, 0.08], [116.5, 0.05]]), true)


## Cold draft through a broken window: band-limited noise in slow gusts.
static func cold_draft() -> AudioStreamWAV:
	var hi := _noise(6.0, 1400.0, 0.5, 0.33, 0.8)
	var lo := _noise(6.0, 260.0, 0.5, 0.33, 0.8)
	var buf := PackedFloat32Array()
	buf.resize(hi.size())
	for i in buf.size():
		buf[i] = (hi[i] - lo[i]) * 0.8
	return _wav(buf, true)


## Valley: soft wind under a warm A-minor pad. The dream's opposite of the apartment.
static func valley_air() -> AudioStreamWAV:
	var wind := _noise(8.0, 650.0, 0.25, 0.125, 0.6)
	var pad := _tones(8.0, [[110.0, 0.06], [164.75, 0.045], [220.0, 0.04], [261.625, 0.03]])
	return _wav(_mix(wind, pad), true)


## Corporate park: bright, clean air and a sterile major triad (pseudo-nature).
static func park_air() -> AudioStreamWAV:
	var air := _noise(6.0, 2200.0, 0.12, 0.16667, 0.3)
	var pad := _tones(6.0, [[261.625, 0.035], [329.625, 0.03], [392.0, 0.025]])
	return _wav(_mix(air, pad), true)


## Hesitation rumble: sub-bass sine under very low noise.
static func rumble() -> AudioStreamWAV:
	var sub := _tones(4.0, [[32.0, 0.35], [48.0, 0.15]])
	var noise := _noise(4.0, 90.0, 0.6, 0.5, 0.5)
	return _wav(_mix(sub, noise), true)


## --- ONE-SHOTS ------------------------------------------------------------------------


## Heartbeat thump: 60 Hz falling to 38 Hz, fast decay. Also the compulsion pulse.
static func heartbeat() -> AudioStreamWAV:
	return _wav(_drop(0.28, 60.0, 38.0, 14.0, 0.85, 0.05), false)


## Defibrillation jolt: a hard low hit plus a crack of noise.
static func defib() -> AudioStreamWAV:
	var hit := _drop(0.6, 90.0, 30.0, 7.0, 0.6, 0.0)
	var crack := _burst(0.6, 0.12, 0.35)
	return _wav(_mix(hit, crack), false)


## Fidget tap: a short dry click.
static func tap() -> AudioStreamWAV:
	var click := _drop(0.08, 1900.0, 1400.0, 70.0, 0.35, 0.0)
	return _wav(_mix(click, _burst(0.08, 0.01, 0.25)), false)


## Denied: dull low blip when an interaction is locked.
static func denied() -> AudioStreamWAV:
	return _wav(_drop(0.18, 300.0, 240.0, 22.0, 0.4, 0.0), false)


## Statue reveal: a slow A-minor(add9) swell and release.
static func statue_sting() -> AudioStreamWAV:
	return _wav(_swell(3.0, [220.0, 261.625, 329.625, 493.875], 0.9, 0.12), false)


## Betrayal: a low dissonant cluster.
static func betrayal_sting() -> AudioStreamWAV:
	return _wav(_swell(2.5, [73.4, 77.8, 110.0, 155.6], 0.25, 0.16), false)


## Memory anchor / loop chime: a bell (fundamental + inharmonic partial).
static func chime() -> AudioStreamWAV:
	var n := int(MIX_RATE * 2.0)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := exp(-t * 2.2)
		buf[i] = (sin(TAU * 880.0 * t) * 0.25 + sin(TAU * 2428.8 * t) * 0.08) * env
	return _wav(buf, false)


## --- BUILDING BLOCKS ------------------------------------------------------------------


## Sum of sines over `seconds`; each frequency snapped to whole cycles so it loops.
static func _tones(seconds: float, partials: Array) -> PackedFloat32Array:
	var n := int(MIX_RATE * seconds)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for p in partials:
		var freq: float = roundf(float(p[0]) * seconds) / seconds
		var amp: float = p[1]
		var step := TAU * freq / MIX_RATE
		for i in n:
			buf[i] += sin(step * i) * amp
	return buf


## One-pole low-passed white noise, optionally amplitude-modulated, crossfaded to loop.
## `mod_hz` is snapped to whole cycles; `mod_depth` 0..1.
static func _noise(
	seconds: float, cutoff_hz: float, amp: float, mod_hz: float, mod_depth: float
) -> PackedFloat32Array:
	var n := int(MIX_RATE * seconds)
	var fade := int(MIX_RATE * CROSSFADE_SECONDS)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var alpha := 1.0 - exp(-TAU * cutoff_hz / MIX_RATE)
	var y := 0.0
	# Gain-compensate the one-pole filter so different cutoffs land at similar loudness.
	var gain := 1.0 / sqrt(maxf(alpha, 0.0001))
	for i in raw.size():
		y += alpha * (randf_range(-1.0, 1.0) - y)
		raw[i] = y * gain * amp * 0.35
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		buf[i] = raw[i]
	for i in fade:
		var w := float(i) / fade
		buf[i] = lerpf(raw[n + i], raw[i], w)
	if mod_depth > 0.0 and mod_hz > 0.0:
		var f := roundf(mod_hz * seconds) / seconds
		for i in n:
			var m := 0.5 + 0.5 * sin(TAU * f * i / MIX_RATE)
			buf[i] *= 1.0 - mod_depth * m
	return buf


## Sine with an exponential pitch drop and decay, plus a soft attack.
static func _drop(
	seconds: float, f0: float, f1: float, decay: float, amp: float, attack: float
) -> PackedFloat32Array:
	var n := int(MIX_RATE * seconds)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var freq := f1 + (f0 - f1) * exp(-t * 18.0)
		phase += freq / MIX_RATE
		var env := exp(-t * decay)
		if attack > 0.0 and t < attack:
			env *= t / attack
		buf[i] = sin(phase * TAU) * env * amp
	return buf


## White-noise burst of `length` seconds inside a buffer of `seconds`.
static func _burst(seconds: float, length: float, amp: float) -> PackedFloat32Array:
	var n := int(MIX_RATE * seconds)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var m := int(MIX_RATE * length)
	for i in mini(m, n):
		buf[i] = randf_range(-1.0, 1.0) * amp * (1.0 - float(i) / m)
	return buf


## Chord with an attack of `attack_frac` of its length, then a linear release.
static func _swell(
	seconds: float, freqs: Array, attack_frac: float, amp: float
) -> PackedFloat32Array:
	var n := int(MIX_RATE * seconds)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var peak := int(n * attack_frac)
	for i in n:
		var env := float(i) / peak if i < peak else 1.0 - float(i - peak) / maxf(n - peak, 1)
		var s := 0.0
		for f in freqs:
			s += sin(TAU * float(f) * i / MIX_RATE)
		buf[i] = s * amp * env
	return buf


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	for i in mini(a.size(), b.size()):
		out[i] += b[i]
	return out


static func _wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buf.size()
	return stream
