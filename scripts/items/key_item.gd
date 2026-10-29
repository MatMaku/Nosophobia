@tool
extends "res://scripts/items/editable_item.gd"

@export_group("Key")
## Match Door2D.key_id exactly. Empty keys do not unlock a key-locked door.
@export var key_id: StringName:
	get:
		return definition.key_id if definition != null else &""
	set(value):
		_edit_definition()
		definition.key_id = value


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "key_id":
		property.usage &= ~PROPERTY_USAGE_STORAGE
