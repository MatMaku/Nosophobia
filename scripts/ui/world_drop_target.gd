extends Control
## Full-screen native drop target behind UI panels. Normal clicks remain unhandled.

signal inventory_drop_requested(slot_index: int, stack: ItemStack, screen_position: Vector2)

const Inventory = preload("res://scripts/inventory/inventory.gd")
const ItemStack = preload("res://scripts/inventory/item_stack.gd")


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var inventory = data.get("inventory")
	var slot_index = data.get("index")
	var stack = data.get("stack")
	return inventory is Inventory and slot_index is int and slot_index >= 0 \
		and stack is ItemStack and inventory.get_item(slot_index) == stack


func _drop_data(position: Vector2, data: Variant) -> void:
	if _can_drop_data(position, data):
		inventory_drop_requested.emit(data.index, data.stack, get_global_mouse_position())
