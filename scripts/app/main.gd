extends Node2D
## Composition translates concrete gameplay into semantic cursor context.

const ShotResult = preload("res://scripts/combat/shot_result.gd")

@export var tracer_scene: PackedScene

@onready var _pickup = $MovementTest/Player/PickupInteractor
@onready var _input = $MovementTest/Player/WheelchairInput
@onready var _ui = $HUD/InventoryUI
@onready var _cursor = $CursorController
@onready var _aim = $MovementTest/Player/WeaponAim
@onready var _firearm = $MovementTest/Player/FirearmController
@onready var _reload_ui = $HUD/WeaponReloadUI
@onready var _character_visual = $MovementTest/Player/CharacterVisual


func _ready() -> void:
	_aim.bind_equipment(_pickup.equipment)
	_firearm.bind_equipment(_pickup.equipment)
	_character_visual.bind_equipment(_pickup.equipment)
	_firearm.aim_muzzle_provider = _character_visual.get_aim_muzzle
	_firearm.shot_fired.connect($WeaponFireVFX.show_shot)
	_firearm.shot_fired.connect(_character_visual.show_recoil)
	_aim.aiming_changed.connect(_sync_movement_gate)
	_ui.panel_changed.connect(_sync_input_gates)
	_reload_ui.panel_changed.connect(_sync_input_gates)
	_ui.bind_inventory(_pickup.inventory, _pickup.equipment)
	_reload_ui.bind_models(_pickup.inventory, _pickup.equipment)
	_firearm.shot_resolved.connect(_show_shot_result)
	_sync_input_gates()


func _sync_input_gates() -> void:
	_aim.set_blocked(_ui.is_open() or _reload_ui.is_open())
	_sync_movement_gate()


func _sync_movement_gate() -> void:
	_input.set_input_enabled(not _aim.is_aiming and not _ui.is_open() and not _reload_ui.is_open())


func _show_shot_result(result: ShotResult) -> void:
	var tracer = tracer_scene.instantiate()
	$Tracers.add_child(tracer)
	tracer.show_segment(result.start, result.end)
	if result.hit:
		$WeaponFireVFX.show_impact(result.end, result.collision_normal)


func _process(_delta: float) -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	var available := false
	if hovered != null:
		available = _ui.is_interactable(hovered) or _reload_ui.is_interactable(hovered)
	else:
		var query := PhysicsPointQueryParameters2D.new()
		query.position = get_global_mouse_position()
		query.collision_mask = _input.WORLD_ITEM_COLLISION_MASK
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hits := get_world_2d().direct_space_state.intersect_point(query)
		var reachable_item := false
		for hit in hits:
			if _pickup.can_pickup(hit.collider):
				reachable_item = true
				break
		if reachable_item:
			# A reachable item intentionally keeps the default pointing hand.
			# Its Area2D still receives the click and requests pickup.
			available = false
		else:
			available = _input.input_enabled and (
				_input.get_local_mouse_position().length() <= _input.interaction_radius)
	_cursor.set_context(self, available,
		_input.drag_active or get_viewport().gui_is_dragging(), _aim.is_aiming)
