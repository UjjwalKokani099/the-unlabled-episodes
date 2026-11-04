// Blurred, darkened copy of the screen behind a UI overlay (inspect view, later menus).
// Manual 25-tap blur (works on Forward+ and the web's Compatibility renderer, which has no
// screen-texture mipmaps).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float radius_px = 6.0;
uniform float darken : hint_range(0.0, 1.0) = 0.62;
uniform vec3 tint : source_color = vec3(0.9, 0.92, 1.0);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius_px;
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.0);
			sum += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px).rgb * w;
			wsum += w;
		}
	}
	vec3 col = sum / wsum;
	COLOR = vec4(col * tint * (1.0 - darken), 1.0);
}
