extends Node2D
## Local UP is forward. One shared half-angle applies to every equipped firearm.

signal aiming_changed
signal aim_updated

const Equipment = preload("res://scripts/inventory/equipment.gd")

@export_range(0.0, 89.0, 1.0) var aim_half_angle_degrees: float = 55.0
@export_group("Aim weight")
@export_range(0.1, 30.0, 0.1) var aim_follow_speed: float = 10.0
@export_group("Aim sway (degrees / Hz)")
@export_range(0.0, 5.0, 0.01) var healthy_drift_amplitude: float = 0.4
@export_range(0.0, 5.0, 0.01) var injured_drift_amplitude: float = 2.0
@export_range(0.0, 2.0, 0.01) var drift_speed: float = 0.35
@export_range(0.0, 1.0, 0.01) var healthy_tremor_amplitude: float = 0.06
@export_range(0.0, 1.0, 0.01) var injured_tremor_amplitude: float = 0.25
@export_range(0.0, 10.0, 0.1) var tremor_speed: float = 3.0
## Input: injury (1 - health). Output: amplitude blend. Null uses injury cubed.
@export var health_sway_curve: Curve
@export_range(0.0, 1.0, 0.01) var aim_sway_blend_in_time: float = 0.15
@export_group("Prototype debug")
@export var show_aim_debug: bool = true
@export var debug_length: float = 160.0
@export var debug_color: Color = Color(1.0, 0.8, 0.3, 0.55)
@export var target_debug_color: Color = Color(0.3, 0.8, 1.0, 0.7)
@export var current_debug_color: Color = Color(0.6, 1.0, 0.4, 0.7)

var is_aiming: bool = false
var target_aim_direction: Vector2:
	get:
		return Vector2.UP.rotated(global_rotation + _target_angle)
var current_aim_direction: Vector2:
	get:
		return Vector2.UP.rotated(global_rotation + _current_angle)
var final_aim_direction: Vector2:
	get:
		return Vector2.UP.rotated(global_rotation + _final_angle)

# Angles are offsets from chair-local UP; rotating the chair preserves the arc.
var _target_angle: float = 0.0
var _current_angle: float = 0.0
var _final_angle: float = 0.0
var _aim_time: float = 0.0
var _health_ratio: float = 1.0
var _blocked: bool = false
var _equipment: Equipment


func _ready() -> void:
	# Resolve aim before FirearmController's default-priority physics step.
	process_physics_priority = -10
	get_window().focus_exited.connect(stop_aiming)


func bind_equipment(equipment: Equipment) -> void:
	_equipment = equipment
	_equipment.changed.connect(stop_aiming)


func set_blocked(blocked: bool) -> void:
	_blocked = blocked
	if blocked:
		stop_aiming()


func stop_aiming() -> void:
	_reset_aim()
	if is_aiming:
		is_aiming = false
		aiming_changed.emit()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			stop_aiming()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not _blocked:
			if _equipment != null and _equipment.get_weapon() != null:
				if _equipment.get_weapon().firearm_state != null:
					_reset_aim()
					is_aiming = true
					aiming_changed.emit()
					get_viewport().set_input_as_handled()


func direction_toward(world_point: Vector2) -> Vector2:
	var forward := Vector2.UP.rotated(global_rotation)
	var desired := world_point - global_position
	if desired.is_zero_approx():
		return forward
	var limit := deg_to_rad(aim_half_angle_degrees)
	return forward.rotated(clampf(forward.angle_to(desired), -limit, limit))


func get_aim_direction() -> Vector2:
	return final_aim_direction


func set_health_ratio(value: float) -> void:
	_health_ratio = clampf(value, 0.0, 1.0)


func _reset_aim() -> void:
	_target_angle = 0.0
	_current_angle = 0.0
	_final_angle = 0.0
	_aim_time = 0.0


func _physics_process(delta: float) -> void:
	if not is_aiming:
		return
	var forward := Vector2.UP.rotated(global_rotation)
	_target_angle = forward.angle_to(direction_toward(get_global_mouse_position()))
	var limit := deg_to_rad(aim_half_angle_degrees)
	var weight := 1.0 - exp(-aim_follow_speed * delta)
	_current_angle = clampf(lerp_angle(_current_angle, _target_angle, weight), -limit, limit)
	_aim_time += delta
	var injury := 1.0 - _health_ratio
	var influence := health_sway_curve.sample(injury) if health_sway_curve != null \
		else pow(injury, 3.0)
	influence = clampf(influence, 0.0, 1.0)
	var drift := lerpf(healthy_drift_amplitude, injured_drift_amplitude, influence)
	var tremor := lerpf(healthy_tremor_amplitude, injured_tremor_amplitude, influence)
	var drift_phase := _aim_time * drift_speed * TAU
	var tremor_phase := _aim_time * tremor_speed * TAU
	# Bounded, continuous mixtures; no new random sample per frame or per pellet.
	var sway := drift * (sin(drift_phase) + 0.5 * sin(drift_phase * 1.73)) / 1.5
	sway += tremor * (sin(tremor_phase) + 0.3 * sin(tremor_phase * 1.37)) / 1.3
	var blend := minf(_aim_time / aim_sway_blend_in_time, 1.0) \
		if aim_sway_blend_in_time > 0.0 else 1.0
	_final_angle = clampf(_current_angle + deg_to_rad(sway * blend), -limit, limit)
	aim_updated.emit()
	queue_redraw()


func _draw() -> void:
	if not is_aiming or not show_aim_debug:
		return
	var limit := deg_to_rad(aim_half_angle_degrees)
	for angle in [-limit, limit]:
		draw_line(Vector2.ZERO, Vector2.UP.rotated(angle) * debug_length, debug_color, 1.0)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(_target_angle) * debug_length,
		target_debug_color, 1.0)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(_current_angle) * debug_length,
		current_debug_color, 2.0)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(_final_angle) * debug_length, debug_color, 1.0)
