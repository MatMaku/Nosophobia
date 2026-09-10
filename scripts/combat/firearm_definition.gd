class_name FirearmDefinition
extends Resource
## Shared gameplay configuration. Spread is the FULL cone, in degrees.

@export var compatible_ammo: ItemDefinition
@export_range(1, 32, 1) var capacity: int = 6
@export_range(1, 32, 1) var pellet_count: int = 1
## Damage per ray/pellet that hits a damage receiver.
@export_range(0.0, 1000.0, 1.0) var damage: float = 25.0
@export_range(0.0, 90.0, 0.1) var spread_degrees: float = 3.0
@export_range(1.0, 3000.0, 1.0) var range: float = 900.0
@export_range(0.0, 2000.0, 1.0) var recoil_impulse: float = 70.0
@export_range(0.01, 5.0, 0.01) var fire_interval: float = 0.35
