extends Node2D
## Playground composition references and runtime inventory drops; no demo generation.

const ItemStack = preload("res://scripts/inventory/item_stack.gd")
const WorldItem = preload("res://scripts/items/world_item.gd")
const Door = preload("res://scripts/world/door_2d.gd")

@export var doors: Array[Door] = []

@export_group("World item drop")
@export var world_item_scene: PackedScene = preload("res://scenes/prefabs/items/world_item.tscn")
@export_range(8.0, 120.0, 1.0) var drop_distance: float = 36.0
@export_range(8.0, 48.0, 1.0) var separation_radius: float = 26.0
@export_range(4.0, 32.0, 1.0) var separation_step: float = 14.0

@onready var _player: RigidBody2D = $Player
@onready var _pickup_interactor: Node2D = $Player/PickupInteractor


func spawn_dropped_item(item_stack: ItemStack, toward_world_position: Vector2) -> WorldItem:
	if item_stack == null or world_item_scene == null:
		return null
	var direction := _player.global_position.direction_to(toward_world_position)
	if direction.is_zero_approx():
		direction = Vector2.UP.rotated(_player.global_rotation)
	var base_position := _player.global_position + direction * drop_distance
	var spawn_position := _find_drop_position(base_position)
	if not spawn_position.is_finite():
		return null
	var world_item := world_item_scene.instantiate() as WorldItem
	if world_item == null:
		return null
	world_item.set_item_stack(item_stack)
	add_child(world_item)
	world_item.global_position = spawn_position
	world_item.pickup_requested.connect(_pickup_interactor.request_pickup)
	return world_item


func _find_drop_position(base_position: Vector2) -> Vector2:
	for attempt in 17:
		var candidate := base_position
		if attempt > 0:
			var ring := 1 + (attempt - 1) / 8
			var angle := float((attempt - 1) % 8) * TAU / 8.0
			candidate += Vector2.RIGHT.rotated(angle) * separation_step * ring
		if _is_clear_of_world_items(candidate) and _is_clear_of_walls(candidate):
			return candidate
	return Vector2(INF, INF)


func _is_clear_of_world_items(candidate: Vector2) -> bool:
	for child in get_children():
		if child is WorldItem and child.global_position.distance_to(candidate) < separation_radius:
			return false
	return true


func _is_clear_of_walls(candidate: Vector2) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
