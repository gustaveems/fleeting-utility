class_name ScreenEffects
extends CanvasLayer
## PRESENTATION LAYER — crash-state screen post-effects (Task 4 spec).
##
## Owns a full-screen ColorRect + ShaderMaterial that composites chromatic aberration,
## blur, and a continuous tremor onto the framebuffer. A separate CanvasLayer-offset
## shake impulse fires when the player completes a grid step while in the Crash state,
## simulating the physical jolt of moving under sensory overload.
##
## INTENSITY MAPPING (Task 4 requirement #3)
## -----------------------------------------
##   sensory_overload   0 ——→ 50 ——→ 100
##   effect_intensity   0.0        0.0 ——→ 1.0
##
## Below 50 the screen is perfectly clean (the protagonist is medicated and focused).
## Between 50 and 100 the effects ramp from invisible to full strength. This two-segment
## map means the CA/blur first appear at the exact moment the Crash state triggers, which
## ties the visual feedback to the state machine's `overload_threshold_reached` signal.
##
## SCREEN SHAKE (Task 4 requirement #4)
## -----------------------------------
## Two independent shake channels:
##   1. Shader tremor: a continuous UV offset driven by `sensory_overload`, computed
##      inside the shader from `TIME` — a low-level vibration that sits under CA/blur.
##   2. Node-level impulse: when `_on_movement_completed()` fires and the state is Crash,
##      the CanvasLayer offset jumps randomly and decays over `shake_decay_seconds`,
##      producing a single "body landed heavy" jolt per step.
##
## This class replaces PerceptionPostFX in the Task 4 pipeline. Do not add both to the
## same scene — the two ColorRects would stack and double the effect.

## --- SHADER CODE (complete GLSL, Task 4 requirement #2) --------------------------

const SCREEN_EFFECTS_SHADER := """
shader_type canvas_item;

// Godot 4.2+ form: the screen texture is a hinted sampler2D uniform, NOT the old bare
// `hint_screen_texture;` statement (that syntax fails to parse on 4.7 — confirmed live).
uniform sampler2D screen_texture : hint_screen_texture;

// 0..1 — how deep into the Crash the player is. Mapped from sensory_overload by the
// script: 0 below the threshold, ramps 0→1 above it.
uniform float crash_intensity : hint_range(0.0, 1.0) = 0.0;

// Chromatic aberration scale (UV separation per unit intensity at screen corners).
// Plain uniform defaults take no colon — `: float` is a storage slot for hints only.
uniform float chroma_scale = 0.018;

// Blur radius in UV space at full crash intensity.
uniform float blur_scale = 0.012;

// Continuous tremor amplitude in UV space at full crash. This is the "ambient"
// tremble under CA/blur, separate from the movement-triggered node shake.
uniform float tremor_amplitude = 0.004;

// Shake offset passed from the script for impulse shake (screen-space translation).
// Applied as a UV shift so the shake is additive with the shader tremor.
uniform vec2 shake_offset = vec2(0.0, 0.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 to_centre = vec2(0.5, 0.5) - uv;
	float rim = length(to_centre);

	// --- CONTINUOUS TREMOR: low-level vibration under CA/blur -------------------
	// Procedural noise approximation using two sine waves at incommensurate frequencies.
	// Cheap and deterministic — unlike rand()-based noise it never snaps between frames.
	float tremor_phase = TIME * 40.0;
	float tx = sin(tremor_phase * 1.0 + uv.y * 20.0) * 0.6
		+ sin(tremor_phase * 1.73 + uv.x * 17.0) * 0.4;
	float ty = cos(tremor_phase * 0.71 + uv.y * 19.0) * 0.6
		+ cos(tremor_phase * 1.37 + uv.x * 21.0) * 0.4;
	vec2 tremor = vec2(tx, ty) * tremor_amplitude * crash_intensity;

	// --- CHROMATIC ABERRATION ---------------------------------------------------
	// Split increases with distance from centre so the focal point (the cell the player
	// is standing on) stays sharp, while the edges bleed. This keeps the grid legible.
	float ca_strength = chroma_scale * crash_intensity * (0.25 + rim * 0.85);
	vec2 ca_offset = to_centre * ca_strength;

	vec3 col;
	col.r = texture(screen_texture, uv + tremor + ca_offset + shake_offset).r;
	col.g = texture(screen_texture, uv + tremor + shake_offset).g;
	col.b = texture(screen_texture, uv + tremor - ca_offset + shake_offset).b;

	// --- BLUR (defocus) ---------------------------------------------------------
	// Eight taps at incommensurate angles, radial distance scaled by intensity.
	// At zero intensity the taps land on the same pixel (no blur).
	float blur_radius = blur_scale * crash_intensity;
	if (blur_radius > 0.0004) {
		vec3 acc = vec3(0.0);
		// Angles: 0, 45, 90, 135, 180, 225, 270, 315 degrees
		acc += texture(screen_texture, uv + vec2( 1.0,  0.0) * blur_radius + tremor + shake_offset).rgb;
		acc += texture(screen_texture, uv + vec2( 0.7,  0.7) * blur_radius + tremor + shake_offset).rgb;
		acc += texture(screen_texture, uv + vec2( 0.0,  1.0) * blur_radius + tremor + shake_offset).rgb;
		acc += texture(screen_texture, uv + vec2(-0.7,  0.7) * blur_radius + tremor + shake_offset).rgb;
		acc += texture(screen_texture, uv + vec2(-1.0,  0.0) * blur_radius + tremor + shake_offset).rgb;
		acc += texture(screen_texture, uv + vec2(-0.7, -0.7) * blur_radius + tremor + shake_offset).rgb;
		acc += texture(screen_texture, uv + vec2( 0.0, -1.0) * blur_radius + tremor + shake_offset).rgb;
		acc += texture(screen_texture, uv + vec2( 0.7, -0.7) * blur_radius + tremor + shake_offset).rgb;
		col = mix(col, acc / 8.0, clamp(crash_intensity * 2.0, 0.0, 1.0));
	}

	COLOR = vec4(col, 1.0);
}
"""

