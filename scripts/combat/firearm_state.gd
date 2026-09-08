extends RefCounted
## Owned by one weapon stack. Never shared between separate weapons.

signal changed

var definition: FirearmDefinition
var _loaded_slots: Array[bool] = []


func _init(config: FirearmDefinition) -> void:
	definition = config
	_loaded_slots.resize(config.capacity)
	_loaded_slots.fill(false)


func get_capacity() -> int:
	return _loaded_slots.size()


func is_loaded(index: int) -> bool:
	return index >= 0 and index < get_capacity() and _loaded_slots[index]


func get_loaded_count() -> int:
	return _loaded_slots.count(true)


func can_load(index: int) -> bool:
	return index >= 0 and index < get_capacity() and not _loaded_slots[index]


## Inventory commits consumption before calling this; observers see both changes.
func load_chamber(index: int) -> bool:
	if not can_load(index):
		return false
	_loaded_slots[index] = true
	changed.emit()
	return true


func consume_round() -> bool:
	var index := _loaded_slots.find(true)
	if index == -1:
		return false
	_loaded_slots[index] = false
	changed.emit()
	return true
