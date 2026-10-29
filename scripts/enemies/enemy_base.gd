@tool
extends CharacterBody2D
## Stationary damage receiver; no movement, AI or weapon knowledge.

const HealthComponent = preload("res://scripts/combat/health_component.gd")

@export_group("Visual")
@export var sprite: Texture2D = preload("res://assets/sprites/ui/reference/godot_icon.svg"):
	set(value):
		sprite = value
		_sync_visual()
@export_range(0.01, 5.0, 0.01) var visual_scale: float = 0.32:
	set(value):
		visual_scale = value
		_sync_visual()
@export_group("Health")
@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0
@export_group("Collision Advanced")
## Independent of sprite scale. Each instance owns its circle shape.
@export_range(1.0, 100.0, 1.0) var collision_radius: float = 20.0:
	set(value):
		collision_radius = value
		_sync_visual()
@export_group("Debug")
@export var show_health_debug: bool = true

@onready var health: HealthComponent = $HealthComponent
@onready var _health_label: Label = $HealthLabel


func _ready() -> void:
	$CollisionShape2D.shape = CircleShape2D.new()
	_sync_visual()
	if Engine.is_editor_hint():
		$HealthLabel.hide()
		return
	health.reset(max_health)
	health.died.connect(queue_free)
	health.damaged.connect(_update_health_label)
	_health_label.visible = show_health_debug
	_update_health_label()


func take_damage(amount: float) -> void:
	health.take_damage(amount)


func set_debug_visuals_enabled(enabled: bool) -> void:
	_health_label.visible = enabled and show_health_debug


func _sync_visual() -> void:
	if not is_node_ready():
		return
	$Visual.texture = sprite
	$Visual.scale = Vector2.ONE * visual_scale
	$CollisionShape2D.shape.radius = collision_radius
	$NavigationObstacle2D.radius = collision_radius


func _update_health_label(_amount: float = 0.0) -> void:
	_health_label.text = "HP: %s / %s" % [health.current_health, health.max_health]
