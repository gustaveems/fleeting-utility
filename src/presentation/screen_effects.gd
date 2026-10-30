class_name ScreenEffects
extends CanvasLayer
## PRESENTATION LAYER — the single screen-space post pass (Ticket-04 Task 4, merged and
## extended in Ticket-11).
##
## One full-screen ColorRect + ShaderMaterial composites, in order:
##   1. motion     continuous crash tremor + the step-shake impulse (UV offsets)
##   2. distortion chromatic aberration + defocus blur (crash)
##   3. High-Focus the medicated gaze: contrast lift + edge wires (GAME_SPEC 1.A)
##   4. vignette   soft boundary: darkens as the player nears the room edge, pulses
##                 when pressed against it, and closes in slightly under crash
##   5. grain      faint film grain under crash
##
## WHY ONE PASS
## ------------
## The vignette used to be a second screen-reading pass (SoftBoundaryController, layer 6).
## Merged here it costs one fewer full-screen read, and every effect answers to the
## same two accessibility scales (T13):
##   motion_scale      tremor + shake (vestibular comfort)
##   distortion_scale  CA + blur (legibility)
##
## INTENSITY MAPPING
## -----------------
##   sensory_overload   0 ——→ 50 ——→ 100
##   crash_intensity    0.0        0.0 ——→ 1.0   (capped by lucid_cap post-climax)
## High-Focus (chemical > 0.7 and not crashed) eases focus_intensity toward 1.
##
## SHAKE
## -----
## A step that lands while crashed (PlayerMovement.movement_completed) kicks a random
## impulse that decays over shake_decay_seconds. It is a UV offset in the shader. The
## CanvasLayer itself never moves: moving it exposed an uncovered strip at the edge.

const SCREEN_EFFECTS_SHADER := """
shader_type canvas_item;

// Godot 4.2+ form: a hinted sampler2D uniform, not the old bare `hint_screen_texture;`.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float crash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float focus_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float edge_proximity : hint_range(0.0, 1.0) = 0.0;

uniform float chroma_scale = 0.018;
uniform float blur_scale = 0.012;
uniform float tremor_amplitude = 0.004;
uniform float grain_scale = 0.03;
uniform vec2 shake_offset = vec2(0.0, 0.0);

// Accessibility (T13): 0 = off, 1 = authored strength.
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;
uniform float distortion_scale : hint_range(0.0, 1.0) = 1.0;

uniform float vignette_inner = 0.30;
uniform float vignette_outer = 0.85;
uniform float vignette_max = 0.85;
uniform float pulse_amplitude = 0.15;
uniform float pulse_frequency = 2.0;

const float GOLDEN_ANGLE = 2.39996323;
const int BLUR_TAPS = 12;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 to_centre = vec2(0.5) - uv;
	float rim = length(to_centre);

	// 1. MOTION ---------------------------------------------------------------------
	// Two incommensurate sines per axis: cheap, smooth, never snaps between frames.
	float t = TIME * 40.0;
	vec2 tremor = vec2(
		sin(t + uv.y * 20.0) * 0.6 + sin(t * 1.73 + uv.x * 17.0) * 0.4,
		cos(t * 0.71 + uv.y * 19.0) * 0.6 + cos(t * 1.37 + uv.x * 21.0) * 0.4
	) * tremor_amplitude * crash_intensity;
	vec2 base = uv + (tremor + shake_offset) * motion_scale;

	// 2. DISTORTION -----------------------------------------------------------------
	float d = crash_intensity * distortion_scale;
	// CA grows toward the rim so the player at the centre stays legible.
	vec2 split = to_centre * chroma_scale * d * (0.25 + rim * 0.85);
	vec3 col = vec3(
		texture(screen_texture, base + split).r,
		texture(screen_texture, base).g,
		texture(screen_texture, base - split).b
	);
	// Golden-angle spiral: a soft disc instead of the ghosted copies a ring kernel
	// leaves at high radius.
	float radius = blur_scale * d;
	if (radius > 0.0004) {
		vec3 acc = col;
		for (int i = 1; i <= BLUR_TAPS; i++) {
			float r = radius * sqrt(float(i) / float(BLUR_TAPS));
			float a = float(i) * GOLDEN_ANGLE;
			acc += texture(screen_texture, base + vec2(cos(a), sin(a)) * r).rgb;
		}
		col = mix(col, acc / float(BLUR_TAPS + 1), clamp(d * 2.0, 0.0, 1.0));
	}

	// 3. HIGH-FOCUS: everything has a wire ------------------------------------------
	if (focus_intensity > 0.001) {
		float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
		vec3 contrasted = mix(vec3(lum), col, 1.28);
		vec2 px = 1.5 / vec2(textureSize(screen_texture, 0));
		vec3 gx = texture(screen_texture, base + vec2(px.x, 0.0)).rgb
			- texture(screen_texture, base - vec2(px.x, 0.0)).rgb;
		vec3 gy = texture(screen_texture, base + vec2(0.0, px.y)).rgb
			- texture(screen_texture, base - vec2(0.0, px.y)).rgb;
		vec3 edges = abs(gx) + abs(gy);
		col = mix(col, contrasted + edges * 0.55, focus_intensity * 0.75);
	}

	// 4. VIGNETTE -------------------------------------------------------------------
	float vig = smoothstep(vignette_inner, vignette_outer, rim);
	float strength = vig * vignette_max * clamp(edge_proximity + crash_intensity * 0.25, 0.0, 1.0);
	float pulse = 0.0;
	if (edge_proximity > 0.7) {
		pulse = sin(TIME * pulse_frequency * 6.28318) * pulse_amplitude
			* ((edge_proximity - 0.7) / 0.3) * vig;
	}
	col *= 1.0 - clamp(strength + pulse, 0.0, 1.0);

	// 5. GRAIN ----------------------------------------------------------------------
	float seed = fract(sin(dot(uv * 511.0 + TIME * 0.37, vec2(12.9898, 78.233))) * 43758.5453);
	col += (seed - 0.5) * grain_scale * crash_intensity;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
"""

