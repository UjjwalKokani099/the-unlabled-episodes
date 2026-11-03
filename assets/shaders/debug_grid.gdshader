// World-space grid for grey-box test geometry: 1 m cells, so you can judge
// distances and see movement. Cheap: no textures, no specular.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 base_color : source_color = vec3(0.4);
uniform vec3 line_color : source_color = vec3(0.22);
uniform float cell_size = 1.0;
uniform float line_px = 1.2;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec3 p = world_pos / cell_size;
	// Project onto whichever axis plane the surface faces most.
	vec2 uv = (n.y > n.x && n.y > n.z) ? p.xz : ((n.x > n.z) ? p.zy : p.xy);
	vec2 dist = abs(fract(uv - 0.5) - 0.5) / fwidth(uv);
	float line = 1.0 - clamp(min(dist.x, dist.y) / line_px, 0.0, 1.0);
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 0.95;
}
