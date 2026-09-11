@tool
extends Node2D
## Click only releases the latch. The rigid leaf and joint handle subsequent motion.

signal unlock_requested(door: Node2D)

@export_group("Latch")
@export var locked_initially: bool = true
@export_range(-90.0, 90.0, 1.0) var unlatched_angle_degrees: float = -20.0
@export_range(1.0, 200.0, 1.0) var interaction_distance: float = 80.0
@export_group("Hinge")
@export_range(-170.0, 0.0, 1.0) var min_open_angle: float = -100.0
@export_range(0.0, 170.0, 1.0) var max_open_angle: float = 5.0
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

var locked: bool = true


func _ready() -> void:
	_collision.shape = RectangleShape2D.new()
	_click_shape.shape = RectangleShape2D.new()
	_occluder.occluder = OccluderPolygon2D.new()
	_visual.texture_changed.connect(_sync_leaf)
	_sync_leaf()
	if Engine.is_editor_hint():
		return
	locked = locked_initially
	body.freeze = locked
	_joint.angular_limit_enabled = true
	# Rebind after applying instance size; leaf origin is its center, not the hinge.
	_joint.node_b = NodePath()
	_joint.node_b = NodePath("../DoorBody")
	_joint.angular_limit_lower = deg_to_rad(min_open_angle)
	_joint.angular_limit_upper = deg_to_rad(max_open_angle)
	interaction_area.input_event.connect(_on_input_event)
	interaction_area.input_pickable = locked
	interaction_area.collision_layer = 2 if locked else 0


func _sync_leaf() -> void:
	if not is_node_ready():
		return
	var center := Vector2(leaf_size.x * 0.5, 0)
	if Engine.is_editor_hint() or locked:
		body.position = center
	_collision.position = Vector2.ZERO
	_collision.shape.size = leaf_size
	_click_shape.position = Vector2.ZERO
	_click_shape.shape.size = leaf_size + Vector2(0, 12)
	_visual.position = Vector2.ZERO
	if _visual.texture != null:
		_visual.scale = leaf_size / _visual.texture.get_size()
	var half_height := leaf_size.y * 0.5
	_occluder.occluder.polygon = PackedVector2Array([
		Vector2(-center.x, 0.0), Vector2(center.x, 0.0)])
	_occluder.occluder.closed = false
	_occluder.occluder.cull_mode = OccluderPolygon2D.CULL_DISABLED
	_occluder.set_meta("vision_occlusion_width", leaf_size.y)


func can_unlock_from(world_position: Vector2) -> bool:
	var local := body.to_local(world_position)
	var closest := Vector2(clampf(local.x, -leaf_size.x * 0.5, leaf_size.x * 0.5),
		clampf(local.y, -leaf_size.y * 0.5, leaf_size.y * 0.5))
	return locked and world_position.distance_to(body.to_global(closest)) <= interaction_distance


func unlock() -> void:
	if not locked:
		return
	locked = false
	# One initial pose change while frozen, never a per-frame rotation controller.
	body.rotation = deg_to_rad(clampf(unlatched_angle_degrees, min_open_angle, max_open_angle))
	body.position = Vector2(leaf_size.x * 0.5, 0).rotated(body.rotation)
	body.freeze = false
	body.sleeping = false
	interaction_area.input_pickable = false
	interaction_area.set_deferred("collision_layer", 0)


func _on_input_event(viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if locked and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			unlock_requested.emit(self)
			if not locked:
				viewport.set_input_as_handled()
