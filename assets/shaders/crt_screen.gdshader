// CRT glass showing a 2D picture (the main menu on Nikhil's TV): barrel curvature,
// RGB scanlines, a slow rolling brightness bar, flicker, glass vignette.
// `screen_tex` = a SubViewport texture. Keep `curvature` in sync with
// scripts/ui/main_menu.gd (mouse clicks are mapped through the same distortion).
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D screen_tex : source_color, filter_linear;
uniform float curvature = 0.12;
uniform float brightness = 1.0;
uniform float scanlines = 0.22;
uniform float flicker = 0.03;

vec2 distort(vec2 uv) {
	vec2 c = uv - 0.5;
	c *= 1.0 + curvature * dot(c, c);
	return c + 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = distort(UV);
	vec3 col = vec3(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		// Slight horizontal bleed, like a cheap composite signal.
		float px = 1.0 / 960.0;
		col = texture(screen_tex, uv).rgb * 0.7
			+ texture(screen_tex, uv + vec2(px * 1.5, 0.0)).rgb * 0.15
			+ texture(screen_tex, uv - vec2(px * 1.5, 0.0)).rgb * 0.15;
		float line = 0.5 + 0.5 * sin(uv.y * 720.0 * 3.14159);
		col *= 1.0 - scanlines * line;
		float roll = 0.93 + 0.07 * smoothstep(0.0, 0.15, abs(fract(uv.y * 0.5 - TIME * 0.05) - 0.5));
		col *= roll;
		col += (hash(floor(uv * vec2(480.0, 360.0)) + floor(TIME * 24.0)) - 0.5) * 0.04;
	}
	col *= 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 47.0));
	vec2 d = UV - 0.5;
	col *= clamp(1.0 - dot(d, d) * 1.3, 0.0, 1.0);  // curved-glass falloff
	ALBEDO = col * brightness;
}
