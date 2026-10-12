// PRESENTATION LAYER — the perception post-processing pass.
//
// One screen-space pass drives all four Crash effects the brief names (constraint #5):
//   reduced turn speed  -> handled in logic/presentation rotation, not here
//   blurry vision       -> `blur` (sparse tap defocus)
//   screen shake        -> handled by IsoCameraRig (needs 3D motion, not a UV trick)
//   chromatic aberration-> `ca` (per-channel radial offset)
// plus the High-Focus look (GAME_SPEC.md #1.A: "vibrant edge detection, high contrast")
// and the soft-boundary vignette (constraint #6).
//
// WHY A SCREEN-TEXTURE COLORRECT INSTEAD OF BUILT-INS
// ---------------------------------------------------
// Godot 4 has no built-in chromatic aberration on Environment, and DOF via
// CameraAttributesPhysical would need the room to be re-authored with depth. Sampling
// screen_texture in a full-rect CanvasItem shader gives all three effects in one pass,
// works on every renderer backend (including Compatibility, which a student project on
// a 2014-era laptop may well be forced onto), and exposes every strength as a uniform a
// script can blend. The tradeoff is honest and stated in docs/TICKET-01.md: a blur done
// in screen space cannot be depth-aware, so when Ticket-05 wants the dreamscape to blur
// *background only*, this pass grows a depth variant.
//
// All strengths are driven from PerceptionPostFX.gd off a single normalised intensity
// float, so nothing here knows what "crash" means narratively.

shader_type canvas_item;

// Godot 4.2+ form: hinted sampler2D uniform, not the bare `hint_screen_texture;`
// statement (which 4.7 rejects at parse). This file was never engine-tested until now.
uniform sampler2D screen_texture : hint_screen_texture;

// 0..1 — how deep into the Crash the protagonist is.
uniform float crash_intensity : hint_range(0.0, 1.0) = 0.0;

// 0..1 — High-Focus presence. Contrast and edge lift; the medicated gaze.
uniform float focus_intensity : hint_range(0.0, 1.0) = 0.0;

// 0..1 — SoftBoundaryModel output. Vignette closes in as the room's edge is approached.
uniform float edge_proximity : hint_range(0.0, 1.0) = 0.0;

// Peak radial chromatic split, in UV units, at full crash.
uniform float chroma_scale = 0.014;

// Defocus radius, in UV units, at full crash.
uniform float blur_scale = 0.011;

// Film grain amount at full crash. Low; this should feel clinical, not retro.
uniform float grain_scale = 0.035;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 to_centre = vec2(0.5, 0.5) - uv;
	float rim = length(to_centre);

	// --- CHROMATIC ABERRATION -----------------------------------------------------
	// Scaled by rim so the centre of frame stays sharp. The player must always be able
	// to read the cell they are standing on, or the grid constraint stops being legible.
	float ca = crash_intensity * chroma_scale + edge_proximity * chroma_scale * 0.3;
	vec2 split = to_centre * (ca * (0.35 + rim));

	vec3 col;
	col.r = texture(screen_texture, uv + split).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - split).b;

	// --- BLUR (defocus) -----------------------------------------------------------
	// Six taps plus the centre, offsets deliberately incommensurate so the kernel does
	// not resolve into a visible hexagon at high intensity.
	float blur = crash_intensity * blur_scale + edge_proximity * blur_scale * 0.55;
	if (blur > 0.0004) {
		vec3 acc = col;
		acc += texture(screen_texture, uv + vec2(0.62, 1.10) * blur).rgb;
		acc += texture(screen_texture, uv + vec2(-1.04, 0.51) * blur).rgb;
		acc += texture(screen_texture, uv + vec2(0.29, -0.94) * blur).rgb;
		acc += texture(screen_texture, uv + vec2(-0.71, -0.38) * blur).rgb;
		acc += texture(screen_texture, uv + vec2(1.18, -0.22) * blur).rgb;
		acc += texture(screen_texture, uv + vec2(-0.16, 1.27) * blur).rgb;
		col = mix(col, acc / 7.0, clamp(blur * 60.0, 0.0, 1.0));
	}

	// --- HIGH FOCUS: contrast + edge detection ------------------------------------
	// Placeholder for Ticket-02. A Sobel-ish neighbour difference added back over the
	// image reads as "everything has a wire", which is the drug's spatial mastery: the
	// room stops being a place and starts being a schematic of usable volume.
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	vec3 contrasted = mix(vec3(lum), col, 1.28);
	vec3 gx = texture(screen_texture, uv + vec2(0.0018, 0.0)).rgb
		- texture(screen_texture, uv - vec2(0.0018, 0.0)).rgb;
	vec3 gy = texture(screen_texture, uv + vec2(0.0, 0.0018)).rgb
		- texture(screen_texture, uv - vec2(0.0, 0.0018)).rgb;
	vec3 edges = abs(gx) + abs(gy);
	col = mix(col, contrasted + edges * 0.55, focus_intensity * 0.75);

	// --- SOFT BOUNDARY VIGNETTE ---------------------------------------------------
	// Note the ordered edge0 < edge1: smoothstep with reversed edges is undefined, so the
	// falloff is expressed as 1 - smoothstep and then inverted by the mix weight.
	float vig = 1.0 - smoothstep(0.30, 0.88, rim);
	float vig_strength = clamp(0.20 + 0.60 * edge_proximity + 0.40 * crash_intensity, 0.0, 0.92);
	col *= mix(1.0, vig, vig_strength);

	// --- GRAIN --------------------------------------------------------------------
	float seed = fract(sin(dot(uv * 511.0 + TIME * 0.37, vec2(12.9898, 78.233))) * 43758.5453);
	col += (seed - 0.5) * grain_scale * crash_intensity;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