## --- CONFIGURATION -------------------------------------------------------------------

## CanvasLayer index: above the world, below the dream fade (30) and the HUD (50).
@export var fx_layer: int = 4

@export var chroma_scale: float = 0.018
@export var blur_scale: float = 0.012
@export var tremor_amplitude: float = 0.0015
@export var grain_scale: float = 0.03

## Vignette shape (soft boundary).
@export var vignette_inner: float = 0.30
@export var vignette_outer: float = 0.85
@export var vignette_max: float = 0.85

## Step-shake impulse: peak offset in pixels and decay time.
@export var shake_impulse_amplitude: float = 2.0
@export var shake_decay_seconds: float = 0.45

## Seconds-scale smoothing for crash and focus ramps.
@export var ramp_rate: float = 5.0

## --- ACCESSIBILITY (T13 settings drive these) -----------------------------------------

## 0 = no tremor or shake, 1 = authored.
@export_range(0.0, 1.0) var motion_scale: float = 1.0

## 0 = no chromatic aberration or blur, 1 = authored.
@export_range(0.0, 1.0) var distortion_scale: float = 1.0

## --- DEPENDENCIES -------------------------------------------------------------------

@export var state_machine: PlayerStateMachine
@export var player_movement: PlayerMovement

## --- STATE -----------------------------------------------------------------------------

## Ticket-06: lucid cap. Even at overload 100, crash intensity is capped at this value
## so the player can still see. 1.0 = no cap.
var lucid_cap: float = 1.0

var _color_rect: ColorRect
var _material: ShaderMaterial
var _crash_intensity: float = 0.0
var _focus_intensity: float = 0.0
var _edge_proximity: float = 0.0
var _shake_remaining: float = 0.0
var _shake_direction: Vector2 = Vector2.ZERO

## External override for crash intensity (-1 = none). The ambulance interception forces
## full strength regardless of the meter.
var _intensity_override: float = -1.0

## ----- LIFECYCLE ---------------------------------------------------------------------


func _ready() -> void:
	layer = fx_layer
	_build_shader_layer()
	if player_movement != null:
		player_movement.movement_completed.connect(_on_movement_completed)


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-delta * ramp_rate)
	_crash_intensity = lerpf(_crash_intensity, _target_crash(), weight)
	_focus_intensity = lerpf(_focus_intensity, _target_focus(), weight)
	_shake_remaining = maxf(_shake_remaining - delta, 0.0)
	_push_shader_params()


## ----- PUBLIC API ------------------------------------------------------------------------


## Soft boundary: 0 = room centre, 1 = pressed against the wall.
func set_edge_proximity(proximity: float) -> void:
	_edge_proximity = clampf(proximity, 0.0, 1.0)


## Force crash intensity to a fixed value, ignoring the meter.
func set_intensity_override(value: float) -> void:
	_intensity_override = clampf(value, 0.0, 1.0)


## Release the override and resume meter-driven intensity.
func clear_intensity_override() -> void:
	_intensity_override = -1.0


## ----- INTERNALS -------------------------------------------------------------------------


func _build_shader_layer() -> void:
	var shader := Shader.new()
	shader.code = SCREEN_EFFECTS_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_color_rect = ColorRect.new()
	_color_rect.name = "ScreenEffectsRect"
	_color_rect.material = _material
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_color_rect)


func _on_movement_completed() -> void:
	# Only a crashed step lands heavy; in High-Focus the step is crisp and silent.
	if state_machine == null or state_machine.state_data == null:
		return
	if not state_machine.state_data.is_crashed():
		return
	_shake_remaining = shake_decay_seconds
	_shake_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()


## 0 below overload 50, ramping to 1 at 100, capped by lucid_cap.
func _target_crash() -> float:
	if _intensity_override >= 0.0:
		return _intensity_override
	if state_machine == null or state_machine.state_data == null:
		return 0.0
	var raw := clampf((state_machine.state_data.sensory_overload - 50.0) / 50.0, 0.0, 1.0)
	return minf(raw, lucid_cap)


func _target_focus() -> float:
	if state_machine == null or state_machine.state_data == null:
		return 0.0
	return 1.0 if state_machine.state_data.is_high_focus() else 0.0


func _shake_uv() -> Vector2:
	if _shake_remaining <= 0.0 or shake_decay_seconds <= 0.0:
		return Vector2.ZERO
	var size := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2.ONE
	var pixels := (
		_shake_direction * shake_impulse_amplitude * (_shake_remaining / shake_decay_seconds)
	)
	return pixels / size.max(Vector2.ONE)


func _push_shader_params() -> void:
	_material.set_shader_parameter("crash_intensity", _crash_intensity)
	_material.set_shader_parameter("focus_intensity", _focus_intensity)
	_material.set_shader_parameter("edge_proximity", _edge_proximity)
	_material.set_shader_parameter("shake_offset", _shake_uv())
	_material.set_shader_parameter("chroma_scale", chroma_scale)
	_material.set_shader_parameter("blur_scale", blur_scale)
	_material.set_shader_parameter("tremor_amplitude", tremor_amplitude)
	_material.set_shader_parameter("grain_scale", grain_scale)
	_material.set_shader_parameter("motion_scale", motion_scale)
	_material.set_shader_parameter("distortion_scale", distortion_scale)
	_material.set_shader_parameter("vignette_inner", vignette_inner)
	_material.set_shader_parameter("vignette_outer", vignette_outer)
	_material.set_shader_parameter("vignette_max", vignette_max)
