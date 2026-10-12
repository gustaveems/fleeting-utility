class_name AtmosphereController
extends Node
## PRESENTATION — lighting and atmosphere degradation driven by WorkspaceEntropy.
##
## Maps entropy (0..100) onto the room's lighting rig:
##
##   entropy 0   (clean)    bright neutral ambient, thin fog, full key light, no contrast push
##   entropy 100 (decayed)  dim sickly green-yellow ambient, heavy fog, dying key light,
##                          high contrast, near-black-green background
##
## ASYMMETRIC RESPONSE (requirements #3 and #5, reconciled)
## --------------------------------------------------------
## Rising entropy CREEPS: _process() lerps the smoothed factor `_t` toward the target at
## `decay_smoothing` (~1.4 s to close 95% of the gap). The room darkens around the player
## while they work — slow enough to be subliminal, which is the claustrophobia pillar.
##
## Falling entropy SNAPS: the `entropy_changed` signal handler sets `_t` immediately when
## entropy drops. Cleaning the room must give instant visual relief — if the light took
## seconds to brighten after the player cleaned, the reward loop would feel broken.
##
## This is a deliberate design choice, not an implementation shortcut: decay is ambient
## dread (slow), cleaning is earned relief (instant).
##
## FLICKERING LAMP
## ---------------
## Above `flicker_onset` (50.0), the OmniLight3D (dying desk lamp) gains:
##   1. a subtle sine wobble between dropouts (the filament struggling), and
##   2. random full dropouts to 0.0 energy, probability per second scaling with how far
##      past the onset entropy is, duration 0.04–0.14 s. At entropy 100 the lamp fails
##      roughly twice a second — the infrastructure is giving out.
## Dropouts use randf() gated by per-second probability rather than a Timer node, so the
## flicker rate scales with frame time correctly and needs no extra scene nodes.

## --- SIGNALS ---------------------------------------------------------------------------

## Lighting mode. NORMAL = entropy-driven decay; CLINICAL = post-climax harsh white;
## SUBDUED = post-loop dim, flat, defeated silence; BROKEN = post-betrayal flickering,
## one light dead, cold draft. Exactly one is active at a time.
enum Mode { NORMAL, CLINICAL, SUBDUED, BROKEN }

## --- ENDPOINT TUNING (constants: the two ends of the decay curve) --------------------

## Ambient light: warm neutral grey → sickly green-yellow.
const CLEAN_AMBIENT_COLOR := Color(0.85, 0.83, 0.80)
const DECAYED_AMBIENT_COLOR := Color(0.38, 0.42, 0.22)
const CLEAN_AMBIENT_ENERGY := 0.45
const DECAYED_AMBIENT_ENERGY := 0.10

## Fog: thin warm haze → heavy sickly murk.
const CLEAN_FOG_COLOR := Color(0.30, 0.28, 0.26)
const DECAYED_FOG_COLOR := Color(0.16, 0.17, 0.10)
const CLEAN_FOG_DENSITY := 0.004
const DECAYED_FOG_DENSITY := 0.085
## Volumetric fog integrates scattering along the whole view path, so its density
## budget is far smaller than plain fog's: 0.18/m over a 45 m far plane is an opaque
## wall (confirmed on first real render — the whole frame washed to tan). Even 0.045
## eats most of the background; this ceiling keeps the decayed room readable.
const CLEAN_VOLUMETRIC_DENSITY := 0.004
const DECAYED_VOLUMETRIC_DENSITY := 0.022

## Key light dies as the room decays.
const CLEAN_KEY_ENERGY := 1.15
const DECAYED_KEY_ENERGY := 0.30

## Background: near-black neutral → near-black with a green cast.
const CLEAN_BACKGROUND_COLOR := Color(0.045, 0.045, 0.05)
const DECAYED_BACKGROUND_COLOR := Color(0.03, 0.035, 0.02)

## Contrast push: 1.0 (neutral) → 1.4 (harsh, crushed shadows — "high contrast").
const CLEAN_CONTRAST := 1.0
const DECAYED_CONTRAST := 1.4

