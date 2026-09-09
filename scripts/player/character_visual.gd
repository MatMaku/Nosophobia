extends Node2D
## Presentation only. Art faces DOWN; the owning chair's physical forward is UP.

const WheelchairInput = preload("res://scripts/player/wheelchair_input.gd")
const WheelchairBody = preload("res://scripts/player/wheelchair_body.gd")
const WeaponAim = preload("res://scripts/player/weapon_aim_controller.gd")
const Equipment = preload("res://scripts/inventory/equipment.gd")
const AimVisual = preload("res://scripts/player/weapon_aim_visual.gd")

@export_group("Sources")
@export var mouse_input: WheelchairInput
@export var body: WheelchairBody
@export var aim: WeaponAim
@export_group("Wheels")
## Texture pixels travelled per world pixel of longitudinal movement.
@export var wheel_scroll_scale: float = 8.0

@onready var _left_arm: AnimatedSprite2D = $LeftArm
@onready var _right_arm: AnimatedSprite2D = $RightArm
@onready var _normal_layers: Array[CanvasItem] = [$Body, $Head, $LeftArm, $RightArm]
var _equipment: Equipment
var _pose: AimVisual
@onready var _wheel_treads: Array[Sprite2D] = [
	$WheelVisuals/RearLeft, $WheelVisuals/RearRight,
	$WheelVisuals/FrontLeft, $WheelVisuals/FrontRight,
]


func _process(delta: float) -> void:
	_sync_aim()
	_update_arms()
	_update_wheels(delta)


func bind_equipment(equipment: Equipment) -> void:
	_equipment = equipment
	_equipment.changed.connect(_rebuild_pose)
	aim.aiming_changed.connect(_sync_aim)
	aim.aim_updated.connect(_sync_aim)
	_rebuild_pose()


func _rebuild_pose() -> void:
	if is_instance_valid(_pose):
		_pose.hide()
		_pose.queue_free()
	_pose = null
	var weapon := _equipment.get_weapon()
	if weapon != null and weapon.definition.aim_pose != null:
		_pose = weapon.definition.aim_pose.instantiate() as AimVisual
		if _pose != null:
			add_child(_pose)
	_sync_aim()


func _sync_aim() -> void:
	var active := is_instance_valid(aim) and aim.is_aiming and is_instance_valid(_pose)
	for layer in _normal_layers:
		layer.visible = not active
	if is_instance_valid(_pose):
		if _pose.visible and not active:
			_pose.reset_recoil(true)
		_pose.visible = active
		if active:
			_pose.update_direction(aim.get_aim_direction())


## Apply the shared final aim at shot time before sampling the real muzzle position.
func get_aim_muzzle(direction: Vector2) -> Marker2D:
	if not is_instance_valid(_pose):
		return null
	_pose.update_direction(direction)
	return _pose.get_muzzle()


func show_recoil(_origin: Vector2, direction: Vector2) -> void:
	if is_instance_valid(_pose) and aim.is_aiming:
		_pose.show_recoil(direction)


func _update_arms() -> void:
	if not is_instance_valid(mouse_input) or not mouse_input.drag_active:
		_set_arm(_left_arm, &"idle", 0.0)
		_set_arm(_right_arm, &"idle", 0.0)
		return
	# Chair-local UP is forward and RIGHT is right, regardless of world rotation.
	var mouse := mouse_input.mouse_normalized_position
	var forward := mouse.dot(WheelchairBody.LOCAL_FORWARD)
	_set_arm(_left_arm, &"push", (forward + mouse.x + 1.0) * 0.5)
	_set_arm(_right_arm, &"push", (forward - mouse.x + 1.0) * 0.5)


func _set_arm(arm: AnimatedSprite2D, pose: StringName, progress: float) -> void:
	if arm.sprite_frames == null or not arm.sprite_frames.has_animation(pose):
		return
	var count := arm.sprite_frames.get_frame_count(pose)
	if count == 0:
		return
	arm.animation = pose
	arm.frame = roundi(clampf(progress, 0.0, 1.0) * (count - 1))


func _update_wheels(delta: float) -> void:
	if not is_instance_valid(body):
		return
	var forward := WheelchairBody.LOCAL_FORWARD.rotated(body.global_rotation)
	var distance := body.linear_velocity.dot(forward) * delta * wheel_scroll_scale
	if is_zero_approx(distance):
		return
	for tread in _wheel_treads:
		if tread.texture == null:
			continue
		var region := tread.region_rect
		# Increasing the sampled Y moves the pattern toward the rear of DOWN-facing art.
		region.position.y = fposmod(region.position.y + distance, tread.texture.get_height())
		tread.region_rect = region
