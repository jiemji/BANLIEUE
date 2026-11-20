shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.95, 0.93, 0.87, 0.90);
uniform float outline_px = 2.0;
uniform vec2 render_size = vec2(60.0, 170.0);
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	// Convertir outline_px (en pixels ecran) vers UV de la texture
	vec2 px_uv = (outline_px * (tex_size / max(render_size, vec2(1.0)))) / max(tex_size, vec2(1.0));

	float max_a = 0.0;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * (6.2831853 / 12.0);
		vec2 dir = vec2(cos(ang), sin(ang));
		max_a = max(max_a, texture(TEXTURE, UV + dir * px_uv).a);
		max_a = max(max_a, texture(TEXTURE, UV + dir * px_uv * 0.55).a);
	}

	vec4 body = vec4(base.rgb * tint_color.rgb, base.a * tint_color.a);
	if (base.a >= 0.50) {
		COLOR = body;
	} else if (max_a >= 0.42) {
		float edge_a = smoothstep(0.42, 0.84, max_a) * outline_color.a;
		float blend = clamp(base.a / 0.50, 0.0, 1.0);
		vec3 col_mix = mix(outline_color.rgb, body.rgb, blend);
		COLOR = vec4(col_mix, max(edge_a, body.a));
	} else {
		COLOR = vec4(0.0);
	}
}
