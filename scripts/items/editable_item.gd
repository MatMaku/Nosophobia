@tool
extends "res://scripts/items/world_item.gd"
## Generic/key authoring only. Edits create a type variant, never mutate other pickups.

@export_group("Item Details")
## Changing details creates a private definition variant; quantity never does.
@export var display_name: String:
	get:
		return definition.display_name if definition != null else ""
	set(value):
		_edit_definition()
		definition.display_name = value
@export var inventory_icon: Texture2D:
	get:
		return definition.icon if definition != null else null
	set(value):
		_edit_definition()
		definition.icon = value


func _edit_definition() -> void:
	definition = definition.duplicate() if definition != null else ItemDefinition.new()


func _validate_property(property: Dictionary) -> void:
	# Proxy values are stored only in definition, not serialized a second time.
	if property.name in ["display_name", "inventory_icon"]:
		property.usage &= ~PROPERTY_USAGE_STORAGE
