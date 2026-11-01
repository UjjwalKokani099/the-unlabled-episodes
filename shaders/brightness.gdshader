// Global brightness (gamma) from Settings.brightness. Drawn by the Settings autoload on
// canvas layer 5: above the 3D view and VHS effect, below the HUD and menus.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float brightness = 1.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(pow(max(c, vec3(0.0)), vec3(1.0 / brightness)), 1.0);
}