## Lamp dims overall as it dies, independent of flicker dropouts.
const CLEAN_LAMP_DIM := 1.0
const DECAYED_LAMP_DIM := 0.55

## --- CLINICAL / POST-CLIMAX ENDPOINTS (Ticket-06 / Ticket-07 Task 3) -------------------
## A third, separate look: not warm-clean and not sickly-decayed, but harsh, cold and
## over-lit. The room stops being a home and becomes a monitored space.
##
## Ticket-07 Task 3: energies have been dialled back from the original blinding values;
## tone mapping (ACES) and an exposure cut to 0.8 prevent the blowout. Shadows are ON
## with a tuned bias so the room retains physical depth — it reads cold, not flat.

## Ambient: cold desaturated blue-grey, moderate energy — the overexposed white wash of
## the original clinical look is gone.
const CLINICAL_AMBIENT_COLOR := Color(0.7, 0.75, 0.8)
const CLINICAL_AMBIENT_ENERGY := 0.3

## Key: bright but not blinding, and SHADOWLESS. The flat, sourceless light of an
## operating theatre makes the room creepier (decision, 2026-10-12).
const CLINICAL_KEY_ENERGY := 1.2
const CLINICAL_KEY_COLOR := Color(0.85, 0.90, 1.0)

## Tone mapping + exposure (Ticket-07 Task 3). ACES clamps highlights gracefully where
## Filmic left the old clinical value blowing to pure white. Exposure 0.8 is a one-stop
## pull that brings the whole room into readable range.
const CLINICAL_TONE_MAPPER := Environment.TONE_MAPPER_ACES
const CLINICAL_TONEMAP_EXPOSURE := 0.8

## Background + fog: sterile near-white, no murk at all.
const CLINICAL_BACKGROUND_COLOR := Color(0.55, 0.60, 0.68)
const CLINICAL_SATURATION := 0.55  # desaturated — colour is a memory, not a present

## --- SUBDUED / POST-LOOP ENDPOINTS (Ticket-07) ----------------------------------------
## The fourth look: after the clinical seizure passes, the room settles into a dim,
## defeated hush. Sickly desaturated grey-green — not the warm decay of entropy, but
## drained of colour and life. The lamp is dead and stays dead.

const SUBDUED_AMBIENT_COLOR := Color(0.35, 0.38, 0.30)
const SUBDUED_AMBIENT_ENERGY := 0.1
const SUBDUED_KEY_ENERGY := 0.5
const SUBDUED_KEY_COLOR := Color(0.52, 0.56, 0.48)
const SUBDUED_BACKGROUND_COLOR := Color(0.04, 0.04, 0.05)
const SUBDUED_FOG_DENSITY := 0.002
const SUBDUED_VOLUMETRIC_DENSITY := 0.003

## --- BROKEN / POST-BETRAYAL ENDPOINTS (Ticket-08) --------------------------------------
## The fifth look: after the walk, the apartment has been ransacked. The key light
## flickers erratically (not the smooth sine wobble of entropy decay — hard, random
## dropouts), the desk lamp is completely dead, and a cold draft seeps in. The room
## is no longer a home or a clinic; it is a crime scene.

const BROKEN_AMBIENT_COLOR := Color(0.28, 0.30, 0.35)
const BROKEN_AMBIENT_ENERGY := 0.15
const BROKEN_KEY_ENERGY := 0.6
const BROKEN_KEY_COLOR := Color(0.55, 0.58, 0.65)
const BROKEN_BACKGROUND_COLOR := Color(0.03, 0.03, 0.04)
const BROKEN_FOG_DENSITY := 0.003
const BROKEN_VOLUMETRIC_DENSITY := 0.004

## Flicker parameters for the broken key light: random dropouts, not sine wobble.
const BROKEN_FLICKER_RATE := 2.5  # dropouts per second
const BROKEN_FLICKER_DURATION := 0.08  # seconds each dropout lasts

## --- REFERENCES (requirement #1) ------------------------------------------------------

