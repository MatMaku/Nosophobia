extends CharacterBody2D
## Stationary damage receiver; no movement, AI or weapon knowledge.

const HealthComponent = preload("res://scripts/combat/health_component.gd")

@export var show_health_debug: bool = true

@onready var health: HealthComponent = $HealthComponent
@onready var _health_label: Label = $HealthLabel


func _ready() -> void:
	health.died.connect(queue_free)
	health.damaged.connect(_update_health_label)
	_health_label.visible = show_health_debug
	_update_health_label()


func take_damage(amount: float) -> void:
	health.take_damage(amount)


func _update_health_label(_amount: float = 0.0) -> void:
	_health_label.text = "HP: %s / %s" % [health.current_health, health.max_health]
