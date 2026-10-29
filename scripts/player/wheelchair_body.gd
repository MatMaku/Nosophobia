@tool
extends RigidBody2D
## Local UP is forward; local RIGHT is the wheel axle (lateral direction).

const LOCAL_FORWARD := Vector2.UP
const WheelchairInput = preload("res://scripts/player/wheelchair_input.gd")

@export_group("Health")
@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0:
	set(value):
		max_health = value
		if is_node_ready() and not Engine.is_editor_hint():
			health.max_health = value

@onready var health = $HealthComponent
var god_mode: bool = false
var _noclip: bool = false
var _noclip_applied: bool = false
var _original_shape_disabled: bool = false
var _original_inertia: float = 0.0
var _effective_inertia: float = 0.0
var _keyboard_noclip_moving: bool = false
var _noclip_direction := Vector2.ZERO

## Force/torque per unit of local mouse speed (pixels per second).
@export_group("Movement")
@export_range(0.0, 30.0, 0.1) var propulsion_force: float = 0.8
@export_range(0.0, 3000.0, 10.0) var turn_force: float = 60.0
@export var invert_turn: bool = false
## Lateral velocity decay rate, in inverse seconds.
@export_range(0.0, 60.0, 0.1) var lateral_grip: float = 12.0

@export_group("Input")
## Gesture radius in world units; independent of pickup distance.
@export_range(10.0, 200.0, 1.0) var interaction_radius: float = 80.0
@export_range(10.0, 200.0, 1.0) var pickup_distance: float = 70.0
@export_group("Aim")
@export_range(0.0, 89.0, 1.0) var aim_half_angle_degrees: float = 45.0
@export_range(0.1, 30.0, 0.1) var aim_follow_speed: float = 10.0
@export_group("Camera")
@export_range(0.25, 5.0, 0.05) var camera_zoom: float = 2.5:
	set(value):
		camera_zoom = value
		if is_node_ready():
			$Camera2D.zoom = Vector2.ONE * value
@export_group("Debug")
@export_range(10.0, 1000.0, 10.0) var noclip_speed: float = 240.0
@export var show_movement_debug: bool = true
@export var show_aim_debug: bool = true

@onready var _mouse_input: WheelchairInput = $WheelchairInput


func _ready() -> void:
	$Camera2D.zoom = Vector2.ONE * camera_zoom
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_mouse_input.interaction_radius = interaction_radius
	health.reset(max_health)
	health.died.connect(_on_died)
	$PickupInteractor.pickup_distance = pickup_distance
	$WeaponAim.aim_half_angle_degrees = aim_half_angle_degrees
	$WeaponAim.aim_follow_speed = aim_follow_speed
	$WeaponAim.show_aim_debug = show_aim_debug
	$Debug.visible = show_movement_debug


func _physics_process(delta: float) -> void:
	if health.current_health <= 0.0:
		return
	var gesture_velocity := _mouse_input.consume_motion() / delta
	var turn_sign := -1.0 if invert_turn else 1.0
	apply_torque(gesture_velocity.x * turn_force * turn_sign)
	_noclip_direction = _mouse_input.get_noclip_direction() if _noclip_applied else Vector2.ZERO
	if _noclip_direction != Vector2.ZERO:
		# A sleeping body must wake before its integration callback can run.
		sleeping = false
		return
	if _keyboard_noclip_moving:
		return
	var forward := LOCAL_FORWARD.rotated(global_rotation)
	var sideways := Vector2.RIGHT.rotated(global_rotation)
	apply_central_force(forward * -gesture_velocity.y * propulsion_force)
	# Exponential decay keeps strong grip gradual and stable at different tick rates.
	var lateral_speed := linear_velocity.dot(sideways)
	var resistance := mass * (1.0 - exp(-lateral_grip * delta)) / delta
	apply_central_force(-sideways * lateral_speed * resistance)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if Engine.is_editor_hint():
		return
	if not _noclip_applied and state.inverse_inertia > 0.0:
		_effective_inertia = 1.0 / state.inverse_inertia
	if health.current_health <= 0.0:
		return
	# Only debug travel overrides velocity; normal motion remains force-driven.
	if _noclip_applied and _noclip_direction != Vector2.ZERO:
		state.linear_velocity = _noclip_direction * noclip_speed
		_keyboard_noclip_moving = true
	elif _keyboard_noclip_moving:
		state.linear_velocity = Vector2.ZERO
		_keyboard_noclip_moving = false


## World-space impulse; an optional world-space offset from the body center adds spin.
func apply_external_impulse(impulse: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	if health.current_health > 0.0:
		apply_impulse(impulse, offset)


func take_damage(amount: float) -> void:
	if not god_mode:
		health.take_damage(amount)


func heal(amount: float) -> void:
	health.heal(amount)


func set_noclip(enabled: bool) -> void:
	if _noclip == enabled:
		return
	_noclip = enabled
	_apply_noclip.call_deferred()


func _apply_noclip() -> void:
	# Coalesce rapid toggles before touching physics; never snapshot our own disabled state.
	if _noclip_applied == _noclip:
		return
	if _noclip:
		_original_shape_disabled = $CollisionShape2D.disabled
		_original_inertia = inertia
		# Disabling the last shape removes automatic inertia, and torque stops rotating.
		if inertia == 0.0 and _effective_inertia > 0.0:
			inertia = _effective_inertia
	else:
		inertia = _original_inertia
		_noclip_direction = Vector2.ZERO
	$CollisionShape2D.disabled = true if _noclip else _original_shape_disabled
	_noclip_applied = _noclip


func set_debug_visuals_enabled(enabled: bool) -> void:
	$Debug.visible = enabled and show_movement_debug
	$Debug.set_process($Debug.visible)
	$WeaponAim.show_aim_debug = enabled and show_aim_debug
	$WeaponAim.queue_redraw()


func _on_died() -> void:
	_mouse_input.set_input_enabled(false)
	$WeaponAim.set_blocked(true)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	set_deferred("freeze", true)
