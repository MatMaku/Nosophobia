shader_type canvas_item;

uniform sampler2D hidden_mask : filter_nearest, repeat_disable;
uniform bool mask_ready = false;

void fragment() {
	COLOR.a *= mask_ready ? 1.0 - texture(hidden_mask, SCREEN_UV).r : 0.0;
}
