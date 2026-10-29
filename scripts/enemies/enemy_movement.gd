extends Node
## Navigation and physical locomotion only; destinations come from Behavior.

var definition: EnemyDefinition
var forward := Vector2.UP
var speed: float = 0.0
var _moving: bool = false
var _body: CharacterBody2D
var _agent: NavigationAgent2D
var _visual: Node2D
var _delta: float = 0.0


func configure(body: CharacterBody2D, agent: NavigationAgent2D,
		visual: Node2D, config: EnemyDefinition) -> void:
	_body = body
	_agent = agent
	_visual = visual
	definition = config
	forward = Vector2.UP.rotated(body.global_rotation)
	_agent.radius = body.collision_radius
	_agent.velocity_computed.connect(_apply_motion)


func set_destination(point: Vector2, move_speed: float) -> void:
	speed = move_speed
	_moving = true
	_agent.target_position = point


func stop() -> void:
	_moving = false


func has_arrived() -> bool:
	return _moving and _agent.is_target_reached()


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	if NavigationServer2D.map_get_iteration_id(_agent.get_navigation_map()) == 0:
		return
	var desired := Vector2.ZERO
	if _moving:
		var next := _agent.get_next_path_position()
		if not _agent.is_navigation_finished():
			desired = _body.global_position.direction_to(next) * speed
	var rate := definition.acceleration if not desired.is_zero_approx() else definition.deceleration
	_delta = delta
	var velocity := _body.velocity.move_toward(desired, rate * delta)
	_agent.max_speed = maxf(definition.patrol_speed, definition.chase_speed)
	if _agent.avoidance_enabled:
		_agent.velocity = velocity
	else:
		_apply_motion(velocity)


func _apply_motion(safe_velocity: Vector2) -> void:
	_body.velocity = safe_velocity
	_body.move_and_slide()
	if _body.velocity.length_squared() > 1.0:
		var angle := lerp_angle(forward.angle(), _body.velocity.angle(), 1.0 - exp(-8.0 * _delta))
		forward = Vector2.from_angle(angle)
		_visual.global_rotation = angle + PI * 0.5
