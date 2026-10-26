class_name CampaignArt
extends RefCounted
## PRESENTATION — the luxury campaign's image (docs/STORY.md, "The valley is nowhere";
## beat 2; Ticket-22): a model walking a misty autumn path past blood-marked stones,
## gold haze, birches, falling leaves. The valley he will dream of, sold first as
## "heritage". Drawn by a shader so any board can wear it at any size.
##
##   panel.material_override = CampaignArt.material(width / height)

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform float aspect = 2.6;
uniform float brightness = 1.2;

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

// Signed distance to a rounded box (centre c, half size h, corner r).
float rbox(vec2 p, vec2 c, vec2 h, float r) {
	vec2 d = abs(p - c) - h + r;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

void fragment() {
	vec2 uv = UV;                       // y down: 0 top, 1 bottom
	vec2 p = vec2(uv.x * aspect, uv.y);
	float hz = 0.6;                     // the horizon
	float cx = aspect * 0.5;
	vec3 mist = vec3(0.97, 0.9, 0.78);

	// Sky: pale gold to warm amber at the horizon.
	vec3 col = mix(vec3(0.92, 0.86, 0.72), vec3(0.99, 0.79, 0.5), smoothstep(0.0, hz, uv.y));
	// The far treeline, soft in the haze.
	float tl = hz - 0.05 - 0.06 * noise(vec2(p.x * 7.0, 1.0));
	if (uv.y > tl && uv.y < hz) {
		col = mix(col, vec3(0.8, 0.56, 0.33), 0.5);
	}
	// Ground: leaf litter, and the path running to the vanishing point.
	if (uv.y >= hz) {
		float t = (uv.y - hz) / (1.0 - hz);
		float g = noise(p * vec2(22.0, 34.0));
		col = mix(vec3(0.6, 0.33, 0.14), vec3(0.82, 0.5, 0.2), g);
		float hw = mix(0.015, 0.6, t);
		col = mix(col, vec3(0.78, 0.64, 0.46), smoothstep(hw, hw - 0.04, abs(p.x - cx)));
	}
	// Mist lying on the horizon.
	col = mix(col, mist, 0.6 * exp(-pow((uv.y - hz) / 0.09, 2.0)));

	// Birches: x, width, depth (0 near, 1 far). Kept off the path.
	float tx[8] = float[8](0.12, 0.36, 0.62, 0.95, 1.7, 1.98, 2.22, 2.48);
	float tw[8] = float[8](0.035, 0.022, 0.012, 0.009, 0.01, 0.014, 0.024, 0.04);
	float td[8] = float[8](0.0, 0.4, 0.75, 0.9, 0.85, 0.7, 0.35, 0.0);
	for (int i = 0; i < 8; i++) {
		float x = tx[i] * aspect / 2.6;
		float foot = hz + (1.0 - td[i]) * 0.36;
		if (abs(p.x - x) < tw[i] && uv.y < foot) {
			float dash = step(0.78, noise(vec2(x * 13.0, uv.y * 46.0)));
			vec3 bark = mix(vec3(0.93, 0.92, 0.88), vec3(0.15, 0.13, 0.12), dash);
			col = mix(bark, mist, td[i] * 0.65);
		}
	}

	// Standing stones beside the path, blood running down them.
	vec3 sc = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 c = vec2(cx + mix(-0.72, 0.5, fi / 2.0) + (fi == 1.0 ? -0.08 : 0.0), 0.0);
		float depth = 1.0 - fi * 0.35;           // the first stands nearest
		vec2 h = vec2(0.042, 0.13) * (1.6 - depth * 0.6);
		c.y = hz + 0.05 + (1.0 - depth) * 0.28 - h.y;
		// Rough-hewn: the outline wanders a little.
		float d = rbox(p, c, h, h.x * 0.35) + (noise(p * 55.0) - 0.5) * 0.012;
		if (d < 0.0) {
			vec3 stone = mix(vec3(0.42, 0.4, 0.38), vec3(0.6, 0.57, 0.53), noise(p * 40.0));
			float run = (uv.y - (c.y - h.y)) / (2.0 * h.y);   // 0 top, 1 bottom
			// Thin drips from the top, each its own length.
			float lane = hash(vec2(floor(p.x * 90.0), fi));
			float blood = step(0.8, lane) * step(run, 0.2 + hash(vec2(floor(p.x * 90.0), 9.0)) * 0.7);
			blood = max(blood, step(run, 0.07));   // pooled along the top
			stone = mix(stone, vec3(0.34, 0.03, 0.03), blood * 0.85);
			col = mix(stone, mist, depth * 0.15);
		}
	}

	// The model: slim, dark, walking the path toward the haze.
	vec2 m = vec2(cx + 0.03, hz + 0.2);       // the feet
	float s = 0.3;                           // her height
	float head = length(p - vec2(m.x, m.y - s * 0.92)) - s * 0.07;
	float coat = rbox(p, vec2(m.x, m.y - s * 0.55), vec2(s * 0.085, s * 0.3), s * 0.05);
	float legl = rbox(p, vec2(m.x - s * 0.04, m.y - s * 0.12), vec2(s * 0.022, s * 0.13), 0.002);
	float legr = rbox(p, vec2(m.x + s * 0.05, m.y - s * 0.1), vec2(s * 0.022, s * 0.11), 0.002);
	if (min(min(head, coat), min(legl, legr)) < 0.0) {
		col = vec3(0.1, 0.08, 0.08);
	}

	// Leaves in the air.
	vec2 cell = floor(p * 18.0);
	vec2 f = fract(p * 18.0) - 0.5;
	vec2 jitter = (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.6;
	if (hash(cell) > 0.82 && length(f - jitter) < 0.07) {
		col = mix(col, vec3(0.92, 0.45, 0.12), 0.9);
	}

	// Gloss: a warm grade and a vignette.
	col = pow(col, vec3(0.95, 1.0, 1.08));
	col *= 0.72 + 0.28 * smoothstep(0.95, 0.25, length((uv - 0.5) * vec2(1.3, 1.0)));
	// Authored as display colours; the renderer works in linear light.
	ALBEDO = pow(col, vec3(2.2)) * brightness;
}
"""

static var _shader: Shader


## A material wearing the campaign, for a panel `aspect` times wider than tall.
static func material(aspect: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("aspect", aspect)
	return m