@export var entropy_data: WorkspaceEntropyData
## The APARTMENT's Environment resource, written directly. Never go through
## WorldEnvironment.environment: while the valley or park is active, that holds THEIR
## resource, and the apartment look used to bleed into them.
@export var environment: Environment
@export var key_light: DirectionalLight3D

## The dying desk lamp. Null-safe: if absent, only the environment degrades.
@export var lamp: OmniLight3D

## --- TUNING ---------------------------------------------------------------------------

## Seconds to close ~95% of the atmosphere gap when entropy RISES (creep).
@export var decay_smoothing: float = 1.4

## Entropy value above which the lamp starts to flicker.
@export var flicker_onset: float = 50.0

## --- INTERNAL STATE -------------------------------------------------------------------

var _mode: Mode = Mode.NORMAL

## Smoothed 0..1 decay factor. Everything visual derives from this one number.
var _t: float = 0.0
var _last_entropy: float = 0.0

## Lamp flicker state.
var _lamp_base_energy: float = 1.0
var _drop_timer: float = 0.0
var _flicker_phase: float = 0.0

## Broken-mode key light flicker state (Ticket-08).
var _broken_flicker_timer: float = 0.0

## Key-light authored values, captured so disabling clinical mode can restore them.
var _key_base_energy: float = 1.0
var _key_base_color: Color = Color.WHITE
var _key_base_shadow: bool = true
var _key_base_bias: float = 0.0

## ----- LIFECYCLE ----------------------------------------------------------------------


func _ready() -> void:
	if entropy_data == null:
		push_warning("AtmosphereController: entropy_data is null, atmosphere will not decay.")
		return
	if environment == null:
		push_warning("AtmosphereController: environment missing, only lights will degrade.")
	if lamp != null:
		# Capture the authored lamp brightness so decay and flicker scale from it,
		# rather than from a hardcoded 1.0.
		_lamp_base_energy = lamp.light_energy
	if key_light != null:
		_key_base_energy = key_light.light_energy
		_key_base_color = key_light.light_color
		_key_base_shadow = key_light.shadow_enabled
		_key_base_bias = key_light.shadow_bias
	_last_entropy = entropy_data.entropy
	_t = entropy_data.entropy / 100.0
	entropy_data.entropy_changed.connect(_on_entropy_changed)
	_apply_atmosphere()


func _process(delta: float) -> void:
	if entropy_data == null:
		return

	# BROKEN mode: flicker the key light, skip entropy creep entirely.
	if _mode == Mode.BROKEN:
		_update_broken_flicker(delta)
		return

	# Clinical and subdued modes fully own the lighting; entropy creep and lamp flicker
	# are inert.
	if _mode != Mode.NORMAL:
		return

	# Requirement #3: smooth lerp toward the current entropy percentage.
	# The creep only applies when entropy is rising; drops were already snapped by the
	# signal handler (see class doc).
	var target := clampf(entropy_data.entropy / 100.0, 0.0, 1.0)
	if target > _t:
		var weight := 1.0 - exp(-delta / maxf(decay_smoothing, 0.001))
		_t = lerpf(_t, target, weight)
		_apply_atmosphere()

	_update_lamp(delta)


## ----- SIGNAL REACTION (requirement #5) ------------------------------------------------


func _on_entropy_changed(new_entropy: float) -> void:
	# Cleaning (entropy dropping) reacts INSTANTLY — the light brightens on the same
	# frame the clutter clears, so the reward is felt immediately.
	if new_entropy < _last_entropy:
		_t = clampf(new_entropy / 100.0, 0.0, 1.0)
		_apply_atmosphere()
	_last_entropy = new_entropy


## ----- CLINICAL MODE (Ticket-06) ------------------------------------------------------


## Toggle the post-climax clinical look. When enabled, entropy lighting is fully
## overridden: harsh cold ambient, blinding shadowless key, lamp dead, sterile fog-free
## background. (Its fluorescent hum is AudioDirector's job, keyed off GameFlow.)
func set_clinical_mode(enabled: bool) -> void:
	var target := Mode.CLINICAL if enabled else Mode.NORMAL
	if _mode == target:
		return
	_mode = target
	_apply_atmosphere()
	if lamp != null:
		_update_lamp(0.0)


