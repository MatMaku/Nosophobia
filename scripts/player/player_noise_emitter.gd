extends Node2D
## Read-only signal source for perception. Rolling speed, including inertia, not input.

@export_range(0.0, 500.0, 1.0) var noise_start_speed: float = 20.0
@export_range(1.0, 1000.0, 1.0) var noise_full_speed: float = 120.0
@export_range(0.0, 1000.0, 1.0) var max_movement_noise_radius: float = 220.0
@export var show_noise_debug: bool = true

@onready var _body: RigidBody2D = get_parent()


func radius_for_speed(speed: float) -> float:
	var span := maxf(noise_full_speed - noise_start_speed, 0.001)
	return clampf((absf(speed) - noise_start_speed) / span, 0.0, 1.0) \
		* max_movement_noise_radius


func get_noise_radius() -> float:
	var forward := Vector2.UP.rotated(_body.global_rotation)
	return radius_for_speed(_body.linear_velocity.dot(forward))


func _ready() -> void:
	set_process(show_noise_debug)


func set_debug_visuals_enabled(enabled: bool) -> void:
	visible = enabled and show_noise_debug
	set_process(visible)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if show_noise_debug:
		draw_arc(Vector2.ZERO, get_noise_radius(), 0, TAU, 64, Color.ORANGE, 1.0)
