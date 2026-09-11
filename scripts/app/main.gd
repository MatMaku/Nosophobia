extends Node2D
## Composition translates concrete gameplay into semantic cursor context.

const ShotResult = preload("res://scripts/combat/shot_result.gd")
const WorldItem = preload("res://scripts/items/world_item.gd")

@export var tracer_scene: PackedScene

@onready var _pickup = $MovementTest/Player/PickupInteractor
@onready var _wheelchair_input = $MovementTest/Player/WheelchairInput
@onready var _ui = $HUD/InventoryUI
@onready var _cursor = $CursorController
@onready var _aim = $MovementTest/Player/WeaponAim
@onready var _firearm = $MovementTest/Player/FirearmController
@onready var _reload_ui = $HUD/WeaponReloadUI
@onready var _character_visual = $MovementTest/Player/CharacterVisual
@onready var _vision = $MovementTest/Player/PlayerVision
@onready var _world = $MovementTest
@onready var _camera = $MovementTest/Player/Camera2D


func _ready() -> void:
	_wheelchair_input.world_interaction_available = _can_world_interact
	for door in _world.doors:
		door.unlock_requested.connect(_request_door_unlock)
	var occluders: Array[LightOccluder2D] = []
	for node in $MovementTest.find_children("*", "LightOccluder2D", true, false):
		occluders.append(node)
	_vision.bind_occluders(occluders)
	$VisibilityFog/Fog.material.set_shader_parameter(
		"visibility_mask", _vision.get_visibility_texture())
	_aim.bind_equipment(_pickup.equipment)
	_firearm.bind_equipment(_pickup.equipment)
	_character_visual.bind_equipment(_pickup.equipment)
	_firearm.aim_muzzle_provider = _character_visual.get_aim_muzzle
	_firearm.shot_fired.connect(_show_shot_presentation)
	_firearm.shot_fired.connect(_character_visual.show_recoil)
	_aim.aiming_changed.connect(_sync_movement_gate)
	_ui.panel_changed.connect(_on_inventory_panel_changed)
	_reload_ui.panel_changed.connect(_on_reload_panel_changed)
	$HUD/WorldDropTarget.inventory_drop_requested.connect(_drop_inventory_stack)
	_ui.bind_inventory(_pickup.inventory, _pickup.equipment)
	_reload_ui.bind_models(_pickup.inventory, _pickup.equipment)
	_firearm.shot_resolved.connect(_show_shot_result)
	_sync_input_gates()


func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if get_viewport().gui_is_dragging():
		return
	# These calls never handle or recreate the event. It continues once through
	# GUI and _unhandled_input after the synchronous panel_changed signal.
	_ui.close_for_outside_click(event.position)
	_reload_ui.close_for_outside_click(event.position)


func _on_inventory_panel_changed() -> void:
	if _ui.is_open():
		_reload_ui.close_panel()
	_sync_input_gates()


func _on_reload_panel_changed() -> void:
	if _reload_ui.is_open():
		_ui.close_panel()
	_sync_input_gates()


func _sync_input_gates() -> void:
	_aim.set_blocked(_ui.is_open() or _reload_ui.is_open())
	_sync_movement_gate()


func _sync_movement_gate() -> void:
	_wheelchair_input.set_input_enabled(
		not _aim.is_aiming and not _ui.is_open() and not _reload_ui.is_open())


func _show_shot_result(result: ShotResult) -> void:
	var tracer = tracer_scene.instantiate()
	$Tracers.add_child(tracer)
	tracer.show_segment(result.start, result.end)
	if result.hit:
		$WeaponFireVFX.show_impact(result.end, result.collision_normal)


func _show_shot_presentation(origin: Vector2, direction: Vector2) -> void:
	var feedback: Dictionary = _character_visual.get_shot_feedback()
	$WeaponFireVFX.show_shot(origin, direction,
		feedback.get("light_energy", -1.0), feedback.get("light_duration", -1.0))
	_camera.shake(feedback.get("shake_strength", 0.0),
		feedback.get("shake_duration", 0.0))


func _drop_inventory_stack(slot_index: int, expected, screen_position: Vector2) -> void:
	if _pickup.inventory.get_item(slot_index) != expected:
		return
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var world_item = _world.spawn_dropped_item(expected, world_position)
	if world_item == null:
		return
	if _pickup.inventory.take(slot_index, expected) == null:
		world_item.queue_free()


func _process(_delta: float) -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	var available := false
	if hovered != null:
		available = _ui.is_interactable(hovered) or _reload_ui.is_interactable(hovered)
	else:
		var query := PhysicsPointQueryParameters2D.new()
		query.position = get_global_mouse_position()
		query.collision_mask = _wheelchair_input.WORLD_ITEM_COLLISION_MASK
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hits := get_world_2d().direct_space_state.intersect_point(query)
		var reachable_item := false
		var reachable_door := false
		for hit in hits:
			if _reachable_door(hit.collider) != null:
				reachable_door = true
			if hit.collider is WorldItem and _pickup.can_pickup(hit.collider):
				reachable_item = true
		if reachable_door:
			available = true
		elif reachable_item:
			# A reachable item intentionally keeps the default pointing hand.
			# Its Area2D still receives the click and requests pickup.
			available = false
		else:
			available = _wheelchair_input.input_enabled and (
				_wheelchair_input.get_local_mouse_position().length()
				<= _wheelchair_input.interaction_radius)
	_cursor.set_context(self, available,
		_wheelchair_input.drag_active or get_viewport().gui_is_dragging(), _aim.is_aiming)


func _reachable_door(area: Object) -> Node2D:
	for door in _world.doors:
		if door.interaction_area == area and door.can_unlock_from(_pickup.global_position):
			return door
	return null


func _can_world_interact(area: Object) -> bool:
	return (area is WorldItem and _pickup.can_pickup(area)) or _reachable_door(area) != null


func _request_door_unlock(door: Node2D) -> void:
	if door.can_unlock_from(_pickup.global_position):
		door.unlock()