## Read-only query: is clinical mode currently active?
func is_clinical_mode() -> bool:
	return _mode == Mode.CLINICAL


## Read-only query: is the post-loop subdued mode currently active?
func is_subdued_mode() -> bool:
	return _mode == Mode.SUBDUED


## Ticket-07: post-loop subdued/defeated lighting. Dim, flat, no flicker — dead silence.
## Calling this clears any clinical override.
func set_subdued_mode(enabled: bool) -> void:
	var target := Mode.SUBDUED if enabled else Mode.NORMAL
	if _mode == target:
		return
	_mode = target
	_apply_atmosphere()
	if lamp != null:
		_update_lamp(0.0)


## Ticket-08: post-betrayal broken state. Flickering key light, dead lamp, cold draft.
## Calling this clears any clinical or subdued override.
func set_broken_mode(enabled: bool) -> void:
	var target := Mode.BROKEN if enabled else Mode.NORMAL
	if _mode == target:
		return
	_mode = target
	if enabled:
		_broken_flicker_timer = 0.0
	_apply_atmosphere()
	if lamp != null:
		_update_lamp(0.0)


## Read-only query: is the post-betrayal broken mode currently active?
func is_broken_mode() -> bool:
	return _mode == Mode.BROKEN


## ----- ATMOSPHERE APPLICATION ----------------------------------------------------------


func _apply_atmosphere() -> void:
	if environment != null:
		var env := environment
		match _mode:
			Mode.CLINICAL:
				env.ambient_light_color = CLINICAL_AMBIENT_COLOR
				env.ambient_light_energy = CLINICAL_AMBIENT_ENERGY
				env.fog_density = 0.0
				env.volumetric_fog_density = 0.0
				env.background_color = CLINICAL_BACKGROUND_COLOR
				env.adjustment_enabled = true
				env.adjustment_contrast = 1.0
				env.adjustment_saturation = CLINICAL_SATURATION
				env.tonemap_mode = CLINICAL_TONE_MAPPER
				env.tonemap_exposure = CLINICAL_TONEMAP_EXPOSURE
			Mode.SUBDUED:
				env.ambient_light_color = SUBDUED_AMBIENT_COLOR
				env.ambient_light_energy = SUBDUED_AMBIENT_ENERGY
				env.fog_density = SUBDUED_FOG_DENSITY
				env.volumetric_fog_density = SUBDUED_VOLUMETRIC_DENSITY
				env.background_color = SUBDUED_BACKGROUND_COLOR
				env.fog_light_color = Color(0.18, 0.18, 0.20)
				env.adjustment_enabled = false
			Mode.BROKEN:
				env.ambient_light_color = BROKEN_AMBIENT_COLOR
				env.ambient_light_energy = BROKEN_AMBIENT_ENERGY
				env.fog_density = BROKEN_FOG_DENSITY
				env.volumetric_fog_density = BROKEN_VOLUMETRIC_DENSITY
				env.background_color = BROKEN_BACKGROUND_COLOR
				env.fog_light_color = Color(0.15, 0.16, 0.18)
				env.adjustment_enabled = false
				env.tonemap_exposure = 1.0
			_:
				env.ambient_light_color = CLEAN_AMBIENT_COLOR.lerp(DECAYED_AMBIENT_COLOR, _t)
				env.ambient_light_energy = lerpf(CLEAN_AMBIENT_ENERGY, DECAYED_AMBIENT_ENERGY, _t)
				env.fog_light_color = CLEAN_FOG_COLOR.lerp(DECAYED_FOG_COLOR, _t)
				env.fog_density = lerpf(CLEAN_FOG_DENSITY, DECAYED_FOG_DENSITY, _t)
				env.volumetric_fog_density = lerpf(
					CLEAN_VOLUMETRIC_DENSITY, DECAYED_VOLUMETRIC_DENSITY, _t
				)
				env.background_color = CLEAN_BACKGROUND_COLOR.lerp(DECAYED_BACKGROUND_COLOR, _t)
				env.adjustment_enabled = _t > 0.01
				env.adjustment_contrast = lerpf(CLEAN_CONTRAST, DECAYED_CONTRAST, _t)
				env.adjustment_saturation = 1.0
				env.tonemap_exposure = 1.0

	if key_light != null:
		match _mode:
			Mode.CLINICAL:
				key_light.light_energy = CLINICAL_KEY_ENERGY
				key_light.light_color = CLINICAL_KEY_COLOR
				key_light.shadow_enabled = false
			Mode.SUBDUED:
				key_light.light_energy = SUBDUED_KEY_ENERGY
				key_light.light_color = SUBDUED_KEY_COLOR
				key_light.shadow_enabled = _key_base_shadow
				key_light.shadow_bias = _key_base_bias
			Mode.BROKEN:
				# Key light energy is driven by the flicker in _process(); set the base
				# here so the first frame after mode switch is not black.
				key_light.light_energy = BROKEN_KEY_ENERGY
				key_light.light_color = BROKEN_KEY_COLOR
				key_light.shadow_enabled = true
				key_light.shadow_bias = _key_base_bias
			_:
				key_light.light_energy = lerpf(CLEAN_KEY_ENERGY, DECAYED_KEY_ENERGY, _t)
				key_light.light_color = _key_base_color
				key_light.shadow_enabled = _key_base_shadow
				key_light.shadow_bias = _key_base_bias


