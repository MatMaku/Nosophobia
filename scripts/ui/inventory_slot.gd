extends PanelContainer
## Native drag/drop view. Immutable source values detect stale drags.

const Inventory = preload("res://scripts/inventory/inventory.gd")
const Equipment = preload("res://scripts/inventory/equipment.gd")
const ItemStack = preload("res://scripts/inventory/item_stack.gd")

@export var preview_scene: PackedScene
@export var empty_text: String = "—"

var inventory: Inventory
var equipment: Equipment
var slot_index: int = -1 # -1 is the single weapon slot.

@onready var _icon: TextureRect = $Content/Icon
@onready var _name_label: Label = $Content/Name
@onready var _quantity: Label = $Quantity


func get_item_stack() -> ItemStack:
	if inventory == null:
		return null
	return equipment.get_weapon() if slot_index == -1 else inventory.get_item(slot_index)


func refresh() -> void:
	var item_stack: ItemStack = get_item_stack()
	_icon.texture = item_stack.definition.icon if item_stack != null else null
	_name_label.text = item_stack.definition.display_name if item_stack != null else empty_text
	_quantity.text = str(item_stack.quantity) if item_stack != null else ""
	_quantity.visible = item_stack != null and item_stack.quantity > 1


func _get_drag_data(_position: Vector2) -> Variant:
	var item_stack: ItemStack = get_item_stack()
	if item_stack == null:
		return null
	var preview = preview_scene.instantiate()
	var preview_icon := preview.get_node("Icon") as TextureRect
	var preview_quantity := preview.get_node("Quantity") as Label
	preview_icon.texture = item_stack.definition.icon
	preview_quantity.text = str(item_stack.quantity) if item_stack.quantity > 1 else ""
	set_drag_preview(preview)
	return {"inventory": inventory, "equipment": equipment, "index": slot_index, "stack": item_stack}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("inventory") != inventory or data.get("equipment") != equipment:
		return false
	if not data.get("stack") is ItemStack or not data.get("index") is int:
		return false
	var source: int = data.index
	if slot_index == -1:
		return source >= 0 and equipment.can_equip(inventory, source, data.stack)
	if source == -1:
		return equipment.can_unequip(inventory, slot_index, data.stack)
	return inventory.can_move(source, slot_index, data.stack)


func _drop_data(position: Vector2, data: Variant) -> void:
	if not _can_drop_data(position, data):
		return
	if slot_index == -1:
		equipment.equip(inventory, data.index, data.stack)
	elif data.index == -1:
		equipment.unequip(inventory, slot_index, data.stack)
	else:
		inventory.move(data.index, slot_index, data.stack)
