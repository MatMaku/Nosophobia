extends Node2D
## Gameplay LOS is independent of visual fog. Hearing deliberately ignores walls.

const AI_SIGHT_MASK := 1 << 4
var definition: EnemyDefinition
var target: Node2D
var noise_source: Node2D
var saw_player: bool = false
var detection_enabled: bool = true
var heard_player: bool = false
var show_vision_debug: bool = false
var show_hearing_debug: bool = false
var _forward := Vector2.UP
var _ray := PhysicsRayQueryParameters2D.new()


func sample(forward: Vector2) -> bool:
	_forward = forward
	saw_player = false
	heard_player = false
	if not detection_enabled or definition == null or not is_instance_valid(target):
		if show_vision_debug or show_hearing_debug:
			queue_redraw()
		return false
	var offset := target.global_position - global_position
	if in_vision_cone(offset, forward):
		_ray.from = global_position
		_ray.to = target.global_position
		_ray.collision_mask = AI_SIGHT_MASK
		_ray.collide_with_areas = true
		_ray.collide_with_bodies = false
		_ray.hit_from_inside = true
		saw_player = get_world_2d().direct_space_state.intersect_ray(_ray).is_empty()
	if is_instance_valid(noise_source):
		var radius := minf(definition.hearing_radius, noise_source.get_noise_radius())
		heard_player = radius > 0.0 and offset.length_squared() <= radius * radius
	if show_vision_debug or show_hearing_debug:
		queue_redraw()
	return saw_player or heard_player


func in_vision_cone(offset: Vector2, forward: Vector2) -> bool:
	return offset.length() <= definition.vision_distance and (offset.is_zero_approx() \
		or forward.dot(offset.normalized()) >= cos(deg_to_rad(definition.vision_angle_degrees * 0.5)))


func _draw() -> void:
	if definition == null:
		return
	if show_vision_debug:
		var angle := _forward.angle() - global_rotation
		var half := deg_to_rad(definition.vision_angle_degrees * 0.5)
		var tint := Color.GREEN if saw_player else Color.YELLOW
		draw_arc(Vector2.ZERO, definition.vision_distance, angle - half, angle + half, 40, tint)
		for edge in [angle - half, angle + half]:
			draw_line(Vector2.ZERO, Vector2.from_angle(edge) * definition.vision_distance, tint)
	if show_hearing_debug:
		var tint := Color.GREEN if heard_player else Color.ORANGE
		draw_arc(Vector2.ZERO, definition.hearing_radius, 0, TAU, 64, tint)
		if is_instance_valid(noise_source):
			draw_arc(to_local(noise_source.global_position), noise_source.get_noise_radius(),
				0, TAU, 64, Color(1, 0.5, 0, 0.5))
