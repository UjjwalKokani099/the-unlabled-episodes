// UNLABELED surface shader: every wall, floor and ceiling in the building kit uses it.
//
// - World-space projection: no UVs needed, textures continue seamlessly across modular
//   pieces and keep a real size (tile_size = metres covered by one texture repeat).
//   Projects along whichever axis the surface faces (the kit is axis-aligned).
// - Macro variation: large soft blotches break up visible texture repetition.
// - Weathering per storey (walls only): rising damp at the bottom of each storey with a
//   dark tide line, rain/leak streaks running down from under each slab, grime near the top.
//   Storeys are storey_height metres tall starting at storey_base (world Y).
// Works with baked lightmaps (LightmapGI) and the Graphics presets.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

group_uniforms textures;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metallic_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
/** Metres covered by one repeat of the texture. */
uniform float tile_size = 2.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float roughness_offset : hint_range(-1.0, 1.0) = 0.0;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.0;

group_uniforms color;
/** Paint colour multiplied over the texture (white = texture's own colour). */
uniform vec4 tint : source_color = vec4(1.0);
/** Large-scale blotchy variation to hide repetition. */
uniform float macro_strength : hint_range(0.0, 1.0) = 0.3;
uniform float macro_size = 4.0;

group_uniforms dado;
/** Two-tone wall: lower band painted a different (usually darker, glossier) colour. 0 = off. */
uniform float dado_height = 0.0;
uniform vec4 dado_tint : source_color = vec4(0.45, 0.55, 0.5, 1.0);
uniform float dado_roughness_offset : hint_range(-1.0, 0.0) = -0.25;

group_uniforms weathering;
uniform float storey_base = 0.0;
uniform float storey_height = 3.0;
/** Height of the rising-damp band above each storey's floor (0 = none). */
uniform float damp_height = 0.0;
uniform float damp_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec4 damp_color : source_color = vec4(0.42, 0.38, 0.28, 1.0);
/** Leak/rain streaks running down from under each slab. */
uniform sampler2D leak_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float leak_strength : hint_range(0.0, 1.0) = 0.0;
uniform float leak_tile = 2.5;
/** Darkening in the top part of each storey (soot, cobwebs, missed paint). */
uniform float top_grime : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * value_noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 an = abs(n);
	vec2 plane;  // metres on the projection plane (u right, v up)
	vec3 tangent;
	vec3 bitangent;
	bool is_wall = true;
	if (an.y >= an.x && an.y >= an.z) {
		plane = vec2(world_pos.x, -world_pos.z * sign(n.y));
		tangent = vec3(1.0, 0.0, 0.0);
		bitangent = vec3(0.0, 0.0, -sign(n.y));
		is_wall = false;
	} else if (an.x >= an.z) {
		plane = vec2(-world_pos.z * sign(n.x), world_pos.y);
		tangent = vec3(0.0, 0.0, -sign(n.x));
		bitangent = vec3(0.0, 1.0, 0.0);
	} else {
		plane = vec2(world_pos.x * sign(n.z), world_pos.y);
		tangent = vec3(sign(n.z), 0.0, 0.0);
		bitangent = vec3(0.0, 1.0, 0.0);
	}
	// Texture v runs downward, so flip it to keep textures upright.
	vec2 uv = vec2(plane.x, -plane.y) / tile_size;

	vec3 albedo = texture(albedo_tex, uv).rgb * tint.rgb;
	float roughness = texture(roughness_tex, uv).r;

	// Macro variation (world-space, independent of tiling).
	float macro = fbm(plane / macro_size + vec2(world_pos.y * 0.07, 0.0));
	albedo *= mix(1.0, 0.72 + 0.56 * macro, macro_strength);

	if (is_wall) {
		float h = mod(world_pos.y - storey_base, storey_height);  // height within storey
		float edge_noise = fbm(plane * 1.7) - 0.5;
		// Dado band: repaint the lower part, with a thin dark dividing line.
		if (dado_height > 0.0 && h < dado_height + 0.012) {
			if (h < dado_height) {
				albedo = albedo / max(tint.rgb, vec3(0.01)) * dado_tint.rgb;
				roughness += dado_roughness_offset;
			} else {
				albedo *= 0.55;
			}
		}
		// Rising damp: darker, browner band with a ragged tide line.
		if (damp_height > 0.0) {
			float line_h = damp_height * (1.0 + edge_noise * 0.6);
			float damp = 1.0 - smoothstep(line_h * 0.55, line_h, h);
			float tide = smoothstep(0.07, 0.0, abs(h - line_h)) * 0.6;
			albedo = mix(albedo, albedo * damp_color.rgb, damp * damp_strength);
			albedo *= 1.0 - tide * damp_strength * 0.45;
			roughness = mix(roughness, roughness * 0.8, damp * damp_strength);
		}
		// Leak streaks hang from the top of each storey and fade downward.
		if (leak_strength > 0.0) {
			float leak = 1.0 - texture(leak_tex, vec2(plane.x, -h) / leak_tile).r;
			float fade = smoothstep(storey_height * 0.15, storey_height, h + edge_noise * 0.4);
			albedo *= 1.0 - leak * leak_strength * fade * 0.85;
		}
		if (top_grime > 0.0) {
			float grime = smoothstep(storey_height * 0.65, storey_height, h) * (0.6 + 0.4 * macro);
			albedo *= 1.0 - grime * top_grime * 0.5;
		}
	}

	ALBEDO = albedo;
	ROUGHNESS = clamp(roughness + roughness_offset, 0.04, 1.0);
	METALLIC = texture(metallic_tex, uv).r * metallic_amount;

	// Godot stores imported normal maps as two channels (X, Y): rebuild Z ourselves.
	vec3 tn;
	tn.xy = texture(normal_tex, uv).rg * 2.0 - 1.0;
	tn.z = sqrt(max(0.0, 1.0 - dot(tn.xy, tn.xy)));
	tn.xy *= normal_strength;
	vec3 world_bumped = normalize(tangent * tn.x + bitangent * tn.y + n * max(tn.z, 0.001));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_bumped, 0.0)).xyz);
}
