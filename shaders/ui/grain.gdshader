shader_type canvas_item;
render_mode unshaded;

uniform float grain_intensity : hint_range(0.0, 0.15) = 0.018;
uniform float grain_scale : hint_range(1.0, 6.0) = 1.0;
uniform float grain_update_rate : hint_range(1.0, 30.0) = 16.0;

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / grain_scale);
	float tick = floor(TIME * grain_update_rate);
	float noise = fract(sin(dot(cell, vec2(12.9898, 78.233)) + tick * 37.719) * 43758.5453);
	float value = step(0.5, noise);
	COLOR = vec4(vec3(value), abs(noise - 0.5) * 2.0 * grain_intensity);
}
