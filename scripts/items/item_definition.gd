class_name ItemDefinition
extends Resource
## Shared static data. Never store per-item runtime state in this resource.

enum EquipmentSlotType { NONE, WEAPON }

@export var display_name: String = "Test Item"
@export var icon: Texture2D
@export_range(1, 999, 1) var max_stack_size: int = 1
@export var equipment_slot: EquipmentSlotType = EquipmentSlotType.NONE
@export var firearm: FirearmDefinition
@export_group("Presentation")
@export var reload_layout: PackedScene
@export var aim_pose: PackedScene
