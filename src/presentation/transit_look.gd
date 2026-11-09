class_name TransitLook
extends RefCounted
## PRESENTATION — the metro's surfaces (playtest 2026-11-03: "the metro station is not
## texturized; the inside of the metro is not texturized"). One shader drawn in each
## box's own space (no UVs on the boxes), its patterns sized in real metres: `unit` is
## how many real metres one local unit is (the diorama carriage is ~2.1 m a unit; the
## evening's real-metre boxes are 1).
##
##   panel(unit)      moulded carriage walls: panel seams, rivets, scuffs, scratched
##                    tags, grime gathering low
##   flooring(unit)   studded rubber flooring, a worn path, grit
##   seat(unit)       the moquette: a repeating diamond weave in teal, maroon, mustard
##   tile(unit)       station walls: white subway tiles, dirty grout, a coloured band
##   concrete(unit)   the platform: slabs, joints, stains, the yellow tactile edge on
##                    the box's +X side

enum Kind { PANEL, FLOOR, SEAT, TILE, CONCRETE }

const SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform int kind = 0;
uniform float unit = 1.0;
uniform vec3 base : source_color = vec3(0.6, 0.62, 0.58);
uniform vec3 band : source_color = vec3(0.15, 0.55, 0.65);
uniform float edge_x = 1.0;

varying vec3 lp;
varying vec3 ln;

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