## --- CONFIGURATION -------------------------------------------------------------------

## CanvasLayer index. 4 places the effects above the world (layer 0) but below the
## vignette (layer 6 from SoftBoundaryController) so the CA applies before vignette.
@export var fx_layer: int = 4

## Peak chromatic aberration in UV units at full crash intensity.
@export var chroma_scale: float = 0.018

## Blur radius in UV units at full crash intensity.
@export var blur_scale: float = 0.012

## Continuous tremor amplitude in UV units at full crash (ambient tremble under CA).
@export var tremor_amplitude: float = 0.004

## --- SCREEN SHAKE IMPULSE (Task 4 requirement #4) -----------------------------------

## Maximum CanvasLayer position offset during a shake impulse, in pixels.
## This is the "body landed heavy" jolt; distinct from the shader's continuous tremor.
@export var shake_impulse_amplitude: float = 6.0

## How long the shake impulse takes to fully decay, in seconds.
@export var shake_decay_seconds: float = 0.45

## --- DEPENDENCIES -------------------------------------------------------------------

## If assigned, the script reads sensory_overload for the continuous effects.
## The movement impulse also needs to know whether we are in Crash.
@export var state_machine: PlayerStateMachine

## If assigned, the script connects to `movement_completed` for the shake impulse.
## Can be null if only continuous effects are wanted.
@export var player_movement: PlayerMovement

## --- INTERNAL STATE ------------------------------------------------------------------

## Ticket-06: lucid cap. Even at overload 100, the intensity is capped at this value so
## the player can still see. 1.0 = no cap, 0.5 = half intensity (stressed but lucid).
var lucid_cap: float = 1.0

var _color_rect: ColorRect
var _material: ShaderMaterial
var _crash_intensity: float = 0.0
var _shake_remaining: float = 0.0  # seconds left in current shake impulse
var _shake_offset: Vector2 = Vector2.ZERO  # current shake canvas offset (pixels)
var _last_emitted_intensity: float = -1.0

## External override for crash_intensity (-1 = none). Set by the ambulance interception
## to force full-strength CA/blur/tremor regardless of the sensory_overload meter.
var _intensity_override: float = -1.0


## ----- LIFECYCLE ---------------------------------------------------------------------

