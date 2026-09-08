extends RigidBody2D
## Local UP is forward; local RIGHT is the wheel axle (lateral direction).

const LOCAL_FORWARD := Vector2.UP
const WheelchairInput = preload("res://scripts/player/wheelchair_input.gd")

## Force/torque per unit of local mouse speed (pixels per second).
@export_range(0.0, 30.0, 0.1) var propulsion_force: float = 0.8
@export_range(0.0, 3000.0, 10.0) var turn_force: float = 60.0
@export var invert_turn: bool = false
## Lateral velocity decay rate, in inverse seconds.
@export_range(0.0, 60.0, 0.1) var lateral_grip: float = 12.0

@onready var _mouse_input: WheelchairInput = $WheelchairInput


func _physics_process(delta: float) -> void:
	var gesture_velocity := _mouse_input.consume_motion() / delta
	var forward := LOCAL_FORWARD.rotated(global_rotation)
	var sideways := Vector2.RIGHT.rotated(global_rotation)
	apply_central_force(forward * -gesture_velocity.y * propulsion_force)
	var turn_sign := -1.0 if invert_turn else 1.0
	apply_torque(gesture_velocity.x * turn_force * turn_sign)
	# Exponential decay keeps strong grip gradual and stable at different tick rates.
	var lateral_speed := linear_velocity.dot(sideways)
	var resistance := mass * (1.0 - exp(-lateral_grip * delta)) / delta
	apply_central_force(-sideways * lateral_speed * resistance)


## World-space impulse; an optional world-space offset from the body center adds spin.
func apply_external_impulse(impulse: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	apply_impulse(impulse, offset)
