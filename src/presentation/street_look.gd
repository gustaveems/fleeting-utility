class_name StreetLook
extends RefCounted
## PRESENTATION — the boulevard's ground after rain (polish pass, 2026-11-06: the road read
## as a mottled sheet with white lamp spots on it and the pavement as flat sand). One shader
## drawn in world space, its patterns sized in real metres (`unit` = world metres per real
## metre, as in `CityLook`), so the road's separate boxes share one surface.
##
##   road()       asphalt, a worn centre line, damp patches, puddles along the kerbs that
##                go mirror-smooth (the scene's screen-space reflections land in them),
##                rain ringing on them
##   pavement()   staggered concrete slabs, dirty joints, stains, damp by the kerb

const SHADER := """
shader_type spatial;

uniform bool pavement = false;
uniform float unit = 0.47;
uniform float kerb_x = 8.0;
uniform sampler2D grain : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D grain_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D grain_rough : hint_default_white, filter_linear_mipmap_anisotropic;

varying vec3 wp;

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
	return noise(p) * 0.55 + noise(p * 2.1 + 3.1) * 0.3 + noise(p * 4.3 + 9.7) * 0.15;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz / unit;
}

void fragment() {
	vec2 q = wp.xz;
	float to_kerb = abs(abs(q.x) - kerb_x);
	vec3 tex = texture(grain, q * 0.3).rgb;
	vec3 n = texture(grain_normal, q * 0.3).rgb;
	float r = texture(grain_rough, q * 0.3).r;
	float damp = smoothstep(0.34, 0.6, fbm(q * 0.11 + 3.0));
	if (pavement) {
		// Slabs 1.2 m by 0.6 m, every other row shifted; a joint fades before it shimmers.
		float row = floor(q.x / 0.6);
		vec2 p = vec2(q.x / 0.6, (q.y + row * 0.5) / 1.2);
		vec2 f = fract(p);
		float width = max(0.02, fwidth(p.y) * 1.2);
		float joint = smoothstep(0.0, width, min(min(f.x, 1.0 - f.x) * 0.5, min(f.y, 1.0 - f.y)));
		float slab = hash(floor(p));
		float stain = smoothstep(0.5, 0.72, fbm(q * 0.5 + 5.0));
		float wet = smoothstep(2.4, 0.0, to_kerb) * damp;
		vec3 c = vec3(0.3, 0.3, 0.31) * (0.78 + slab * 0.3) * (0.7 + tex * 0.6);
		c = mix(c * 0.45, c, joint);
		c *= mix(1.0, 0.68, stain);
		c *= mix(1.0, 0.6, wet);
		ALBEDO = c;
		ROUGHNESS = mix(0.8, 0.22, wet * joint);
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), n, 0.4);
	} else {
		float puddle = smoothstep(0.61, 0.67, fbm(q * 0.3 + 7.0));
		float gutter = smoothstep(1.8, 0.2, to_kerb) * smoothstep(0.42, 0.52, fbm(q * 0.5));
		puddle = max(puddle, gutter);
		vec3 c = tex * vec3(0.62, 0.63, 0.68);
		// A worn dashed centre line: 3 m in every 7, scuffed through.
		float dash = step(fract(q.y / 7.0), 0.43) * smoothstep(0.1, 0.07, abs(q.x));
		c = mix(c, vec3(0.5, 0.48, 0.42), dash * smoothstep(0.3, 0.55, fbm(q * 1.4)));
		c *= mix(1.0, 0.72, damp);
		c *= mix(1.0, 0.5, puddle);
		ALBEDO = c;
		ROUGHNESS = mix(mix(r, 0.3, damp), 0.03, puddle);
		vec3 ripple = mix(n, vec3(0.5, 0.5, 1.0), max(puddle, damp * 0.6));
		// Rain on the puddles: one drop's ring a cell, each on its own clock.
		vec2 cell = floor(q / 0.8);
		float clock = fract(TIME * 1.3 + hash(cell));
		vec2 to_drop = q / 0.8 - cell - vec2(hash(cell + 3.0), hash(cell + 7.0));
		float dist = length(to_drop);
		float ring = sin((dist - clock * 0.6) * 42.0) * smoothstep(0.06, 0.0, abs(dist - clock * 0.6));
		ring *= (1.0 - clock) * puddle;
		ripple.xy += normalize(to_drop + 0.001) * ring * 0.4;
		NORMAL_MAP = ripple;
	}
	SPECULAR = 0.5;
}
"""

static var _shader: Shader


static func road(unit: float) -> ShaderMaterial:
	return _material(false, unit, "Asphalt025B")


static func pavement(unit: float) -> ShaderMaterial:
	return _material(true, unit, "Asphalt025B")


static func _material(on_pavement: bool, unit: float, set_id: String) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("pavement", on_pavement)
	m.set_shader_parameter("unit", unit)
	var color := CityKit.surface(set_id, "Color")
	if ResourceLoader.exists(color):
		m.set_shader_parameter("grain", load(color))
		m.set_shader_parameter("grain_normal", load(CityKit.surface(set_id, "NormalGL")))
		m.set_shader_parameter("grain_rough", load(CityKit.surface(set_id, "Roughness")))
	return m
