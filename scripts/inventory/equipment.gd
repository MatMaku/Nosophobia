extends RefCounted
## One weapon slot. Both models are updated before observers are notified.

signal changed

const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const ItemStack = preload("res://scripts/inventory/item_stack.gd")
const Inventory = preload("res://scripts/inventory/inventory.gd")
var _weapon: ItemStack


func get_weapon() -> ItemStack:
	return _weapon


func accepts(stack: ItemStack) -> bool:
	return stack != null and stack.quantity == 1 \
		and stack.definition.equipment_slot == ItemDefinition.EquipmentSlotType.WEAPON \
		and stack.definition.max_stack_size == 1


func can_equip(inventory: Inventory, index: int, expected: ItemStack) -> bool:
	return accepts(expected) and inventory.get_item(index) == expected


func equip(inventory: Inventory, index: int, expected: ItemStack) -> bool:
	if not can_equip(inventory, index, expected):
		return false
	var previous := _weapon
	_weapon = expected
	if not inventory.exchange(index, expected, previous):
		_weapon = previous
		return false
	changed.emit()
	return true


func can_unequip(inventory: Inventory, index: int, expected: ItemStack) -> bool:
	if expected == null or _weapon != expected or index < 0 or index >= inventory.get_capacity():
		return false
	var destination := inventory.get_item(index)
	return destination == null or accepts(destination)


func unequip(inventory: Inventory, index: int, expected: ItemStack) -> bool:
	if not can_unequip(inventory, index, expected):
		return false
	var destination := inventory.get_item(index)
	_weapon = destination
	if not inventory.exchange(index, destination, expected):
		_weapon = expected
		return false
	changed.emit()
	return true
