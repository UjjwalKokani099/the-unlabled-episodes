// CRT screen for the hub TV. mode 0 = snow/static, 1 = VCR blue screen, 2 = off.
shader_type spatial;
render_mode unshaded;

uniform int mode = 0;
uniform float brightness = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col;
	if (mode == 0) {
		float frame = floor(TIME * 30.0);
		float snow = hash(floor(uv * vec2(180.0, 135.0)) + frame * vec2(1.7, 9.2));
		float roll = 0.8 + 0.2 * sin(uv.y * 7.0 - TIME * 3.0);
		col = vec3(snow * roll * 0.85);
	} else if (mode == 1) {
		col = vec3(0.04, 0.1, 0.72) * (0.94 + 0.06 * sin(uv.y * 320.0));
	} else {
		col = vec3(0.015);
	}
	vec2 d = uv - 0.5;
	col *= 1.0 - dot(d, d) * 1.4;  // curved-glass falloff
	ALBEDO = col * brightness;
}
