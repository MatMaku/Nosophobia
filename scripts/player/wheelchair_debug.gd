extends Node2D
## Disposable prototype drawing; removing this node does not affect controls.

const WheelchairInput = preload("res://scripts/player/wheelchair_input.gd")

@export var mouse_input: WheelchairInput


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(mouse_input):
		return
	var radius := mouse_input.interaction_radius
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.8, 0.9, 0.06))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(0.3, 0.8, 0.9, 0.6), 2.0, true)
	# Front arrow stays visible even with no active drag.
	draw_line(Vector2(0, -20), Vector2(0, -43), Color.YELLOW, 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -49), Vector2(-6, -38), Vector2(6, -38)
	]), Color.YELLOW)
	var cursor := mouse_input.mouse_local_position
	draw_circle(cursor, 5.0, Color.CYAN if mouse_input.drag_active else Color.GRAY)
	if mouse_input.drag_active:
		var start := to_local(mouse_input.drag_start_global_position)
		draw_circle(start, 6.0, Color.ORANGE, false, 2.0, true)
		draw_line(start, cursor, Color(1, 0.65, 0.15, 0.6), 1.0, true)
		# The short cyan vector shows actual recent motion, not the accumulated drag.
		draw_line(cursor, cursor + mouse_input.local_mouse_displacement * 5.0,
			Color.CYAN, 3.0, true)
