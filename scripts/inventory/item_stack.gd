extends RefCounted
## Immutable slot value. Models replace values instead of exposing mutable quantities.

const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const FirearmState = preload("res://scripts/combat/firearm_state.gd")
var firearm_state: FirearmState
var definition: ItemDefinition:
	get:
		return _definition
var quantity: int:
	get:
		return _quantity
var _definition: ItemDefinition
var _quantity: int


func _init(item: ItemDefinition, amount: int = 1) -> void:
	assert(item != null and amount >= 1 and amount <= item.max_stack_size)
	_definition = item
	_quantity = amount
	if item.firearm != null:
		assert(item.max_stack_size == 1 and amount == 1)
		firearm_state = FirearmState.new(item.firearm)
