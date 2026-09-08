extends Area2D

signal pickup_requested(world_item: Area2D)

const ItemDefinition = preload("res://scripts/items/item_definition.gd")

@export var definition: ItemDefinition
@export_range(1, 999, 1) var quantity: int = 1

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if definition != null:
		_sprite.texture = definition.icon


func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			viewport.set_input_as_handled()
			pickup_requested.emit(self)
