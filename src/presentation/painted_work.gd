class_name PaintedWork
extends Node3D
## PRESENTATION — one canvas (Ticket-14, loop 2). It always tries to paint the same
## thing, the autumn valley with a monolith on the horizon (what he dreams of), and
## his state decides how close it gets:
##
##   vividness   chemical / High-Focus      saturation and warmth
##   smear       crash intensity            a horizontal drag through everything
##   flatness    withdrawal                 grey, lifeless
##   coherence   skill                      the horizon and monolith resolve from noise
##   reveal      0..1                       paint laid so far (the easel's wet canvas)
##
## All parameters plus the seed are plain floats, so Persistence can rebuild the canvas.

## Big enough to read his state from the iso camera; the room haze is ignored
## (fog_disabled) so the paint reads true.
const SIZE := Vector2(0.95, 0.68)

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform float seed_value = 0.0;
uniform float vividness : hint_range(0.0, 1.0) = 0.5;
uniform float smear : hint_range(0.0, 1.0) = 0.0;
uniform float flatness : hint_range(0.0, 1.0) = 0.0;
uniform float coherence : hint_range(0.0, 1.0) = 0.2;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed_value * 13.37) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	// The crash drags the brush sideways.
	uv.x += (noise(vec2(uv.y * 14.0, seed_value)) - 0.5) * smear * 0.35;
	float n = noise(uv * 5.0 + seed_value) * 0.6 + noise(uv * 13.0 - seed_value) * 0.4;
	float loose = 1.0 - coherence;

	// Composition: sky above a horizon, a monolith rising from it.
	float horizon_y = 0.58 + (hash(vec2(seed_value, 1.0)) - 0.5) * 0.12;
	float ground = smoothstep(horizon_y - 0.02 - loose * 0.2, horizon_y + 0.02 + loose * 0.2,
		uv.y + (n - 0.5) * loose * 0.6);
	float mono_x = 0.5 + (hash(vec2(seed_value, 2.0)) - 0.5) * 0.5;
	float width = 0.035 + loose * 0.12;
	float mono = (1.0 - smoothstep(width, width + 0.02 + loose * 0.2, abs(uv.x - mono_x)))
		* step(0.18 + n * loose * 0.4, uv.y) * (1.0 - ground);

	vec3 sky = mix(vec3(0.98, 0.66, 0.30), vec3(0.85, 0.42, 0.18), uv.y);
	vec3 earth = vec3(0.42, 0.22, 0.10);
	vec3 col = mix(sky, earth, ground);
	col = mix(col, vec3(0.20, 0.14, 0.13), mono * (0.4 + coherence * 0.6));
	col = mix(col, col * (0.6 + n * 0.8), loose * 0.7);

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, clamp(vividness * 1.2, 0.0, 1.2));
	col = mix(col, vec3(lum * 0.55 + 0.12), flatness);

	// Unpainted canvas shows through where the paint has not reached yet.
	float laid = step(n * 0.35 + uv.x * 0.65, reveal * 1.05);
	// Bare canvas: a dull primed grey (unshaded and unfogged, so pure white glared).
	ALBEDO = mix(vec3(0.62, 0.60, 0.56), col, laid);
}
"""

static var _shader: Shader

var seed_value: float = 0.0
var vividness: float = 0.5
var smear: float = 0.0
var flatness: float = 0.0
var coherence: float = 0.2

var _material: ShaderMaterial


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = _shader
	var canvas := MeshInstance3D.new()
	canvas.name = "Canvas"
	var quad := QuadMesh.new()
	quad.size = SIZE
	canvas.mesh = quad
	canvas.material_override = _material
	add_child(canvas)
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	var box := BoxMesh.new()
	box.size = Vector3(SIZE.x + 0.06, SIZE.y + 0.06, 0.02)
	frame.mesh = box
	frame.position = Vector3(0.0, 0.0, -0.015)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.16, 0.11)
	frame.material_override = wood
	add_child(frame)
	apply_params()


## Push the parameters into the canvas (call after changing them).
func apply_params(reveal: float = 1.0) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("seed_value", seed_value)
	_material.set_shader_parameter("vividness", vividness)
	_material.set_shader_parameter("smear", smear)
	_material.set_shader_parameter("flatness", flatness)
	_material.set_shader_parameter("coherence", coherence)
	_material.set_shader_parameter("reveal", reveal)


func to_dict() -> Dictionary:
	return {
		"seed": seed_value,
		"vividness": vividness,
		"smear": smear,
		"flatness": flatness,
		"coherence": coherence,
	}


func from_dict(d: Dictionary) -> void:
	seed_value = float(d.get("seed", 0.0))
	vividness = float(d.get("vividness", 0.5))
	smear = float(d.get("smear", 0.0))
	flatness = float(d.get("flatness", 0.0))
	coherence = float(d.get("coherence", 0.2))
	apply_params()
