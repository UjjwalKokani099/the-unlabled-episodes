// Hanging fabric (clothes on a line, curtains, towels): a subdivided QuadMesh pushed
// along its normal into vertical drape folds, swaying more toward the hem (fan draft /
// night breeze). Normals follow the folds so they catch the light; a fine weave and
// optional stripes/checks break up the flat colour. Built by tools/propkit.py `cloth()`.
// UV (0,0) = top-left corner (the hung edge). Don't batch these (StaticBatcher): they
// live under the level's Props node.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 albedo : source_color = vec3(0.4, 0.3, 0.25);
uniform vec3 stripe_color : source_color = vec3(0.8, 0.78, 0.7);
// x = vertical stripes across the width, y = horizontal ones down the length (0 = none).
uniform vec2 stripes = vec2(0.0, 0.0);
uniform float stripe_width : hint_range(0.0, 1.0) = 0.18;
uniform vec2 size = vec2(0.5, 0.8);          // QuadMesh size in metres
uniform float folds = 3.0;                   // fold count across the width
uniform float fold_depth = 0.025;            // metres
uniform float gather = 0.0;                  // curtains: folds deepen toward the top
uniform float sway = 0.03;                   // metres at the hem
uniform float sway_speed = 1.3;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.95;
uniform float wear : hint_range(0.0, 1.0) = 0.25;  // faded / grimy toward the hem

varying float v_hem;

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	float phase = dot(NODE_POSITION_WORLD, vec3(1.7, 0.0, 2.3));
	float u = UV.x;
	float v = UV.y;
	// Folds: a main wave plus an irregular second one so it doesn't look like corrugation.
	float depth = fold_depth * (1.0 + gather * (1.0 - v) * 1.5);
	float k1 = folds * TAU;
	float k2 = folds * 2.3 * TAU;
	float fold = sin(u * k1 + phase) * 0.75 + sin(u * k2 + phase * 1.7) * 0.25;
	float dfold_du = cos(u * k1 + phase) * 0.75 * k1 + cos(u * k2 + phase * 1.7) * 0.25 * k2;
	// Sway: zero at the hung edge, strongest at the hem.
	float t = TIME * sway_speed + phase;
	float hem = v * v;
	float swing = (sin(t) * 0.7 + sin(t * 2.13 + u * 3.0) * 0.3) * sway * hem;
	float dswing_dv = (sin(t) * 0.7 + sin(t * 2.13 + u * 3.0) * 0.3) * sway * 2.0 * v;
	float d = fold * depth + swing;
	VERTEX += NORMAL * d;
	// Normal from the surface slope (UV runs +X across, +Y down = -Y in the quad).
	float slope_x = dfold_du * depth / size.x;
	float slope_y = -dswing_dv / size.y;
	NORMAL = normalize(NORMAL - TANGENT * slope_x - BINORMAL * slope_y);
	v_hem = v;
}

void fragment() {
	vec3 col = albedo;
	if (stripes.x > 0.0) {
		col = mix(col, stripe_color, step(1.0 - stripe_width, fract(UV.x * stripes.x)) * 0.85);
	}
	if (stripes.y > 0.0) {
		col = mix(col, stripe_color, step(1.0 - stripe_width, fract(UV.y * stripes.y)) * 0.6);
	}
	// Weave + blotchy fading.
	vec2 p = UV * size * 900.0;
	float weave = (sin(p.x) * sin(p.y)) * 0.04;
	float blotch = vnoise(UV * size * 6.0) * 0.18 - 0.09;
	col *= 1.0 + weave + blotch;
	col = mix(col, col * vec3(0.82, 0.8, 0.74), wear * v_hem);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.2;
	// Thin fabric lets a little light through (backlit curtains, shirts in lamplight).
	BACKLIGHT = col * 0.35;
}
