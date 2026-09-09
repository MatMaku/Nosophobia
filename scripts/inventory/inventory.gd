extends RefCounted

signal changed

const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const ItemStack = preload("res://scripts/inventory/item_stack.gd")
var _slots: Array[ItemStack] = []


func _init(capacity: int = 8) -> void:
	_slots.resize(maxi(1, capacity))


func get_capacity() -> int:
	return _slots.size()


func get_item(index: int) -> ItemStack:
	return _slots[index] if _valid_index(index) else null


func can_accept(item: ItemDefinition) -> bool:
	if item == null:
		return false
	for stack in _slots:
		if stack == null or (stack.definition == item and stack.quantity < item.max_stack_size):
			return true
	return false


## Returns units actually stored, including partial pickups.
func try_add(item: ItemDefinition, quantity: int = 1) -> int:
	if item == null or quantity <= 0:
		return 0
	var remaining := quantity
	for index in _slots.size():
		var stack := _slots[index]
		if stack != null and stack.definition == item:
			var amount := mini(remaining, item.max_stack_size - stack.quantity)
			if amount > 0:
				_slots[index] = ItemStack.new(item, stack.quantity + amount)
				remaining -= amount
	for index in _slots.size():
		if remaining == 0:
			break
		if _slots[index] == null:
			var amount := mini(remaining, item.max_stack_size)
			_slots[index] = ItemStack.new(item, amount)
			remaining -= amount
	if remaining != quantity:
		changed.emit()
	return quantity - remaining


## Stores an existing runtime value. An untouched stack keeps its identity/state.
func try_add_stack(item_stack: ItemStack) -> int:
	if item_stack == null:
		return 0
	var item := item_stack.definition
	var remaining := item_stack.quantity
	for index in _slots.size():
		var destination := _slots[index]
		if destination != null and destination.definition == item:
			var amount := mini(remaining, item.max_stack_size - destination.quantity)
			if amount > 0:
				_slots[index] = ItemStack.new(item, destination.quantity + amount)
				remaining -= amount
	for index in _slots.size():
		if remaining == 0:
			break
		if _slots[index] == null:
			if remaining == item_stack.quantity:
				_slots[index] = item_stack
			else:
				_slots[index] = ItemStack.new(item, remaining)
			remaining = 0
	if remaining != item_stack.quantity:
		changed.emit()
	return item_stack.quantity - remaining


func can_move(source: int, target: int, expected: ItemStack) -> bool:
	if not _valid_index(source) or not _valid_index(target) or source == target:
		return false
	if expected == null or _slots[source] != expected:
		return false
	var destination := _slots[target]
	if destination != null and destination.definition == expected.definition:
		if expected.definition.max_stack_size > 1:
			return destination.quantity < expected.definition.max_stack_size
	return true


func move(source: int, target: int, expected: ItemStack) -> bool:
	if not can_move(source, target, expected):
		return false
	var destination := _slots[target]
	if destination != null and destination.definition == expected.definition:
		if expected.definition.max_stack_size > 1:
			var amount := mini(expected.quantity,
				expected.definition.max_stack_size - destination.quantity)
			_slots[target] = ItemStack.new(expected.definition, destination.quantity + amount)
			_slots[source] = ItemStack.new(expected.definition, expected.quantity - amount) \
				if expected.quantity > amount else null
			changed.emit()
			return true
	_slots[target] = expected
	_slots[source] = destination
	changed.emit()
	return true


## Checked exchange used by Equipment; no backing array is exposed.
func exchange(index: int, expected: ItemStack, replacement: ItemStack) -> bool:
	if not _valid_index(index) or _slots[index] != expected:
		return false
	_slots[index] = replacement
	changed.emit()
	return true


## Removes and returns the exact runtime value only when the slot still matches.
func take(index: int, expected: ItemStack) -> ItemStack:
	if not _valid_index(index) or expected == null or _slots[index] != expected:
		return null
	_slots[index] = null
	changed.emit()
	return expected


func _valid_index(index: int) -> bool:
	return index >= 0 and index < _slots.size()


func count_item(item: ItemDefinition) -> int:
	var count := 0
	for stack in _slots:
		if stack != null and stack.definition == item:
			count += stack.quantity
	return count


## Atomic one-round transfer. Neither drag start nor an invalid drop consumes ammo.
func try_load_round(state: ItemStack.FirearmState, chamber: int, ammo: ItemDefinition) -> bool:
	if state == null or ammo == null or state.definition.compatible_ammo != ammo:
		return false
	if not state.can_load(chamber):
		return false
	for index in _slots.size():
		var stack := _slots[index]
		if stack != null and stack.definition == ammo:
			_slots[index] = ItemStack.new(ammo, stack.quantity - 1) if stack.quantity > 1 else null
			state.load_chamber(chamber)
			changed.emit()
			return true
	return false
