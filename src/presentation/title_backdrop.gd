class_name TitleBackdrop
extends RefCounted
## PRESENTATION — the title screen's night (polish pass, 2026-11-06): the city drawn in one
## canvas shader, so it costs nothing behind the splash. Three ranks of towers in haze with
## their lit rooms, ads breathing on the skyline, the golden colossus between them with its
## arm up, and rain.

const SHADER := """
shader_type canvas_item;

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Towers: returns the skyline height at x for one rank.
float skyline(float x, float width, float seed, float low, float high) {
	float id = floor(x / width);
	return low + hash(id + seed) * (high - low);
}

float box(vec2 p, vec2 centre, vec2 half_size) {
	vec2 d = abs(p - centre) - half_size;
	return step(max(d.x, d.y), 0.0);
}

// The colossus: a figure in boxes, left arm raised with a torch, legs apart.
float colossus(vec2 p) {
	float f = 0.0;
	f = max(f, box(p, vec2(0.0, 0.47), vec2(0.022, 0.05)));  // chest
	f = max(f, box(p, vec2(0.0, 0.54), vec2(0.011, 0.016)));  // head
	f = max(f, box(p, vec2(-0.016, 0.34), vec2(0.009, 0.085)));  // legs
	f = max(f, box(p, vec2(0.016, 0.34), vec2(0.009, 0.085)));
	f = max(f, box(p, vec2(0.031, 0.54), vec2(0.007, 0.07)));  // raised arm
	f = max(f, box(p, vec2(0.031, 0.63), vec2(0.012, 0.012)));  // torch
	f = max(f, box(p, vec2(-0.03, 0.45), vec2(0.007, 0.05)));  // hanging arm
	f = max(f, box(p, vec2(0.0, 0.25), vec2(0.05, 0.012)));  // plinth
	return f;
}

vec3 rooms(vec2 p, float width, float top, float seed, float amount) {
	vec2 grid = vec2(floor(p.x * 120.0), floor(p.y * 90.0));
	float lit = step(1.0 - amount, hash2(grid + seed));
	float frame = step(0.2, fract(p.x * 120.0)) * step(0.25, fract(p.y * 90.0));
	float flicker = 0.85 + 0.15 * sin(TIME * (0.5 + hash2(grid) * 2.0) + hash2(grid) * 6.0);
	vec3 warm = mix(vec3(1.0, 0.72, 0.42), vec3(0.45, 0.8, 0.95), step(0.7, hash2(grid + 9.0)));
	return warm * lit * frame * flicker * step(p.y, top);
}

void fragment() {
	vec2 p = vec2(UV.x * 1.78, 1.0 - UV.y);
	// Night falling into a magenta-brown haze at the horizon.
	vec3 c = mix(vec3(0.17, 0.08, 0.13), vec3(0.02, 0.03, 0.06), smoothstep(0.1, 0.85, p.y));
	// The far rank.
	float far_top = skyline(p.x, 0.07, 3.0, 0.3, 0.62);
	float far_mask = step(p.y, far_top);
	c = mix(c, vec3(0.1, 0.09, 0.13), far_mask);
	c += rooms(p, 0.07, far_top, 2.0, 0.05) * far_mask * 0.25;
	// The gold copy, its glow in the haze round it.
	vec2 g = p - vec2(1.46, 0.0);
	float halo = exp(-dot(g - vec2(0.0, 0.45), g - vec2(0.0, 0.45)) * 11.0);
	c += vec3(0.5, 0.3, 0.1) * halo * (0.5 + 0.06 * sin(TIME * 0.7));
	float figure = colossus(g);
	float light = 0.75 + 0.5 * (g.x + 0.05) / 0.1;
	c = mix(c, vec3(0.92, 0.66, 0.26) * light, figure);
	// Ads on the skyline: slow columns of magenta and cyan.
	float ad_id = floor(p.x / 0.31);
	float ad = box(p, vec2((ad_id + 0.5) * 0.31, 0.36 + hash(ad_id) * 0.1), vec2(0.025, 0.05));
	vec3 ad_col = mix(vec3(0.9, 0.2, 0.6), vec3(0.2, 0.84, 0.9), step(0.5, hash(ad_id + 4.0)));
	c += ad * ad_col * (0.5 + 0.35 * sin(TIME * 0.6 + ad_id));
	// The middle rank.
	float mid_top = skyline(p.x + 0.4, 0.11, 7.0, 0.18, 0.42);
	float mid_mask = step(p.y, mid_top);
	c = mix(c, vec3(0.05, 0.05, 0.07), mid_mask);
	c += rooms(p, 0.11, mid_top, 5.0, 0.1) * mid_mask * 0.6;
	// The near rank, his side: low and nearly black.
	float near_top = skyline(p.x + 0.9, 0.17, 11.0, 0.06, 0.2);
	float near_mask = step(p.y, near_top);
	c = mix(c, vec3(0.015, 0.016, 0.02), near_mask);
	c += rooms(p, 0.17, near_top, 8.0, 0.03) * near_mask;
	// The menu reads against a dim centre column.
	c *= 1.0 - 0.6 * exp(-pow((UV.x - 0.5) * 3.2, 2.0));
	// Rain.
	vec2 r = vec2(UV.x * 300.0 + UV.y * 22.0, UV.y * 9.0 - TIME * 6.0);
	float drop = step(0.975, hash2(floor(r))) * smoothstep(0.0, 0.5, fract(r.y));
	c += vec3(0.5, 0.56, 0.65) * drop * 0.14;
	float grain = fract(sin(dot(UV * 731.0 + TIME, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(c + (grain - 0.5) * 0.02, 1.0);
}
"""
