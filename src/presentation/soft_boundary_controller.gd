class_name SoftBoundaryController
extends Node3D
## PRESENTATION LAYER — soft boundary vignette (Task 3 spec).
##
## Instead of physical walls (constraint #6), this controller drives a full-screen
## CanvasItem shader that draws a heavy dark vignette. The vignette intensifies as the
## player approaches the edge of the workspace grid, creating a visual "you're getting
## too close to the wall" signal without any collision response.
##
## WHY A CANVASLAYER + COLORRECT
## -----------------------------
## The vignette is a screen-space effect: it doesn't need to know about 3D geometry,
## only about UV coordinates. A ColorRect on a CanvasLayer (layer 6, above the world)
## samples `SCREEN_TEXTURE` and applies a radial darkening. This is cheaper than a
## post-processing camera effect and works on all renderer backends (Forward+, Mobile,
## Compatibility).
##
## INTENSITY MODEL
## ---------------
## `edge_proximity` is a 0..1 float where 0 = centre of the grid, 1 = at the wall. The
## vignette strength scales linearly with this value, so the player sees the edges
## darken smoothly as they approach. A pulse is added on top when `edge_proximity > 0.7`
## to create urgency.
##
## This controller can be driven by:
##   1. GameBootstrap wiring SoftBoundaryModel.proximity_changed to set_edge_proximity()
##   2. Direct assignment from PlayerMovement when the cell position changes
##   3. Manual testing by setting edge_proximity in the inspector (via @export)
##
## The shader is embedded as a string constant so the file is self-contained; no external
## .gdshader asset is needed.

## --- SHADER CODE (inline GLSL, Task 3 requirement #3) --------------------------------

const VIGNETTE_SHADER_CODE := """
shader_type canvas_item;

// Godot 4.2+ form: hinted sampler2D uniform, not the bare `hint_screen_texture;`
// statement (which 4.7 rejects at parse).
uniform sampler2D screen_texture : hint_screen_texture;

uniform float edge_proximity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_time = 0.0;

// Vignette shape: radial falloff from screen centre.
// `inner_radius` is where the darkening starts (0.3 = inner 30% of the screen is clean).
// `outer_radius` is where it reaches maximum darkness (1.0 = corners).
// Plain float uniforms take the default directly — `: float` is not a valid hint.
uniform float inner_radius = 0.30;
uniform float outer_radius = 0.85;

// Maximum darkness at the outer edge (0 = no vignette, 1 = fully black).
uniform float max_darkness = 0.85;

// Pulse amplitude and frequency. The pulse kicks in when edge_proximity > 0.7 to
// create urgency as the player presses against the wall.
uniform float pulse_amplitude = 0.15;
uniform float pulse_frequency = 2.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centre = vec2(0.5, 0.5);
	float dist = distance(uv, centre);

	// Radial vignette: smoothstep from inner_radius (clean) to outer_radius (dark).
	float vignette = smoothstep(inner_radius, outer_radius, dist);

	// Scale by edge_proximity: no vignette at centre, full vignette at wall.
	float strength = vignette * max_darkness * edge_proximity;

	// Pulse: sine wave that intensifies when the player is very close to the edge.
	float pulse = 0.0;
	if (edge_proximity > 0.7) {
		float pulse_intensity = (edge_proximity - 0.7) / 0.3;  // normalize 0.7..1.0 to 0..1
		pulse = sin(pulse_time * pulse_frequency * 6.28318) * pulse_amplitude * pulse_intensity;
	}

	// Combine: darken the screen by (strength + pulse).
	float darkness = clamp(strength + pulse, 0.0, 1.0);

	// Sample the screen texture and apply the vignette as a multiply.
	vec3 col = texture(screen_texture, uv).rgb;
	col *= (1.0 - darkness);

	COLOR = vec4(col, 1.0);
}
"""

## --- CONFIGURATION -------------------------------------------------------------------

## CanvasLayer index. 6 places the vignette above the world (layer 0) and the post-FX
## layer (5), but below any modal UI or pause menus.
@export var canvas_layer_index: int = 6

## Initial edge proximity (0 = centre, 1 = wall). Set by GameBootstrap or PlayerMovement.
@export var edge_proximity: float = 0.0:
	set(value):
		edge_proximity = clampf(value, 0.0, 1.0)
		if _material != null:
			_material.set_shader_parameter("edge_proximity", edge_proximity)

## Maximum vignette darkness at the wall (0 = no effect, 1 = fully black edges).
@export var max_darkness: float = 0.85

## Inner radius of the vignette (fraction of screen distance from centre). The inner
## portion of the screen stays clean so the player can always read their immediate cell.
@export var inner_radius: float = 0.30

## Outer radius where the vignette reaches maximum darkness.
@export var outer_radius: float = 0.85

## Pulse amplitude when edge_proximity > 0.7. Creates urgency as the player presses
## against the wall.
@export var pulse_amplitude: float = 0.15

## Pulse frequency in Hz. 2.0 Hz is fast enough to feel urgent but slow enough to read.
@export var pulse_frequency: float = 2.0

## --- INTERNAL STATE ------------------------------------------------------------------

var _canvas_layer: CanvasLayer
var _color_rect: ColorRect
var _material: ShaderMaterial
var _pulse_time: float = 0.0

## ----- LIFECYCLE ---------------------------------------------------------------------


func _ready() -> void:
	_build_shader_layer()


func _process(delta: float) -> void:
	_pulse_time += delta
	if _material != null:
		_material.set_shader_parameter("pulse_time", _pulse_time)


## ----- SHADER SETUP ------------------------------------------------------------------


func _build_shader_layer() -> void:
	# Create the shader resource from the embedded code.
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER_CODE

	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("edge_proximity", edge_proximity)
	_material.set_shader_parameter("max_darkness", max_darkness)
	_material.set_shader_parameter("inner_radius", inner_radius)
	_material.set_shader_parameter("outer_radius", outer_radius)
	_material.set_shader_parameter("pulse_amplitude", pulse_amplitude)
	_material.set_shader_parameter("pulse_frequency", pulse_frequency)

	# Create the CanvasLayer and ColorRect.
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = canvas_layer_index
	add_child(_canvas_layer)

	_color_rect = ColorRect.new()
	_color_rect.name = "VignetteRect"
	_color_rect.material = _material
	# A full-rect Control on top of the view must not eat mouse clicks.
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_color_rect)


## ----- PUBLIC API --------------------------------------------------------------------


## Update edge proximity at runtime. Called by GameBootstrap when SoftBoundaryModel
## emits proximity_changed, or by PlayerMovement when the cell position changes.
func set_edge_proximity(proximity: float) -> void:
	edge_proximity = clampf(proximity, 0.0, 1.0)


## Update configuration at runtime (for cutscenes or Ticket-05 dreamscape transition
## where the boundary rules change).
func set_vignette_params(darkness: float, inner: float, outer: float) -> void:
	max_darkness = darkness
	inner_radius = inner
	outer_radius = outer
	if _material != null:
		_material.set_shader_parameter("max_darkness", max_darkness)
		_material.set_shader_parameter("inner_radius", inner_radius)
		_material.set_shader_parameter("outer_radius", outer_radius)