func _ready() -> void:
	layer = fx_layer
	_build_shader_layer()
	_connect_signals()


func _process(delta: float) -> void:
	_update_intensity(delta)
	_update_shake_impulse(delta)
	_push_shader_params()


## ----- SHADER SETUP ------------------------------------------------------------------

func _build_shader_layer() -> void:
	var shader := Shader.new()
	shader.code = SCREEN_EFFECTS_SHADER

	_material = ShaderMaterial.new()
	_material.shader = shader

	_color_rect = ColorRect.new()
	_color_rect.name = "ScreenEffectsRect"
	_color_rect.material = _material
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_color_rect)


## ----- SIGNAL WIRING -----------------------------------------------------------------

func _connect_signals() -> void:
	if player_movement != null:
		player_movement.movement_completed.connect(_on_movement_completed)


func _on_movement_completed() -> void:
	# Only trigger the impulse when the protagonist is actually in the Crash state.
	# In High-Focus the step is crisp and lands silently.
	if not _is_crashed():
		return
	# Fire a new shake impulse. If one is already in progress, overlap the two instead
	# of replacing — a rapid sequence of steps should feel like a cascade, not a reset.
	_shake_remaining = maxf(_shake_remaining, shake_decay_seconds)
	# Randomise the offset direction so each step lands differently: the body is
	# unsteady, not a metronome.
	var random_dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	_shake_offset = random_dir.normalized() * shake_impulse_amplitude


## ----- INTENSITY (Task 4 requirement #3) ---------------------------------------------

func _update_intensity(_delta: float) -> void:
	var target := _compute_intensity()
	# Smooth ramp so the effects don't pop on/off when crossing the threshold.
	_crash_intensity = lerpf(_crash_intensity, target, 0.08)


## Two-segment map: sensory_overload 0→50 = intensity 0.0, 50→100 = 0.0→1.0.
func _compute_intensity() -> float:
	# External override wins (ambulance interception forces full-strength effects).
	if _intensity_override >= 0.0:
		return _intensity_override
	if state_machine == null or state_machine.state_data == null:
		return 0.0
	var overload := state_machine.state_data.sensory_overload
	if overload <= 50.0:
		return 0.0
	var raw := clampf((overload - 50.0) / 50.0, 0.0, 1.0)
	# Lucid cap: even at overload 100, the player must see clearly.
	return minf(raw, lucid_cap)


## Force crash_intensity to a fixed value, ignoring the sensory_overload meter.
func set_intensity_override(value: float) -> void:
	_intensity_override = clampf(value, 0.0, 1.0)


## Release the override and resume meter-driven intensity.
func clear_intensity_override() -> void:
	_intensity_override = -1.0


## ----- SHAKE IMPULSE ----------------------------------------------------------------

func _update_shake_impulse(delta: float) -> void:
	if _shake_remaining <= 0.0:
		# No active impulse — reset the canvas offset.
		_shake_offset = Vector2.ZERO
		return

	_shake_remaining -= delta
	if _shake_remaining <= 0.0:
		_shake_remaining = 0.0
		_shake_offset = Vector2.ZERO

	# Decay the offset magnitude linearly, keeping the original direction. This produces
	# a clean retraction rather than the jitter bouncing around randomly.
	var decay := _shake_remaining / shake_decay_seconds
	offset = _shake_offset * decay


## ----- SHADER PUSH ------------------------------------------------------------------

func _push_shader_params() -> void:
	if _material == null:
		return
	# Avoid redundant set_shader_parameter calls every frame when nothing changed.
	if is_equal_approx(_crash_intensity, _last_emitted_intensity):
		return
	_last_emitted_intensity = _crash_intensity
	_material.set_shader_parameter("crash_intensity", _crash_intensity)
	_material.set_shader_parameter("chroma_scale", chroma_scale)
	_material.set_shader_parameter("blur_scale", blur_scale)
	_material.set_shader_parameter("tremor_amplitude", tremor_amplitude)


## ----- HELPERS -----------------------------------------------------------------------

func _is_crashed() -> bool:
	if state_machine == null:
		return false
	return state_machine.state_data.is_crashed()