shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float grain_strength : hint_range(0.0, 0.15) = 0.045;
uniform float low_moral_amount : hint_range(0.0, 1.0) = 0.0;
uniform float shake_amount : hint_range(0.0, 0.02) = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (shake_amount > 0.0001) {
		uv.x += sin(TIME * 48.0) * shake_amount;
		uv.y += cos(TIME * 37.0) * shake_amount * 0.7;
	}
	uv = clamp(uv, vec2(0.001), vec2(0.999));

	vec4 tex = texture(screen_texture, uv);
	vec3 col = tex.rgb;

	// Luminance argentique
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float contrast_luma = clamp((luma - 0.5) * 1.24 + 0.48, 0.0, 1.0);
	vec3 mono = vec3(contrast_luma);

	// Preservation selective des 4 couleurs-signaux la nuit :
	// 1) Rouge fanzine / Zone, 2) Orange sodium, 3) Bleu electrique, 4) Halo pale Poudrerie
	float red_signal = smoothstep(0.18, 0.45, col.r - max(col.g, col.b) * 0.85);
	float orange_signal = smoothstep(0.16, 0.40, (col.r * 0.65 + col.g * 0.35) - col.b * 1.1) * step(0.15, col.g);
	float blue_signal = smoothstep(0.16, 0.42, col.b - max(col.r, col.g) * 0.88);
	float halo_signal = smoothstep(0.12, 0.32, (col.g * 0.45 + col.b * 0.55) - col.r * 0.95);
	float keep_signal = clamp(max(max(red_signal, orange_signal), max(blue_signal, halo_signal)), 0.0, 1.0);

	vec3 night_col = mix(mono, col * 1.15, keep_signal * 0.92);
	col = mix(col, night_col, night_amount);

	// Grain pellicule 16mm 1982
	float n = hash12(uv * vec2(1280.0, 720.0) + floor(TIME * 18.0) * 13.7);
	float grain = (n - 0.5) * (grain_strength + night_amount * 0.02 + low_moral_amount * 0.025);
	col += vec3(grain);

	// Vignettage discret amplifie la nuit ou sous bas Moral
	vec2 centered = uv - vec2(0.5);
	float dist = dot(centered, centered);
	float vig_power = mix(0.12, 0.58, clamp(night_amount * 0.75 + low_moral_amount * 0.35, 0.0, 1.0));
	col *= 1.0 - dist * vig_power;

	COLOR = vec4(clamp(col, 0.0, 1.0), tex.a);
}
