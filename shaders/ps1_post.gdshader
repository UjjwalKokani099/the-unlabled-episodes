// PS1 mode post-process (Settings.ps1_mode): the 3D picture is resampled to `lines`
// rows with nearest filtering (chunky low-res pixels), then quantised to 15-bit colour
// (5 bits per channel) with a 4x4 ordered (Bayer) dither in that low-res grid.
// Sits under the camcorder OSD and the VHS effect (scripts/ui/camcorder.gd), so the
// tape look still goes on top.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float lines = 480.0;
uniform float levels = 31.0;      // 5 bits per channel
uniform float dither = 1.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	// 4x4 Bayer matrix, row-major.
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;  // width / height
	vec2 cells = vec2(floor(lines * aspect), lines);
	vec2 cell = floor(SCREEN_UV * cells);
	vec3 col = texture(screen_tex, (cell + 0.5) / cells).rgb;
	col += bayer4(cell) * dither / levels;
	col = floor(col * levels + 0.5) / levels;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
