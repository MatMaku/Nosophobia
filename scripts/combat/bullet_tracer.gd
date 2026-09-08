extends Node2D
## Presentation only. Endpoints are fixed in world space, independent of the shooter.

@export_range(0.01, 2.0, 0.01) var tracer_lifetime: float = 0.2
@export_range(0.0, 1.0, 0.01) var hold_time: float = 0.04

@onready var _line: Line2D = $Line2D


func show_segment(start: Vector2, end: Vector2) -> void:
	_line.points = PackedVector2Array([to_local(start), to_local(end)])
	var tween := create_tween()
	tween.tween_interval(minf(hold_time, tracer_lifetime))
	tween.tween_property(_line, "modulate:a", 0.0, maxf(0.01, tracer_lifetime - hold_time))
	tween.tween_callback(queue_free)
