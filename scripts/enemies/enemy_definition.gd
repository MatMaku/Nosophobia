class_name EnemyDefinition
extends Resource
## Shared type data. Never store detection, health or route progress here.

@export_group("Movement")
@export_range(0.0, 400.0, 1.0) var patrol_speed: float = 44.0
@export_range(0.0, 400.0, 1.0) var chase_speed: float = 80.0
@export_range(1.0, 2000.0, 1.0) var acceleration: float = 260.0
@export_range(1.0, 2000.0, 1.0) var deceleration: float = 360.0
@export_group("Perception")
@export_range(1.0, 1500.0, 1.0) var vision_distance: float = 260.0
@export_range(1.0, 360.0, 1.0) var vision_angle_degrees: float = 100.0
@export_range(0.0, 1500.0, 1.0) var hearing_radius: float = 220.0
@export_range(0.0, 30.0, 0.1) var target_memory_seconds: float = 3.0
@export_group("Combat (future, unused)")
@export_range(0.0, 1000.0, 1.0) var damage: float = 10.0
