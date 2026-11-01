// Dim TV snow for the main menu background, with a slow dark rolling bar.
shader_type canvas_item;

uniform float strength = 0.16;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / 3.0);
	float snow = hash(cell + floor(TIME * 24.0) * vec2(3.1, 7.7));
	float bar = smoothstep(0.0, 0.12, abs(fract(UV.y * 0.6 - TIME * 0.06) - 0.5));
	vec3 col = vec3(snow) * strength * (0.45 + 0.55 * bar);
	vec2 d = UV - 0.5;
	col *= 1.0 - dot(d, d) * 1.6;
	COLOR = vec4(col, 1.0);
}
