shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.05, 0.02, 0.025, 1.0);
uniform float outline_size : hint_range(0.0, 10.0) = 1.25;
uniform int pattern : hint_range(0, 2) = 1; // diamond, circle, square
uniform float top_left_outline_scale : hint_range(0.0, 1.0) = 0.55;
uniform bool inside = false;
uniform bool add_margins = true;
uniform vec2 number_of_images = vec2(1.0);

varying flat vec4 vertex_modulate;

void vertex() {
	vertex_modulate = COLOR;

	if (add_margins) {
		vec2 direction = step(vec2(0.5), UV) * 2.0 - 1.0;
		VERTEX += direction * outline_size;
	}
}

bool has_contrary_neighbour(vec2 uv, vec2 texture_pixel_size, vec2 image_top_left, vec2 image_bottom_right, sampler2D texture_sampler) {
	for (float i = -ceil(outline_size); i <= ceil(outline_size); i++) {
		float x_limit = i > 0.0 ? outline_size * top_left_outline_scale : outline_size;
		float x = abs(i) > x_limit ? x_limit * sign(i) : i;
		float offset = outline_size;

		if (pattern == 0) {
			offset = outline_size - abs(x);
		} else if (pattern == 1) {
			offset = floor(sqrt(pow(outline_size + 0.5, 2.0) - x * x));
		}

		for (float j = -ceil(offset); j <= ceil(offset); j++) {
			float y_limit = j > 0.0 ? offset * top_left_outline_scale : offset;
			float y = abs(j) > y_limit ? y_limit * sign(j) : j;
			vec2 sample_uv = uv + texture_pixel_size * vec2(x, y);
			bool outside_image = sample_uv != clamp(sample_uv, image_top_left, image_bottom_right);
			bool empty_pixel = outside_image || texture(texture_sampler, sample_uv).a <= 0.0;

			if (empty_pixel == inside) {
				return true;
			}
		}
	}

	return false;
}

void fragment() {
	vec2 uv = UV;
	vec2 image_top_left = floor(uv * number_of_images) / number_of_images;
	vec2 image_bottom_right = image_top_left + vec2(1.0) / number_of_images;

	if (add_margins) {
		vec2 texture_pixel_size = vec2(1.0) / (vec2(1.0) / TEXTURE_PIXEL_SIZE + vec2(outline_size * 2.0) * number_of_images);
		uv = (uv - texture_pixel_size * outline_size - image_top_left) * TEXTURE_PIXEL_SIZE / texture_pixel_size + image_top_left;

		if (uv != clamp(uv, image_top_left, image_bottom_right)) {
			COLOR = vec4(0.0);
		} else {
			COLOR = texture(TEXTURE, uv) * vertex_modulate;
		}
	} else {
		COLOR = texture(TEXTURE, uv) * vertex_modulate;
	}

	if ((COLOR.a > 0.0) == inside && has_contrary_neighbour(uv, TEXTURE_PIXEL_SIZE, image_top_left, image_bottom_right, TEXTURE)) {
		COLOR.rgb = inside ? mix(COLOR.rgb, outline_color.rgb * vertex_modulate.rgb, outline_color.a * vertex_modulate.a) : outline_color.rgb * vertex_modulate.rgb;
		COLOR.a += (1.0 - COLOR.a) * outline_color.a * vertex_modulate.a;
	}
}
