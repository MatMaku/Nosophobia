@tool
class_name ItemDefinition
extends Resource
## Shared static data. Never store per-item runtime state in this resource.

enum EquipmentSlotType { NONE, WEAPON }

@export var display_name: String = "Test Item":
	set(value):
		display_name = value
		emit_changed()
@export var icon: Texture2D:
	set(value):
		icon = value
		emit_changed()
## Optional world art. Null uses the inventory icon; shared by pickups of this type.
@export var world_sprite: Texture2D:
	set(value):
		world_sprite = value
		emit_changed()
@export_range(1, 999, 1) var max_stack_size: int = 1
@export var equipment_slot: EquipmentSlotType = EquipmentSlotType.NONE
@export var key_id: StringName = &""
@export var firearm: FirearmDefinition
@export_group("Presentation")
@export var reload_layout: PackedScene
@export var aim_pose: PackedScene
