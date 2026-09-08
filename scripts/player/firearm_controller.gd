extends Node2D
## Input queues one trigger; all rays and recoil resolve during the physics step.

signal shot_fired
signal dry_fired
signal tracer_requested(start: Vector2, end: Vector2)

const Equipment = preload("res://scripts/inventory/equipment.gd")
const WeaponAim = preload("res://scripts/player/weapon_aim_controller.gd")

@export var aim: WeaponAim
@export var body: RigidBody2D
@export var muzzle: Marker2D
@export_flags_2d_physics var collision_mask: int = 1

var _equipment: Equipment
var _pending: bool = false
var _cooldown: float = 0.0


func bind_equipment(equipment: Equipment) -> void:
	_equipment = equipment
	_equipment.changed.connect(_cancel_pending)
	aim.aiming_changed.connect(_on_aim_changed)


func _cancel_pending() -> void:
	_pending = false


func _on_aim_changed() -> void:
	if not aim.is_aiming:
		_cancel_pending()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and aim.is_aiming:
			_pending = true
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if not _pending:
		return
	_pending = false
	if not aim.is_aiming or _cooldown > 0.0 or _equipment == null:
		return
	var weapon := _equipment.get_weapon()
	if weapon == null or weapon.firearm_state == null:
		return
	var state = weapon.firearm_state
	if not state.consume_round():
		dry_fired.emit()
		return
	var config: FirearmDefinition = state.definition
	var direction := aim.get_aim_direction()
	var start := muzzle.global_position
	_cooldown = config.fire_interval
	var half_spread := deg_to_rad(config.spread_degrees) * 0.5
	for pellet in config.pellet_count:
		var ray_direction := direction.rotated(randf_range(-half_spread, half_spread))
		var end := start + ray_direction * config.range
		var query := PhysicsRayQueryParameters2D.create(start, end, collision_mask, [body.get_rid()])
		query.hit_from_inside = true
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit.position
		tracer_requested.emit(start, end)
	body.apply_external_impulse(-direction * config.recoil_impulse)
	shot_fired.emit()
