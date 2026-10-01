shader_type canvas_item;
render_mode unshaded;

uniform sampler2D visibility_mask : filter_linear, repeat_disable;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Screen-space radius: independent of the light's shadow-atlas quadrants.
uniform float edge_filter_pixels : hint_range(0.0, 3.0, 0.25) = 1.5;

void fragment() {
	float center = texture(visibility_mask, SCREEN_UV).r;
	vec2 step_uv = edge_filter_pixels / vec2(textureSize(visibility_mask, 0));
	float filtered = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			float weight = float((x == 0 ? 2 : 1) * (y == 0 ? 2 : 1));
			filtered += texture(visibility_mask,
				SCREEN_UV + vec2(float(x), float(y)) * step_uv).r * weight;
		}
	}
	// Soften only inward: a hidden pixel must never become visible through filtering.
	float visibility = clamp(min(center, filtered / 16.0), 0.0, 1.0);
	// Opaque replacement at zero visibility, independent of the world's brightness.
	COLOR = vec4(fog_color.rgb, 1.0 - visibility);
}
