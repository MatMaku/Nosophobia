extends Area2D

signal pickup_requested(world_item: Area2D)

const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const ItemStack = preload("res://scripts/inventory/item_stack.gd")

@export var definition: ItemDefinition
@export_range(1, 999, 1) var quantity: int = 1

@onready var _sprite: Sprite2D = $Sprite2D
var _runtime_stack: ItemStack
## Injected by composition; tests the clicked world position, not the item center.
var visibility_test: Callable


func is_pointer_visible() -> bool:
	return not visibility_test.is_valid() or visibility_test.call(get_global_mouse_position())


func _ready() -> void:
	if definition != null:
		_sprite.texture = definition.icon


func set_item_stack(item_stack: ItemStack) -> void:
	_runtime_stack = item_stack
	definition = item_stack.definition if item_stack != null else null
	quantity = item_stack.quantity if item_stack != null else 0
	if is_node_ready():
		_sprite.texture = definition.icon if definition != null else null


func get_item_stack() -> ItemStack:
	return _runtime_stack


func remove_quantity(amount: int) -> void:
	quantity = maxi(0, quantity - amount)
	if _runtime_stack != null:
		_runtime_stack = ItemStack.new(definition, quantity) if quantity > 0 else null


func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not is_visible_in_tree() or not is_pointer_visible():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			viewport.set_input_as_handled()
			pickup_requested.emit(self)
