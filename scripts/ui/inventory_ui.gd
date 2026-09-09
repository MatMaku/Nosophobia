extends Control

signal panel_changed

const Inventory = preload("res://scripts/inventory/inventory.gd")
const Equipment = preload("res://scripts/inventory/equipment.gd")

@export var slot_scene: PackedScene = preload("res://scenes/ui/inventory_slot.tscn")
var _inventory: Inventory
var _equipment: Equipment

@onready var _panel: PanelContainer = $Panel
@onready var _grid: GridContainer = $Panel/Margin/Content/Slots
@onready var _button: Button = $BackpackButton
@onready var _weapon_slot = $Panel/Margin/Content/Weapon/WeaponSlot


func _ready() -> void:
	_button.pressed.connect(_toggle_panel)


func bind_inventory(inventory: Inventory, equipment: Equipment) -> void:
	if _inventory != null:
		_inventory.changed.disconnect(_refresh)
		_equipment.changed.disconnect(_refresh)
	_inventory = inventory
	_equipment = equipment
	for slot in _grid.get_children():
		_grid.remove_child(slot)
		slot.queue_free()
	for index in _inventory.get_capacity():
		var slot = slot_scene.instantiate()
		slot.inventory = inventory
		slot.equipment = equipment
		slot.slot_index = index
		_grid.add_child(slot)
	_weapon_slot.inventory = inventory
	_weapon_slot.equipment = equipment
	_inventory.changed.connect(_refresh)
	_equipment.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for slot in _grid.get_children():
		slot.refresh()
	_weapon_slot.refresh()


func is_interactable(control: Control) -> bool:
	if control == _button:
		return true
	var slots := _grid.get_children()
	slots.append(_weapon_slot)
	for slot in slots:
		if control == slot or slot.is_ancestor_of(control):
			return slot.get_item_stack() != null
	return false


func _toggle_panel() -> void:
	_panel.visible = not _panel.visible
	panel_changed.emit()


func is_open() -> bool:
	return _panel.visible


func close_panel() -> bool:
	if not _panel.visible:
		return false
	_panel.hide()
	panel_changed.emit()
	return true


func close_for_outside_click(screen_position: Vector2) -> bool:
	if not is_open() or _panel.get_global_rect().has_point(screen_position):
		return false
	if _button.get_global_rect().has_point(screen_position):
		return false
	return close_panel()
