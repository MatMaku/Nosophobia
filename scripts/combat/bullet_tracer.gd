extends Node2D
## Presentation only. Endpoints are fixed in world space, independent of the shooter.

@export_range(0.01, 2.0, 0.01) var tracer_lifetime: float = 0.45
@export_range(0.0, 1.0, 0.01) var hold_time: float = 0.04
@export_range(2, 32, 1) var tracer_segment_count: int = 12
@export_range(0.0, 10.0, 0.1) var tracer_noise_amplitude: float = 3.0
@export_range(0.5, 5.0, 0.1) var tracer_noise_frequency: float = 2.0

@onready var _line: Line2D = $Line2D
var _random := RandomNumberGenerator.new()


func show_segment(start: Vector2, end: Vector2) -> void:
	var perpendicular := (end - start).normalized().orthogonal()
	var phase := _random.randf_range(0.0, TAU)
	var amplitude := minf(tracer_noise_amplitude, start.distance_to(end) * 0.02)
	var points := PackedVector2Array([to_local(start)])
	for index in range(1, tracer_segment_count):
		var t := float(index) / tracer_segment_count
		var wave := sin(t * TAU * tracer_noise_frequency + phase)
		wave += 0.3 * sin(t * TAU * tracer_noise_frequency * 0.5 + phase)
		var noise := sin(t * PI) * wave / 1.3
		points.append(to_local(start.lerp(end, t) + perpendicular * noise * amplitude))
	points.append(to_local(end))
	_line.points = points
	var dissolve := _line.material as ShaderMaterial
	dissolve.set_shader_parameter("seed", _random.randf_range(0.0, 1000.0))
	var tween := create_tween()
	tween.tween_interval(minf(hold_time, tracer_lifetime))
	tween.tween_method(func(progress: float):
		dissolve.set_shader_parameter("fade_progress", progress),
		0.0, 1.0, maxf(0.01, tracer_lifetime - hold_time))
	tween.tween_callback(queue_free)
