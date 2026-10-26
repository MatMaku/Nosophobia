shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size;
uniform vec2 viewer_position;
uniform float clear_radius;
uniform float dark_radius;
uniform float darkness;
uniform int lamp_count = 0;
uniform vec4 lamps[32]; // Screen center, projected radius, relief intensity.
uniform sampler2D hidden_mask : filter_nearest, repeat_disable;
uniform bool has_visibility_mask = false;

void fragment() {
	vec2 pixel = SCREEN_UV * viewport_size;
	float shade = smoothstep(clear_radius, dark_radius, distance(pixel, viewer_position));
	float visible_pixel = has_visibility_mask ? 1.0 - texture(hidden_mask, SCREEN_UV).r : 0.0;
	for (int i = 0; i < lamp_count; i++) {
		float radius = max(lamps[i].z, 1.0);
		float relief = 1.0 - smoothstep(0.0, radius, distance(pixel, lamps[i].xy));
		shade *= 1.0 - clamp(relief * lamps[i].w, 0.0, 1.0) * visible_pixel;
	}
	COLOR = vec4(0.0, 0.0, 0.0, shade * darkness);
}
