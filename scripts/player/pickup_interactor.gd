extends Node2D
## Owns this player's inventory and pickup range, independently of wheelchair physics.

const Inventory = preload("res://scripts/inventory/inventory.gd")
const Equipment = preload("res://scripts/inventory/equipment.gd")
const WorldItem = preload("res://scripts/items/world_item.gd")

@export_range(1, 32, 1) var inventory_capacity: int = 8
@export_range(1.0, 500.0, 1.0) var pickup_distance: float = 95.0

var inventory: Inventory
var equipment: Equipment


func _ready() -> void:
	inventory = Inventory.new(inventory_capacity)
	equipment = Equipment.new()


func can_pickup(world_item: WorldItem) -> bool:
	if not is_instance_valid(world_item) or world_item.is_queued_for_deletion():
		return false
	return global_position.distance_to(world_item.global_position) <= pickup_distance


func request_pickup(world_item: WorldItem) -> void:
	if not can_pickup(world_item):
		return
	var runtime_stack = world_item.get_item_stack()
	var added := inventory.try_add_stack(runtime_stack) if runtime_stack != null \
		else inventory.try_add(world_item.definition, world_item.quantity)
	if added == world_item.quantity:
		world_item.queue_free()
	elif added > 0:
		world_item.remove_quantity(added)
