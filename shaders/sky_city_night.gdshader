// Night sky over an Indian city: deep navy overhead, a dirty orange glow of sodium
// streetlights near the horizon, faint stars (most washed out by light pollution).
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.006, 0.01, 0.026);
uniform vec3 horizon_color : source_color = vec3(0.07, 0.045, 0.03);
uniform vec3 ground_color : source_color = vec3(0.01, 0.009, 0.008);
uniform float glow_height = 0.18;
uniform float star_density = 0.0025;
uniform float star_brightness = 0.6;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	float up = EYEDIR.y;
	vec3 col;
	if (up < 0.0) {
		col = mix(horizon_color * 0.5, ground_color, clamp(-up * 6.0, 0.0, 1.0));
	} else {
		float glow = exp(-up / glow_height);
		col = mix(zenith_color, horizon_color, glow);
		// Stars: sparse, only well above the glow.
		vec3 cell = floor(EYEDIR * 380.0);
		float star = step(1.0 - star_density, hash(cell));
		col += vec3(star * star_brightness * smoothstep(0.15, 0.5, up) * (0.5 + 0.5 * hash(cell + 7.0)));
	}
	COLOR = col;
}
