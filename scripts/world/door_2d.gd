@tool
extends Node2D
## Owns one hinged leaf: latch, key lock, short feedback, then free physics.

signal interaction_requested(door: Node2D)
signal key_requested(door: Node2D)

enum DoorState { LATCHED, OPEN, KEY_LOCKED }

@export_group("Interaction")
@export_range(1.0, 200.0, 1.0) var interaction_distance: float = 80.0
@export_group("Opening")
@export_range(1.0, 90.0, 1.0) var unlatched_angle_degrees: float = 20.0
@export_range(1.0, 170.0, 1.0) var max_open_angle_degrees: float = 100.0
@export_range(0.01, 1.0, 0.01) var opening_time: float = 0.22
@export_range(0.1, 15.0, 0.1) var closing_latch_angle_degrees: float = 4.0
@export_range(0.1, 5.0, 0.1) var closing_angular_velocity: float = 0.5
@export_group("Key Lock")
@export var key_id: StringName = &""
@export var consume_key_on_unlock: bool = true
@export_range(0.5, 10.0, 0.5) var rattle_angle_degrees: float = 3.0
@export_range(0.03, 0.5, 0.01) var rattle_time: float = 0.15
@export_group("Leaf")
@export var leaf_size: Vector2 = Vector2(96, 12):
	set(value):
		leaf_size = value.max(Vector2(1, 1))
		_sync_leaf()

@onready var body: RigidBody2D = $DoorBody
@onready var interaction_area: Area2D = $DoorBody/InteractionArea
@onready var _joint: PinJoint2D = $PinJoint2D
@onready var _visual: Sprite2D = $DoorBody/Visual
@onready var _collision: CollisionShape2D = $DoorBody/CollisionShape2D
@onready var _click_shape: CollisionShape2D = $DoorBody/InteractionArea/CollisionShape2D
@onready var _occluder: LightOccluder2D = $DoorBody/LightOccluder

var state: DoorState = DoorState.LATCHED
var locked: bool:
	get:
		return state != DoorState.OPEN

var _motion_tween: Tween
var _transition_active: bool = false
var _last_opening_sign: float = -1.0


func _ready() -> void:
	_collision.shape = RectangleShape2D.new()
	_click_shape.shape = RectangleShape2D.new()
	_occluder.occluder = OccluderPolygon2D.new()
	_visual.texture_changed.connect(_sync_leaf)
	_sync_leaf()
	if Engine.is_editor_hint():
		return
	state = DoorState.KEY_LOCKED if not key_id.is_empty() else DoorState.LATCHED
	body.freeze = true
	_joint.angular_limit_enabled = true
	# Rebind after applying instance size; leaf origin is its center, not the hinge.
	_joint.node_b = NodePath()
	_joint.node_b = NodePath("../DoorBody")
	var limit := deg_to_rad(max_open_angle_degrees)
	_joint.angular_limit_lower = -limit
	_joint.angular_limit_upper = limit
	interaction_area.input_event.connect(_on_input_event)
	_set_interaction_enabled(true)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if state != DoorState.OPEN or _transition_active:
		return
	var angle_limit := deg_to_rad(closing_latch_angle_degrees)
	if absf(body.rotation) <= angle_limit \
			and absf(body.angular_velocity) <= closing_angular_velocity:
		_latch()


func _sync_leaf() -> void:
	if not is_node_ready():
		return
	var center := Vector2(leaf_size.x * 0.5, 0)
	if Engine.is_editor_hint() or state != DoorState.OPEN:
		body.position = center
	_collision.position = Vector2.ZERO
	_collision.shape.size = leaf_size
	_click_shape.position = Vector2.ZERO
	_click_shape.shape.size = leaf_size + Vector2(0, 12)
	_visual.position = Vector2.ZERO
	if _visual.texture != null:
		_visual.scale = leaf_size / _visual.texture.get_size()
	_occluder.occluder.polygon = PackedVector2Array([
		Vector2(-center.x, 0.0), Vector2(center.x, 0.0)])
	_occluder.occluder.closed = false
	_occluder.occluder.cull_mode = OccluderPolygon2D.CULL_DISABLED
	_occluder.set_meta("vision_occlusion_width", leaf_size.y)


func can_interact_from(world_position: Vector2) -> bool:
	if state == DoorState.OPEN or _transition_active:
		return false
	var local := body.to_local(world_position)
	var closest := Vector2(clampf(local.x, -leaf_size.x * 0.5, leaf_size.x * 0.5),
		clampf(local.y, -leaf_size.y * 0.5, leaf_size.y * 0.5))
	return world_position.distance_to(body.to_global(closest)) <= interaction_distance


func interact_from(world_position: Vector2) -> void:
	if not can_interact_from(world_position):
		return
	var opening_sign := _opening_sign_from(world_position)
	_last_opening_sign = opening_sign
	if state == DoorState.KEY_LOCKED:
		_rattle(opening_sign)
	else:
		_open_smoothly(opening_sign)


func accepts_key(candidate_key_id: StringName) -> bool:
	return state == DoorState.KEY_LOCKED and not candidate_key_id.is_empty() \
		and candidate_key_id == key_id


func unlock_with_key(candidate_key_id: StringName) -> bool:
	if not accepts_key(candidate_key_id):
		return false
	state = DoorState.LATCHED
	return true


func open_after_unlock() -> void:
	if state == DoorState.LATCHED and not _transition_active:
		_open_smoothly(_last_opening_sign)


func _opening_sign_from(world_position: Vector2) -> float:
	return -1.0 if to_local(world_position).y >= 0.0 else 1.0


func _open_smoothly(opening_sign: float) -> void:
	state = DoorState.OPEN
	_transition_active = true
	_set_interaction_enabled(false)
	body.freeze = true
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	_kill_tween()
	_motion_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var target := opening_sign * deg_to_rad(minf(
		unlatched_angle_degrees, max_open_angle_degrees))
	_motion_tween.tween_method(_set_leaf_angle, body.rotation, target, opening_time)
	_motion_tween.finished.connect(_finish_opening)


func _finish_opening() -> void:
	_motion_tween = null
	_transition_active = false
	body.freeze = false
	body.sleeping = false


func _rattle(opening_sign: float) -> void:
	_transition_active = true
	_set_interaction_enabled(false)
	_kill_tween()
	var angle := opening_sign * deg_to_rad(rattle_angle_degrees)
	var step_time := rattle_time / 3.0
	_motion_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_motion_tween.tween_method(_set_leaf_angle, 0.0, angle, step_time)
	_motion_tween.tween_method(_set_leaf_angle, angle, -angle, step_time)
	_motion_tween.tween_method(_set_leaf_angle, -angle, 0.0, step_time)
	_motion_tween.finished.connect(_finish_rattle)


func _finish_rattle() -> void:
	_motion_tween = null
	_transition_active = false
	_set_leaf_angle(0.0)
	_set_interaction_enabled(true)
	key_requested.emit(self)


func _latch() -> void:
	state = DoorState.LATCHED
	body.freeze = true
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	_set_leaf_angle(0.0)
	_set_interaction_enabled(true)


func _set_leaf_angle(angle: float) -> void:
	body.rotation = angle
	body.position = Vector2(leaf_size.x * 0.5, 0).rotated(angle)


func _set_interaction_enabled(enabled: bool) -> void:
	interaction_area.input_pickable = enabled
	interaction_area.set_deferred("collision_layer", 2 if enabled else 0)


func _kill_tween() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null


func _on_input_event(viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and state != DoorState.OPEN and not _transition_active:
		interaction_requested.emit(self)
		viewport.set_input_as_handled()
