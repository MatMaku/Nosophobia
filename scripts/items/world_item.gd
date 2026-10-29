@tool
extends Area2D

signal pickup_requested(world_item: Area2D)

const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const ItemStack = preload("res://scripts/inventory/item_stack.gd")

@export_group("Item")
## Canonical type. Ammo/weapon pickups must share definitions for stacking and reload.
@export var definition: ItemDefinition:
	set(value):
		if definition != null and definition.changed.is_connected(_refresh_visual):
			definition.changed.disconnect(_refresh_visual)
		definition = value
		if definition != null:
			definition.changed.connect(_refresh_visual)
		_refresh_visual()
@export_range(1, 999, 1) var quantity: int = 1
@export_group("World Visual")
## Optional placement-only art override. Null uses definition.world_sprite, then icon.
@export var world_sprite: Texture2D:
	set(value):
		world_sprite = value
		_refresh_visual()
## Scales only the sprite, never the click area or pickup distance.
@export_range(0.01, 5.0, 0.01) var world_visual_scale: float = 0.5:
	set(value):
		world_visual_scale = value
		_refresh_visual()

@onready var _sprite: Sprite2D = $Sprite2D
var _runtime_stack: ItemStack
## Injected by composition; tests the clicked world position, not the item center.
var visibility_test: Callable


func is_pointer_visible() -> bool:
	return not visibility_test.is_valid() or visibility_test.call(get_global_mouse_position())


func _ready() -> void:
	_refresh_visual()


func _refresh_visual() -> void:
	if not is_node_ready():
		return
	_sprite.texture = world_sprite
	if _sprite.texture == null and definition != null:
		_sprite.texture = definition.world_sprite if definition.world_sprite != null else definition.icon
	_sprite.scale = Vector2.ONE * world_visual_scale
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if definition == null:
		return ["Select an ItemDefinition before playing."]
	if definition.firearm != null and (quantity != 1 or definition.max_stack_size != 1):
		return ["A firearm pickup requires Quantity = 1 and Max Stack Size = 1."]
	return []


func set_item_stack(item_stack: ItemStack) -> void:
	_runtime_stack = item_stack
	definition = item_stack.definition if item_stack != null else null
	quantity = item_stack.quantity if item_stack != null else 0
	_refresh_visual()


func get_item_stack() -> ItemStack:
	return _runtime_stack


func remove_quantity(amount: int) -> void:
	quantity = maxi(0, quantity - amount)
	if _runtime_stack != null:
		_runtime_stack = ItemStack.new(definition, quantity) if quantity > 0 else null


func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if Engine.is_editor_hint():
		return
	if not is_visible_in_tree() or not is_pointer_visible():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			viewport.set_input_as_handled()
			pickup_requested.emit(self)
