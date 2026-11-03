// Grounded horror "real lens" grade, drawn over the 3D view by the Graphics autoload
// (canvas layer 1, under the camcorder OSD/VHS and the HUD). Works in Forward+ and
// Compatibility (web). One pass, 7 texture taps.
//
// What it does, in order: slight barrel lens + radial colour fringing, a little sharpening
// (3D renders below 100%), a filmic S-curve that crushes the blacks so darkness reads as
// darkness, cool/green shadows + warm highlights, a touch of desaturation, soft film grain
// that lives mostly in the shadows, and a lens vignette.
// `amount` = Settings.film_look (0 = off: the layer is hidden instead).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float distortion = 0.035;        // barrel lens (0 = flat)
uniform float fringe_px = 1.4;           // colour fringing at the corners, in pixels
uniform float sharpen = 0.35;
uniform float contrast = 1.14;
uniform float black_crush = 0.025;       // values below this go to black
uniform float saturation = 0.86;
uniform vec3 shadow_tint : source_color = vec3(0.86, 0.97, 1.0);
uniform vec3 highlight_tint : source_color = vec3(1.04, 0.99, 0.9);
uniform float grain = 0.045;
uniform float vignette = 0.5;
// Fear: Graphics/levels raise this as danger grows (narrower, darker, noisier picture).
uniform float dread : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 c = SCREEN_UV - 0.5;
	float aspect = px.y / px.x;  // width / height
	vec2 ca = vec2(c.x * aspect, c.y);
	float r2 = dot(ca, ca);

	// Barrel distortion, zoomed so the edges never sample outside the frame.
	float k = distortion * amount;
	vec2 uv = 0.5 + c * (1.0 + k * r2) / (1.0 + k * (0.25 * aspect * aspect + 0.25));

	// Radial chromatic fringing (zero in the middle, strongest in the corners).
	vec2 dir = c / max(length(c), 1e-4) * r2 * 2.0 * fringe_px * amount * px;
	vec3 col;
	col.r = texture(screen_tex, uv + dir).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir).b;

	// Unsharp mask (cross pattern).
	vec3 blur = (texture(screen_tex, uv + vec2(px.x, 0.0)).rgb + texture(screen_tex, uv - vec2(px.x, 0.0)).rgb
			+ texture(screen_tex, uv + vec2(0.0, px.y)).rgb + texture(screen_tex, uv - vec2(0.0, px.y)).rgb) * 0.25;
	vec3 src = col;
	col = max(col + (col - blur) * sharpen * amount, vec3(0.0));

	// Filmic curve: crush the toe, gentle S around mid-grey, soft shoulder.
	vec3 g = max(col - black_crush, vec3(0.0)) / (1.0 - black_crush);
	g = clamp((g - 0.42) * contrast + 0.42, 0.0, 1.2);
	g = g / (1.0 + max(g - 0.85, 0.0) * 0.8);

	// Split toning by luminance, then saturation.
	float luma = dot(g, vec3(0.2126, 0.7152, 0.0722));
	vec3 tint = mix(shadow_tint, highlight_tint, smoothstep(0.08, 0.65, luma));
	g *= tint;
	g = mix(vec3(luma), g, saturation - dread * 0.25);

	// Film grain: 24 fps cadence, stronger in the shadows (like a pushed sensor).
	float t = floor(TIME * 24.0);
	float n = hash(FRAGCOORD.xy + t * 37.0) + hash(FRAGCOORD.xy * 1.37 - t * 19.0) - 1.0;
	float shadow_weight = mix(1.4, 0.4, smoothstep(0.0, 0.6, luma));
	g += n * (grain + dread * 0.04) * shadow_weight;

	// Lens vignette (cos^4-ish falloff), tighter with dread.
	float v = 1.0 - r2 * (vignette + dread * 0.9) * 1.6;
	g *= clamp(v, 0.0, 1.0);

	COLOR = vec4(mix(src, max(g, vec3(0.0)), amount), 1.0);
}