float line(float x, float step_m, float w) {
	float d = abs(fract(x / step_m + 0.5) - 0.5) * step_m;
	return 1.0 - smoothstep(w * 0.5, w, d);
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;  // boxes seen from inside (a carriage shell) light properly
	}
	vec3 p = lp * unit;  // real metres
	vec3 n = abs(ln);
	// The face's own 2D coordinates: across (u) and up (v).
	vec2 q = n.y > 0.5 ? p.xz : (n.x > 0.5 ? p.zy : p.xy);
	vec3 c = base;
	float rough = 0.8;
	float metal = 0.0;
	float dirt = noise(q * 1.7) * 0.6 + noise(q * 7.0) * 0.4;
	if (kind == 0) {
		// Panels 1.2 m wide, 0.9 m tall; rivets along the seams; scuffs; tags.
		float seam = max(line(q.x, 1.2, 0.012), line(q.y, 0.9, 0.012));
		vec2 rv = vec2(fract(q.x / 1.2), fract(q.y / 0.15));
		float rivet = step(abs(rv.x - 0.04) * 1.2, 0.006) * step(abs(rv.y - 0.5) * 0.15, 0.006);
		c *= mix(0.92, 1.05, dirt);
		c *= 1.0 - seam * 0.45;
		c = mix(c, vec3(0.75), rivet * 0.6);
		float low = smoothstep(-0.6, -1.4, p.y);  // the box's lower part (centred boxes)
		c = mix(c, c * 0.6, low * 0.5);
		float scratch = step(0.86, noise(vec2(q.x * 30.0, q.y * 2.0))) * step(0.55, noise(q * 0.8));
		c = mix(c, vec3(0.85), scratch * 0.5);
		// A sprayed stroke: the noise's mid contour, a line that wanders, not a blob.
		float stroke = smoothstep(0.05, 0.025, abs(noise(q * 3.2 + 11.0) - 0.5));
		float tag = stroke * step(0.66, noise(q * 0.5 + 3.0));
		vec3 spray = mix(vec3(0.85, 0.2, 0.55), vec3(0.95, 0.8, 0.2), step(0.5, hash(floor(q * 0.5))));
		c = mix(c, spray * 0.8, tag * 0.8);
		rough = mix(0.45, 0.9, dirt * 0.6 + seam);
	} else if (kind == 1) {
		// Studded rubber: round studs on a 4 cm grid; a worn, paler path; grit.
		vec2 g = fract(q / 0.04) - 0.5;
		// Fade the studs and grit out where they'd be smaller than a pixel (they sparkled).
		float fine = 1.0 - smoothstep(0.25, 0.6, length(fwidth(q / 0.04)));
		float stud = (1.0 - smoothstep(0.18, 0.24, length(g))) * fine;
		float path = 1.0 - smoothstep(0.2, 0.5, abs(q.y));
		c *= mix(0.8, 1.05, stud);
		c = mix(c, c * 1.35, path * 0.5 * dirt);
		float grit = step(0.93, hash(floor(q * 60.0))) * fine;
		c = mix(c, vec3(0.5, 0.47, 0.42), grit * 0.6);
		rough = 0.85;
	} else if (kind == 2) {
		// Moquette: diamonds every 8 cm, a cross through each, three colours.
		vec2 r = vec2(q.x + q.y, q.x - q.y) / 0.08;
		vec2 f = abs(fract(r) - 0.5);
		float diamond = step(max(f.x, f.y), 0.28);
		float cross = step(min(f.x, f.y), 0.05);
		vec3 teal = vec3(0.06, 0.32, 0.36);
		vec3 maroon = vec3(0.42, 0.08, 0.12);
		vec3 mustard = vec3(0.72, 0.55, 0.12);
		c = mix(teal, maroon, diamond);
		c = mix(c, mustard, cross * (1.0 - diamond));
		c *= mix(0.75, 1.0, dirt);  // worn, stained
		c *= base;  // white on the trains; a faded tint for a rug
		rough = 0.95;
	} else if (kind == 3) {
		// Subway tiles 15×7.5 cm in a brick bond; grout greys with the dirt; a band of
		// the line's colour at 1.4–1.6 m.
		float row = floor(q.y / 0.075);
		vec2 t = vec2(q.x / 0.15 + 0.5 * mod(row, 2.0), q.y / 0.075);
		vec2 f = fract(t);
		// Far off, the grout blends into a flat grey instead of shimmering (moiré).
		float fine = 1.0 - smoothstep(0.1, 0.3, length(fwidth(t)));
		float grout = mix(0.12, max(step(f.x, 0.06), step(f.y, 0.1)), fine);
		vec3 tile = mix(vec3(0.86, 0.87, 0.84), vec3(0.78, 0.8, 0.76), hash(floor(t)));
		float banded = step(1.4, q.y) * step(q.y, 1.6);
		tile = mix(tile, band, banded);
		c = mix(tile, vec3(0.3, 0.29, 0.26) * (1.3 - dirt * 0.6), grout);
		c *= mix(1.0, 0.7, smoothstep(0.8, 0.0, q.y) * dirt);  // splash grime low
		rough = mix(0.15, 0.8, grout);
	} else {
		// Platform concrete: 1.5 m slabs, joints, stains; the tactile strip along the
		// edge (the box's +X side, the last 0.6 m).
		vec2 s = q / 1.5;
		vec2 f = fract(s);
		float joint = max(step(f.x, 0.02), step(f.y, 0.02));
		c *= mix(0.85, 1.1, hash(floor(s))) * mix(0.8, 1.05, dirt);
		c = mix(c, c * 0.55, joint);
		float stain = smoothstep(0.62, 0.75, noise(q * 0.6 + 5.0));
		c = mix(c, c * 0.6, stain);
		if (n.y > 0.5 && lp.x * sign(edge_x) > abs(edge_x) - 0.6 / unit) {
			vec2 b = fract(q / 0.05) - 0.5;
			float far = 1.0 - smoothstep(0.25, 0.6, length(fwidth(q / 0.05)));
			float bump = (1.0 - smoothstep(0.2, 0.28, length(b))) * far;
			c = mix(vec3(0.85, 0.68, 0.1), vec3(0.95, 0.78, 0.15), bump);
		}
		rough = 0.9;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
}
"""

static var _shader: Shader


static func panel(unit: float = 1.0, color: Color = Color(0.62, 0.64, 0.58)) -> ShaderMaterial:
	return _make(Kind.PANEL, unit, color)


static func flooring(unit: float = 1.0) -> ShaderMaterial:
	return _make(Kind.FLOOR, unit, Color(0.2, 0.21, 0.22))


static func seat(unit: float = 1.0, fade: Color = Color.WHITE) -> ShaderMaterial:
	return _make(Kind.SEAT, unit, fade)


static func tile(unit: float = 1.0, line_color: Color = Color(0.15, 0.55, 0.65)) -> ShaderMaterial:
	var m := _make(Kind.TILE, unit, Color.WHITE)
	m.set_shader_parameter("band", line_color)
	return m


## `edge_half_x`: the box's half width along X (local); the yellow strip runs on the
## side that sign points to.
static func concrete(unit: float = 1.0, edge_half_x: float = 1.0) -> ShaderMaterial:
	var m := _make(Kind.CONCRETE, unit, Color(0.5, 0.5, 0.48))
	m.set_shader_parameter("edge_x", edge_half_x)
	return m


static func _make(kind: Kind, unit: float, color: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("kind", int(kind))
	m.set_shader_parameter("unit", unit)
	m.set_shader_parameter("base", color)
	return m
