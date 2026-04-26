shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.05, 0.02, 0.025, 1.0);
uniform float outline_size = 1.25;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 step_size = TEXTURE_PIXEL_SIZE * outline_size;
	float outline_alpha = 0.0;

	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-step_size.x, 0.0)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0.0, -step_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0.0, step_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-step_size.x, -step_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(step_size.x, -step_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-step_size.x, step_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(step_size.x, step_size.y)).a);

	float edge_alpha = max(outline_alpha - tex.a, 0.0);
	vec4 edge = vec4(outline_color.rgb, outline_color.a * edge_alpha);
	COLOR = mix(edge, tex, tex.a);
}
