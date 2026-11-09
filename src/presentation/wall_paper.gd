class_name WallPaper
extends RefCounted
## PRESENTATION — the wallpaper above the dado, tearing away as the room decays (polish
## pass, 2026-11-06). A next-pass on the plaster's own material, so it follows the walls
## round the windows and needs no geometry. `decay` is entropy over 100: at 0 the paper
## is whole, faded stripes; as it rises, holes open along a noise field, a pale torn edge
## round each, the plaster behind them.

const SHADER := """
shader_type spatial;
render_mode depth_draw_never;

uniform float decay = 0.0;
uniform float dado = 0.42;

varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.3 + 4.1) * 0.3 + noise(p * 5.1 + 8.3) * 0.2;
}

void vertex() {
	VERTEX += NORMAL * 0.003;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (wn.y > 0.5 || wp.y < dado) {
		discard;
	}
	vec2 q = wn.x > 0.5 ? vec2(wp.z, wp.y) : vec2(wp.x, wp.y);
	// Tearing starts from the top and the damp low corners, so the holes aren't even.
	float field = fbm(q * 1.5) + (1.0 - wp.y / 1.35) * 0.08;
	float cut = field - (1.02 - decay * 0.82);
	if (cut > 0.0) {
		discard;
	}
	float stripe = step(0.5, fract(q.x * 7.0));
	float sprig = smoothstep(0.1, 0.07, length(fract(q * vec2(7.0, 5.0)) - 0.5));
	vec3 c = mix(vec3(0.5, 0.47, 0.34), vec3(0.42, 0.42, 0.32), stripe);
	c = mix(c, vec3(0.34, 0.27, 0.2), sprig * 0.6);
	c *= 0.82 + 0.3 * noise(q * 3.0);
	float edge = smoothstep(-0.035, 0.0, cut);
	c = mix(c, vec3(0.74, 0.7, 0.6), edge);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	ALPHA = 1.0;
}
"""

static var _material: ShaderMaterial


## The next pass for a wall above the dado (one shared material).
static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


## `entropy` 0–100, as WorkspaceEntropyData carries it.
static func set_decay(entropy: float) -> void:
	material().set_shader_parameter("decay", clampf(entropy / 100.0, 0.0, 1.0))
