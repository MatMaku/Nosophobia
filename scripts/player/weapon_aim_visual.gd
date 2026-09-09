extends Node2D
## DOWN-facing art; consumes the effective aim direction, never mouse input.

@export var aim_visual_rotation_offset: float = 0.091
@export_group("Visual recoil")
## Distance is in pose-art pixels, independent of physical recoil impulse.
@export var visual_recoil_distance: float = 24.0
@export var visual_recoil_kick_time: float = 0.025
@export var visual_recoil_return_time: float = 0.12
@export_group("Shot feedback")
@export_range(0.0, 8.0, 0.1) var camera_shake_strength: float = 2.4
@export_range(0.01, 0.3, 0.01) var camera_shake_duration: float = 0.12
@export_range(0.0, 8.0, 0.1) var muzzle_light_energy: float = 1.8
@export_range(0.01, 0.2, 0.01) var muzzle_light_duration: float = 0.06
@onready var _upper: Node2D = $AimUpperBody
@onready var _muzzle: Marker2D = $AimUpperBody/AimMuzzle
@onready var _rest_position: Vector2 = _upper.position
var _recoil_tween: Tween


func update_direction(direction: Vector2) -> void:
	_upper.global_rotation = direction.angle() - PI * 0.5 + aim_visual_rotation_offset


func get_muzzle() -> Marker2D:
	return _muzzle


func get_shot_feedback() -> Dictionary:
	return {
		"shake_strength": camera_shake_strength,
		"shake_duration": camera_shake_duration,
		"light_energy": muzzle_light_energy,
		"light_duration": muzzle_light_duration,
	}


func show_recoil(direction: Vector2) -> void:
	reset_recoil()
	var local_direction := global_transform.basis_xform_inv(direction).normalized()
	var kick := _rest_position - local_direction * visual_recoil_distance
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_upper, "position", kick, visual_recoil_kick_time)
	_recoil_tween.tween_property(_upper, "position", _rest_position,
		visual_recoil_return_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func reset_recoil(reset_rotation: bool = false) -> void:
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	_upper.position = _rest_position
	if reset_rotation:
		_upper.rotation = 0.0
