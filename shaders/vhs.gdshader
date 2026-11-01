// Full-screen VHS / camcorder look. Applied by a ColorRect over the 3D view
// (ui/hud/camcorder.tscn). `strength` comes from Settings.screen_effects;
// `glitch` (0..1) is spiked briefly by scares.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
// VCR freeze-frame (the Spot key): judder + a noisy tracking band near the bottom.
uniform float pause_amount : hint_range(0.0, 1.0) = 0.0;
// Camcorder night-vision mode: amplified green picture, extra grain (works even with the
// VHS effect turned down to 0 in Settings).
uniform float night_vision : hint_range(0.0, 1.0) = 0.0;
uniform float aberration_px = 1.6;   // red/blue split, in screen pixels
uniform float bleed = 0.35;          // horizontal colour smear
uniform float noise_amount = 0.055;
uniform float scanline_amount = 0.10;
uniform float vignette = 0.45;
uniform float saturation = 0.78;
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.92);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float t = TIME;

	// Tape wobble + occasional horizontal tracking bands (more of both while glitching).
	float wobble = sin(uv.y * 38.0 + t * 2.7) * 0.0005 * (1.0 + glitch * 6.0);
	float band_row = floor(uv.y * 70.0);
	float band = step(0.994 - glitch * 0.12, hash(vec2(band_row, floor(t * 14.0))));
	float band_shift = band * (hash(vec2(band_row, t)) - 0.5) * (0.012 + glitch * 0.05);
	// Head-switching noise along the bottom edge.
	float bottom = smoothstep(0.975, 1.0, uv.y);
	float bottom_shift = bottom * (hash(vec2(floor(uv.y / px.y), t)) - 0.5) * 0.03;
	uv.x += (wobble + band_shift + bottom_shift) * strength;
	float pause_center = 0.86 + sin(t * 0.7) * 0.03;
	float pause_band = pause_amount * (1.0 - smoothstep(0.0, 0.03, abs(uv.y - pause_center)));
	uv.y += pause_amount * (hash(vec2(floor(t * 24.0), 3.0)) - 0.5) * 0.004;
	uv.x += pause_band * (hash(vec2(floor(uv.y / px.y), floor(t * 30.0))) - 0.5) * 0.09;

	// Chromatic split + smear.
	float ab = aberration_px * (1.0 + glitch * 5.0) * strength * px.x;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ab, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ab, 0.0)).b;
	vec3 smear = (texture(screen_tex, uv + vec2(px.x * 2.5, 0.0)).rgb
			+ texture(screen_tex, uv - vec2(px.x * 2.5, 0.0)).rgb) * 0.5;
	col = mix(col, smear, bleed * strength);

	// Washed-out colour + warm tint.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, mix(vec3(luma), col, saturation) * tint, strength);

	// Night vision: gain with a soft roll-off, green phosphor, noisier.
	float nv_luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 nv = vec3(0.32, 1.0, 0.42) * (1.0 - exp(-nv_luma * 5.0));
	col = mix(col, nv, night_vision);

	// Scanlines (3 px period) and grain.
	float scan = 0.5 + 0.5 * cos(FRAGCOORD.y * TAU / 3.0);
	col *= 1.0 - scanline_amount * scan * strength;
	float grain = hash(floor(FRAGCOORD.xy) + fract(t * 7.3) * 113.0) - 0.5;
	col += grain * noise_amount * (1.0 + glitch * 3.0) * strength;
	col += grain * 0.12 * night_vision;
	col += bottom * grain * 0.4 * strength;
	col = mix(col, vec3(0.55 + grain * 1.6), pause_band * 0.75);

	// Vignette.
	vec2 d = SCREEN_UV - 0.5;
	col *= mix(1.0, clamp(1.0 - dot(d, d) * vignette * 2.2, 0.0, 1.0), strength);
	col *= mix(1.0, clamp(1.0 - dot(d, d) * 2.4, 0.0, 1.0), night_vision);  // tunnel vision

	COLOR = vec4(col, 1.0);
}
