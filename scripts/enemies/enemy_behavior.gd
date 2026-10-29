extends Node2D
## The first behavior: a local two-state policy, replaceable independently of EnemyBase.

enum PatrolMode { ROUTE, STATIONARY }
enum State { PATROL, CHASE }

var definition: EnemyDefinition
var patrol_mode: PatrolMode = PatrolMode.ROUTE
var route: Path2D
var wait_time_at_point: float = 0.5
var show_patrol_debug: bool = false
var state: State = State.PATROL
var last_known_position := Vector2.ZERO
var waypoint_index: int = 0
var _memory: float = 0.0
var _wait: float = 0.0
var _refresh: float = 0.0
var _patrol_destination_set: bool = false
var _movement: Node
var _perception: Node2D

const CHASE_DISTANCE := 44.0
const TARGET_REFRESH_SECONDS := 0.2


func configure(movement: Node, perception: Node2D, config: EnemyDefinition) -> void:
	_movement = movement
	_perception = perception
	definition = config


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	var detected: bool = _perception.sample(_movement.forward)
	_refresh -= delta
	if detected:
		last_known_position = _perception.target.global_position
		_memory = definition.target_memory_seconds
		if state != State.CHASE:
			state = State.CHASE
			_refresh = 0.0
	else:
		_memory = maxf(0.0, _memory - delta)
	if state == State.CHASE:
		if not detected and _memory <= 0.0:
			return_to_patrol()
		elif global_position.distance_to(last_known_position) <= CHASE_DISTANCE:
			_movement.stop()
			_refresh = 0.0
		elif _refresh <= 0.0:
			_movement.set_destination(last_known_position, definition.chase_speed)
			_refresh = TARGET_REFRESH_SECONDS
	if state == State.PATROL:
		_patrol(delta)
	if show_patrol_debug:
		queue_redraw()


func _patrol(delta: float) -> void:
	if patrol_mode == PatrolMode.STATIONARY or not is_instance_valid(route) \
			or route.curve == null or route.curve.point_count == 0:
		_movement.stop()
		return
	waypoint_index %= route.curve.point_count
	if _wait > 0.0:
		_wait = maxf(0.0, _wait - delta)
		return
	if not _patrol_destination_set:
		var destination := route.to_global(route.curve.get_point_position(waypoint_index))
		_movement.set_destination(destination, definition.patrol_speed)
		_patrol_destination_set = true
	elif _movement.has_arrived():
		_movement.stop()
		waypoint_index = (waypoint_index + 1) % route.curve.point_count
		_patrol_destination_set = false
		_wait = wait_time_at_point


func return_to_patrol() -> void:
	if state == State.PATROL:
		return
	state = State.PATROL
	_memory = 0.0
	_refresh = 0.0
	_wait = 0.0
	last_known_position = Vector2.ZERO
	_patrol_destination_set = false
	_movement.stop()
	queue_redraw()


func _draw() -> void:
	if not show_patrol_debug or not is_instance_valid(route) or route.curve == null:
		return
	for index in route.curve.point_count:
		var point := to_local(route.to_global(route.curve.get_point_position(index)))
		draw_circle(point, 4.0, Color.CYAN)
	if state == State.CHASE:
		draw_line(Vector2.ZERO, to_local(last_known_position), Color.RED)
