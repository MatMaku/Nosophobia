shader_type canvas_item;

// Line2D tiles X and owns the joins. Slice Y keeps the border bands unscaled.
uniform float wall_width = 16.0;
uniform float border_width : hint_range(0.0, 6.0) = 2.0;
varying vec4 wall_tint;

void vertex() {
	wall_tint = COLOR;
}

void fragment() {
	float source_height = 1.0 / TEXTURE_PIXEL_SIZE.y;
	float border = min(border_width, min(wall_width, source_height) * 0.49);
	float y = UV.y * wall_width;
	if (y < border) {
		y = y / source_height;
	} else if (y > wall_width - border) {
		y = 1.0 - (wall_width - y) / source_height;
	} else {
		y = (border + (y - border) / (wall_width - 2.0 * border)
			* (source_height - 2.0 * border)) / source_height;
	}
	COLOR = wall_tint * texture(TEXTURE, vec2(UV.x, y));
}
