shader_type canvas_item;
render_mode unshaded;

uniform sampler2D visibility_mask : filter_linear, repeat_disable;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	float visibility = clamp(texture(visibility_mask, SCREEN_UV).r, 0.0, 1.0);
	// Opaque replacement at zero visibility, independent of the world's brightness.
	COLOR = vec4(fog_color.rgb, 1.0 - visibility);
}
