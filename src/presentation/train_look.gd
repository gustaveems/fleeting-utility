class_name TrainLook
extends RefCounted
## PRESENTATION — the maglev's skin (playtest 2026-10-30: "the train still hasn't been
## texturized"). Shaders in the carriage's own space, so every box of it lines up:
##
##   TrainLook.body(color)   white panels with seams, two doors a side, the belt lines,
##                           grime gathering low and streaking down from the roof
##   TrainLook.glass()       a window band: dark frames between panes, each pane lit a
##                           little differently (people inside, blinds half down)

const BODY := """
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.92, 0.93, 0.94);
uniform float length_m = 18.0;
uniform float height_m = 3.4;

varying vec3 local_pos;

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

// 1 on a thin line at every multiple of `step` (width `w` metres), else 0.
float lines(float x, float step, float w) {
	float d = abs(fract(x / step + 0.5) - 0.5) * step;
	return 1.0 - smoothstep(w * 0.5, w, d);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float z = local_pos.z;
	float y = local_pos.y + height_m * 0.5;  // 0 at the floor, height_m at the roof
	vec3 c = base_color;
	// Panels: a seam every 2.25 m along the car, the belt lines above and below the
	// windows, the roof's edge.
	float seam = lines(z, 2.25, 0.03);
	seam = max(seam, lines(y - 1.0, 100.0, 0.03));
	seam = max(seam, lines(y - 2.35, 100.0, 0.03));
	seam = max(seam, lines(y - 3.05, 100.0, 0.03));
	// Two doors a side: an outline, a darker sill, the gap where they part.
	for (int k = -1; k <= 1; k += 2) {
		float dz = z - float(k) * length_m * 0.25;
		float inside = step(abs(dz), 0.75) * step(y, 2.3) * step(0.15, y);
		float edge = inside * (1.0 - step(abs(dz), 0.71) * step(y, 2.26) * step(0.19, y));
		seam = max(seam, edge);
		seam = max(seam, inside * lines(dz, 100.0, 0.02));
		c = mix(c, c * 0.9, inside);
	}
	c *= 1.0 - seam * 0.55;
	// Grime: low on the skirt, streaks run down from the roof, a mottle everywhere.
	float mottle = noise(vec2(z * 0.7, y * 2.0)) * 0.6 + noise(vec2(z * 3.1, y * 5.0)) * 0.4;
	float low = smoothstep(1.1, 0.0, y);
	float streak = smoothstep(0.55, 0.9, noise(vec2(z * 6.0, y * 0.35))) * smoothstep(1.2, 3.4, y);
	float grime = clamp(low * 0.55 + streak * 0.25 + mottle * 0.12, 0.0, 1.0);
	c = mix(c, vec3(0.32, 0.3, 0.27), grime);
	ALBEDO = c;
	ROUGHNESS = mix(0.28, 0.85, grime);
	METALLIC = 0.25;
	SPECULAR = 0.6;
}
"""

const GLASS := """
shader_type spatial;

uniform float length_m = 16.0;
uniform vec3 light_color : source_color = vec3(0.95, 0.85, 0.55);

varying vec3 local_pos;

float hash(float n) {
	return fract(sin(n * 91.7) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float pane_w = 1.6;
	float x = local_pos.z / pane_w + 0.5;
	float pane = floor(x);
	float across = fract(x);
	float up = local_pos.y;  // -h/2 .. h/2
	// Dark frames between the panes and round the band.
	float frame = step(across, 0.06) + step(0.94, across);
	frame = max(frame, step(0.38, abs(up)));
	// Each pane its own light: some bright, some dim, a blind half down in a few.
	float lit = mix(0.35, 1.0, hash(pane + 3.0));
	float blind = step(0.75, hash(pane + 11.0)) * step(0.05, up);
	vec3 inside = light_color * lit * (1.0 - blind * 0.7);
	ALBEDO = mix(vec3(0.05, 0.06, 0.07), vec3(0.08, 0.1, 0.12), 1.0 - frame);
	ROUGHNESS = mix(0.08, 0.6, frame);
	METALLIC = 0.0;
	EMISSION = inside * (1.0 - frame) * 0.9;
}
"""

static var _body_shader: Shader
static var _glass_shader: Shader


static func body(color: Color, length_m: float, height_m: float) -> ShaderMaterial:
	if _body_shader == null:
		_body_shader = Shader.new()
		_body_shader.code = BODY
	var m := ShaderMaterial.new()
	m.shader = _body_shader
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("length_m", length_m)
	m.set_shader_parameter("height_m", height_m)
	return m


static func glass(length_m: float) -> ShaderMaterial:
	if _glass_shader == null:
		_glass_shader = Shader.new()
		_glass_shader.code = GLASS
	var m := ShaderMaterial.new()
	m.shader = _glass_shader
	m.set_shader_parameter("length_m", length_m)
	return m
