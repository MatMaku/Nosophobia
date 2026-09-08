extends Node2D
## Local UP is forward. One shared half-angle applies to every equipped firearm.

signal aiming_changed

const Equipment = preload("res://scripts/inventory/equipment.gd")

@export_range(0.0, 89.0, 1.0) var aim_half_angle_degrees: float = 55.0
@export_group("Prototype debug")
@export var show_aim_debug: bool = true
@export var debug_length: float = 160.0
@export var debug_color: Color = Color(1.0, 0.8, 0.3, 0.55)

var is_aiming: bool = false
var _blocked: bool = false
var _equipment: Equipment


func _ready() -> void:
	get_window().focus_exited.connect(stop_aiming)


func bind_equipment(equipment: Equipment) -> void:
	_equipment = equipment
	_equipment.changed.connect(stop_aiming)


func set_blocked(blocked: bool) -> void:
	_blocked = blocked
	if blocked:
		stop_aiming()


func stop_aiming() -> void:
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
	return direction_toward(get_global_mouse_position())


func _process(_delta: float) -> void:
	if is_aiming:
		queue_redraw()


func _draw() -> void:
	if not is_aiming or not show_aim_debug:
		return
	var limit := deg_to_rad(aim_half_angle_degrees)
	for angle in [-limit, limit]:
		draw_line(Vector2.ZERO, Vector2.UP.rotated(angle) * debug_length, debug_color, 1.0)
	var local_direction := get_aim_direction().rotated(-global_rotation)
	draw_line(Vector2.ZERO, local_direction * debug_length, debug_color, 2.0)
