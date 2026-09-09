extends Control
## Displays Equipment/FirearmState/Inventory. All round transfers belong to Inventory.

signal panel_changed

const Inventory = preload("res://scripts/inventory/inventory.gd")
const Equipment = preload("res://scripts/inventory/equipment.gd")
const ItemStack = preload("res://scripts/inventory/item_stack.gd")

@export var loose_round_scene: PackedScene

var _inventory: Inventory
var _equipment: Equipment
var _weapon: ItemStack
var _layout: Control
var _refresh_pending: bool = false

@onready var _button: Button = $WeaponButton
@onready var _panel: PanelContainer = $Panel
@onready var _layout_host: Control = $Panel/Margin/Content/LayoutHost
@onready var _loose: HFlowContainer = $Panel/Margin/Content/LooseRounds
@onready var _title: Label = $Panel/Margin/Content/Title


func _ready() -> void:
	_button.pressed.connect(_toggle_panel)


func bind_models(inventory: Inventory, equipment: Equipment) -> void:
	_inventory = inventory
	_equipment = equipment
	_inventory.changed.connect(_schedule_refresh)
	_equipment.changed.connect(_on_equipment_changed)
	_on_equipment_changed()


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


func _toggle_panel() -> void:
	if _weapon == null or _weapon.firearm_state == null:
		return
	_panel.visible = not _panel.visible
	panel_changed.emit()


func _on_equipment_changed() -> void:
	if _weapon != null and _weapon.firearm_state != null:
		_weapon.firearm_state.changed.disconnect(_schedule_refresh)
	_weapon = _equipment.get_weapon()
	_panel.hide()
	panel_changed.emit()
	_button.visible = _weapon != null
	if is_instance_valid(_layout):
		_layout_host.remove_child(_layout)
		_layout.queue_free()
	_layout = null
	if _weapon == null:
		return
	_button.icon = _weapon.definition.icon
	_button.text = _weapon.definition.display_name if _button.icon == null else ""
	_button.disabled = _weapon.firearm_state == null
	if _weapon.firearm_state == null:
		return
	_weapon.firearm_state.changed.connect(_schedule_refresh)
	_title.text = _weapon.definition.display_name
	if _weapon.definition.reload_layout != null:
		_layout = _weapon.definition.reload_layout.instantiate()
		_layout_host.add_child(_layout)
		for socket in _layout.get_node("Sockets").get_children():
			socket.reload_ui = self
	_refresh()


func _schedule_refresh() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		call_deferred("_refresh")


func _refresh() -> void:
	_refresh_pending = false
	for token in _loose.get_children():
		_loose.remove_child(token)
		token.queue_free()
	if _weapon == null or _weapon.firearm_state == null:
		return
	var state := _weapon.firearm_state
	var ammo: ItemDefinition = state.definition.compatible_ammo
	if _layout != null:
		for socket in _layout.get_node("Sockets").get_children():
			socket.show_ammo(ammo.icon if ammo != null else null, state.is_loaded(socket.chamber_index))
	for index in get_loose_count():
		var token = loose_round_scene.instantiate()
		token.reload_ui = self
		_loose.add_child(token)
		token.show_ammo(ammo.icon, true)


func get_loose_count() -> int:
	if _weapon == null or _weapon.firearm_state == null:
		return 0
	var state := _weapon.firearm_state
	return mini(_inventory.count_item(state.definition.compatible_ammo),
		state.get_capacity() - state.get_loaded_count())


func get_round_drag() -> Dictionary:
	if get_loose_count() == 0 or not is_open():
		return {}
	return {"weapon": _weapon, "ammo": _weapon.firearm_state.definition.compatible_ammo,
		"reload_source": self}


func can_load(chamber: int, data: Variant) -> bool:
	if not is_open() or not data is Dictionary or _weapon == null:
		return false
	if data.get("reload_source") != self or data.get("weapon") != _weapon:
		return false
	var state := _weapon.firearm_state
	return state != null and state.can_load(chamber) and data.get("ammo") != null \
		and data.get("ammo") == state.definition.compatible_ammo \
		and _inventory.count_item(state.definition.compatible_ammo) > 0


func load_round(chamber: int, data: Variant) -> void:
	if can_load(chamber, data):
		_inventory.try_load_round(_weapon.firearm_state, chamber, data.ammo)


func is_interactable(control: Control) -> bool:
	if control == _button:
		return not _button.disabled
	for token in _loose.get_children():
		if control == token or token.is_ancestor_of(control):
			return get_loose_count() > 0
	return false