## ----- FLICKERING LAMP (requirement #4) -------------------------------------------------


func _update_lamp(delta: float) -> void:
	if lamp == null or entropy_data == null:
		return

	# Clinical or subdued mode kills the desk lamp entirely — fluorescent or dead silence.
	if _mode != Mode.NORMAL:
		lamp.light_energy = 0.0
		return

	var overload_past_onset := clampf(
		(entropy_data.entropy - flicker_onset) / (100.0 - flicker_onset), 0.0, 1.0
	)

	# Mid-dropout: hold at zero until the dropout window closes.
	if _drop_timer > 0.0:
		_drop_timer -= delta
		lamp.light_energy = 0.0
		return

	# Roll for a new dropout. Probability per second scales with how far past the onset
	# entropy is: at entropy 100 that is ~1.8 dropouts/second.
	if overload_past_onset > 0.0 and randf() < overload_past_onset * 1.8 * delta:
		_drop_timer = randf_range(0.04, 0.14)
		lamp.light_energy = 0.0
		return

	# Between dropouts: subtle sine wobble (the filament struggling) plus the overall
	# decay dim. Wobble amplitude only exists past the onset.
	_flicker_phase += delta * (3.0 + 9.0 * overload_past_onset)
	var wobble := 1.0 - 0.15 * overload_past_onset * (0.5 + 0.5 * sin(_flicker_phase * 2.1))
	var dim := lerpf(CLEAN_LAMP_DIM, DECAYED_LAMP_DIM, _t)
	lamp.light_energy = _lamp_base_energy * wobble * dim


## ----- BROKEN KEY LIGHT FLICKER (Ticket-08) ---------------------------------------------


## Random hard dropouts on the key light — not the smooth sine wobble of entropy decay.
## The light stutters like a failing fluorescent tube in a crime scene.
func _update_broken_flicker(delta: float) -> void:
	if key_light == null:
		return

	# Mid-dropout: hold at zero until the dropout window closes.
	if _broken_flicker_timer > 0.0:
		_broken_flicker_timer -= delta
		key_light.light_energy = 0.0
		return

	# Roll for a new dropout. BROKEN_FLICKER_RATE dropouts per second on average.
	if randf() < BROKEN_FLICKER_RATE * delta:
		_broken_flicker_timer = BROKEN_FLICKER_DURATION
		key_light.light_energy = 0.0
		return

	# Between dropouts: steady at the broken base energy.
	key_light.light_energy = BROKEN_KEY_ENERGY
