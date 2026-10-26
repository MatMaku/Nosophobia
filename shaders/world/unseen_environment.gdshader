shader_type canvas_item;
render_mode unshaded;

uniform sampler2D world_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float unseen_brightness : hint_range(0.1, 1.0) = 0.45;

void fragment() {
	vec3 world = textureLod(world_texture, SCREEN_UV, 0.0).rgb;
	float gray = dot(world, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(vec3(gray * unseen_brightness), 1.0);
}
