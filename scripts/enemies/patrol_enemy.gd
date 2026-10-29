@tool
extends "res://scripts/enemies/enemy_base.gd"
## Authoring/composition only. EnemyBase remains usable without any AI components.

const Behavior = preload("res://scripts/enemies/enemy_behavior.gd")

@export_group("Enemy Type")
@export var definition: EnemyDefinition = preload("res://resources/enemies/patrol_enemy.tres")
@export_group("Patrol")
@export var patrol_mode: Behavior.PatrolMode = Behavior.PatrolMode.ROUTE
## Assign a Path2D placed in the LEVEL, not beneath the moving enemy.
@export var patrol_route: Path2D
@export_range(0.0, 30.0, 0.1) var wait_time_at_point: float = 0.5
@export_group("AI Debug")
@export var show_navigation_debug: bool = true
@export var show_patrol_debug: bool = true
@export var show_vision_debug: bool = true
@export var show_hearing_debug: bool = true


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	if definition == null:
		push_error("PatrolEnemy requires an EnemyDefinition.")
		return
	$Movement.configure(self, $NavigationAgent2D, $Visual, definition)
	$NavigationAgent2D.debug_enabled = show_navigation_debug
	$Perception.definition = definition
	$Perception.show_vision_debug = show_vision_debug
	$Perception.show_hearing_debug = show_hearing_debug
	$Behavior.patrol_mode = patrol_mode
	$Behavior.route = patrol_route
	$Behavior.wait_time_at_point = wait_time_at_point
	$Behavior.show_patrol_debug = show_patrol_debug
	$Behavior.configure($Movement, $Perception, definition)


func bind_player(player: RigidBody2D) -> void:
	# Body center is the detection point; independent of sprite/aim animation.
	$Perception.target = player
	$Perception.noise_source = player.get_node("PlayerNoiseEmitter")


func set_detection_enabled(enabled: bool) -> void:
	$Perception.detection_enabled = enabled
	if not enabled:
		$Perception.saw_player = false
		$Perception.heard_player = false
		$Behavior.return_to_patrol()
		$Perception.queue_redraw()


func set_debug_visuals_enabled(enabled: bool) -> void:
	super.set_debug_visuals_enabled(enabled)
	$NavigationAgent2D.debug_enabled = enabled and show_navigation_debug
	$Perception.show_vision_debug = enabled and show_vision_debug
	$Perception.show_hearing_debug = enabled and show_hearing_debug
	$Behavior.show_patrol_debug = enabled and show_patrol_debug
	$Perception.queue_redraw()
	$Behavior.queue_redraw()


func _get_configuration_warnings() -> PackedStringArray:
	if definition == null:
		return ["Assign an EnemyDefinition; shared resources configure the whole enemy type."]
	if patrol_mode == Behavior.PatrolMode.ROUTE:
		if patrol_route == null or patrol_route.curve == null or patrol_route.curve.point_count == 0:
			return ["ROUTE needs a level Path2D with points. Without it patrol stays stationary."]
		if is_ancestor_of(patrol_route):
			return ["Place the route in the level, outside the moving enemy hierarchy."]
	return []
