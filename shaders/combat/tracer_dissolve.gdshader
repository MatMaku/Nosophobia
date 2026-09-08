shader_type canvas_item;

uniform float fade_progress : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_intensity : hint_range(0.0, 1.0) = 0.9;
uniform float seed = 0.0;

float hash(float x) {
	return fract(sin(x * 127.1 + seed * 31.7) * 43758.5453);
}

float noise(float x) {
	float cell = floor(x);
	float weight = smoothstep(0.0, 1.0, fract(x));
	return mix(hash(cell), hash(cell + 1.0), weight);
}

void fragment() {
	float threshold = 0.12 + noise(UV.x * 18.0) * 0.6;
	float dissolve = 1.0 - smoothstep(threshold, threshold + 0.28, fade_progress);
	float edge = smoothstep(0.0, 0.24, UV.y) * smoothstep(0.0, 0.24, 1.0 - UV.y);
	COLOR.a *= edge * mix(1.0 - fade_progress, dissolve, dissolve_intensity);
}
