class_name CityLook
extends RefCounted
## PRESENTATION — the city's buildings (Phase C's massing look, shared since playtest
## 2026-11-03: "the city isn't texturized" — the evening's and the metro window's towers
## were flat boxes). World-space, so it needs no UVs on scaled boxes.
##
## The look by style: a tower's curtain wall (storey bands, mullions, glass that holds
## the sky, lit rooms, blinds, rain stains), a low block's few windows, the town's render
## over brick with shutters, rock, paving (the top face jointed), corrugated metal.
##
##   PrologueCity's MultiMeshes: instance colour + INSTANCE_CUSTOM.x (Look) per box
##   CityLook.building(tint, look, unit, anchored)   one box's material

enum Look { PLAIN, TOWER, BLOCK, TOWN, ROCK, PAVING, RIBBED }

const SHADER := """
shader_type spatial;
render_mode diffuse_burley;

// MultiMesh: the instance colour and INSTANCE_CUSTOM.x pick the body and the look. A
// single box: `tint` and `look_override` do (its COLOR is white, its custom 0).
uniform vec3 tint : source_color = vec3(1.0);
uniform float look_override = -1.0;
// World metres per real metre (the evening's world is a 0.47 diorama).
uniform float unit = 1.0;
// For a building that moves (the metro window's skyline): pattern in its own space.
uniform bool anchored = false;

varying vec3 world_pos;
varying vec3 world_normal;
varying float look;
varying vec3 body;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 45758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (anchored) {
		world_pos -= NODE_POSITION_WORLD;
	}
	world_pos /= unit;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	look = look_override >= 0.0 ? look_override : INSTANCE_CUSTOM.x;
	body = COLOR.rgb * tint;
}

void fragment() {
	vec3 base = body;
	float y = world_pos.y;
	// Grime toward the street; roofs catch the sky.
	base *= mix(0.62, 1.0, smoothstep(0.0, 9.0, y));
	if (world_normal.y > 0.5) {
		base *= 1.12;
	}
	vec3 glow = vec3(0.0);
	float rough = 0.88;
	float metal = 0.0;
	bool wall = abs(world_normal.y) < 0.5;
	vec2 along = normalize(vec2(-world_normal.z, world_normal.x));
	float u = dot(world_pos.xz, along);
	if (wall && look > 0.5 && look < 2.5) {
		// A curtain wall (playtest 2026-10-30: "the towers are not texturized"): storey
		// bands and mullions in the panel colour, glass that holds the sky (dark low,
		// lighter up), a few lit rooms, blinds, rain stains run down the panels.
		bool tower = look < 1.5;
		vec2 cell_size = tower ? vec2(2.4, 3.6) : vec2(3.2, 3.0);
		vec2 g = vec2(u, y) / cell_size;
		vec2 cell = floor(g);
		vec2 f = fract(g);
		float stain = vnoise(vec2(u * 0.7, y * 0.04)) * vnoise(vec2(u * 3.1, y * 0.12));
		base *= mix(0.9, 1.1, hash(floor(world_pos.xz / 40.0)));  // building to building
		base *= 1.0 - stain * 0.35;
		float glass_x = tower ? 0.08 : 0.25;
		float sill = tower ? 0.22 : 0.3;
		bool pane = f.x > glass_x && f.x < 1.0 - glass_x && f.y > sill && f.y < 0.86 && y > 4.0;
		float slab = 1.0 - smoothstep(0.0, 0.03, abs(f.y - sill + 0.02));
		base *= 1.0 + slab * 0.25;
		if (pane) {
			float h = hash(cell + floor(world_pos.xz / 40.0));
			float lit_share = tower ? 0.12 : 0.1;
			if (h < lit_share) {
				vec3 warm = vec3(1.0, 0.78, 0.5);
				vec3 cool = vec3(0.62, 0.86, 1.0);
				glow = mix(warm, cool, step(0.6, fract(h * 13.7))) * (tower ? 1.15 : 1.05);
				float blind = step(0.7, fract(h * 29.3)) * step(0.55, f.y);
				glow *= 1.0 - blind * 0.6;
				base *= 0.4;
			} else {
				// Dark glass, the sky in it: bluer and brighter with height, a mullion
				// splitting each pane, blinds drawn in some.
				vec3 sky = mix(vec3(0.18, 0.22, 0.26), vec3(0.42, 0.5, 0.56), smoothstep(10.0, 140.0, y));
				base = sky * mix(0.75, 1.1, h);
				float mullion = 1.0 - smoothstep(0.0, 0.02, abs(f.x - 0.5));
				base = mix(base, body * 0.8, mullion * (tower ? 1.0 : 0.0));
				base = mix(base, body * 1.1, step(0.82, fract(h * 7.1)) * 0.6);
				rough = 0.12;
				metal = 0.55;
			}
		}
	}
	if (wall && look > 2.5 && look < 3.5) {
		// The town: sun-bleached render over brick, patched; small shuttered windows.
		float n = vnoise(vec2(u, y) * 0.35) * 0.6 + vnoise(vec2(u, y) * 2.2) * 0.4;
		base *= mix(0.78, 1.15, n);
		float brick = step(0.62, vnoise(vec2(u, y) * 0.5 + 9.0));
		vec2 b = vec2(u * 4.0 + floor(y * 13.0) * 0.5, y * 13.0);
		float course = max(step(fract(b.y), 0.12), step(fract(b.x), 0.06));
		base = mix(base, vec3(0.45, 0.24, 0.16) * mix(1.0, 0.7, course), brick * 0.85);
		vec2 g = vec2(u, y - 1.0) / vec2(3.0, 3.2);
		vec2 f = fract(g);
		if (y > 1.0 && f.x > 0.33 && f.x < 0.67 && f.y > 0.3 && f.y < 0.8) {
			float shut = hash(floor(g) + floor(world_pos.xz / 20.0));
			base = shut < 0.5
				? vec3(0.32, 0.27, 0.22) * (0.8 + 0.2 * step(0.5, fract(f.y * 9.0)))
				: vec3(0.06, 0.05, 0.05);
		}
		base *= mix(0.7, 1.0, smoothstep(0.0, 2.5, y));  // splashback dust
	}
	if (look > 3.5 && look < 4.5) {
		// Rock: two octaves of mottling, faint strata.
		vec2 q = world_pos.xz + vec2(world_pos.y * 0.7);
		float n = vnoise(q * 0.07) * 0.6 + vnoise(q * 0.45) * 0.4;
		base = body * mix(0.55, 1.25, n) * (0.92 + 0.08 * sin(world_pos.y * 1.6));
	} else if (look > 4.5 && look < 5.5 && world_normal.y > 0.5) {
		// Paving: 1.5 m slabs, each a shade off, dark joints.
		vec2 t = world_pos.xz / 1.5;
		vec2 j = fract(t);
		float joint = max(step(j.x, 0.04), step(j.y, 0.04));
		base *= mix(0.9 + 0.16 * hash(floor(t)), 0.62, joint);
	} else if (look > 5.5 && wall) {
		// Corrugated metal: vertical ribs every 0.6 m.
		base *= 0.84 + 0.16 * sin(u * 10.5);
	}
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = glow;
}
"""

static var _shader: Shader


static func building(
	tint: Color, look: Look, unit: float = 1.0, anchored: bool = false
) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("look_override", float(look))
	m.set_shader_parameter("unit", unit)
	m.set_shader_parameter("anchored", anchored)
	return m
