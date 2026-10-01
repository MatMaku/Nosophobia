@tool
extends StaticBody2D
## Damageable glass; the body barrier remains after hitscan stops seeing the pane.

const HealthComponent = preload("res://scripts/combat/health_component.gd")
const BODY_BARRIER_LAYER: int = 4
const HITSCAN_LAYER: int = 1

enum GlassState { INTACT, CRACKED, BROKEN }

@export_group("Size")
@export var pane_size: Vector2 = Vector2(96, 16):
	set(value):
		pane_size = value.max(Vector2(24, 12))
		_sync_size()
@export_group("Durability")
@export_range(1.0, 1000.0, 1.0) var max_durability: float = 75.0
@export_group("Broken glass")
@export_range(0.0, 64.0, 1.0) var shard_scatter_distance: float = 20.0
@export_range(0.0, 0.5, 0.01) var shard_scatter_time: float = 0.12
@export_group("Visual States")
@export var intact_texture: Texture2D:
	set(value):
		intact_texture = value
		_refresh_visual()
@export var cracked_texture: Texture2D
@export var broken_texture: Texture2D

@onready var health: HealthComponent = $HealthComponent
@onready var _visual: NinePatchRect = $Visual
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _shards: Sprite2D = $Shards

var state: GlassState = GlassState.INTACT
var _last_impact_direction := Vector2.ZERO


func _ready() -> void:
	_collision.shape = RectangleShape2D.new()
	_sync_size()
	_refresh_visual()
	if not Engine.is_editor_hint():
		health.reset(max_durability)
		health.damaged.connect(_on_damaged)
		collision_layer = BODY_BARRIER_LAYER | HITSCAN_LAYER


func take_damage(amount: float) -> void:
	if not Engine.is_editor_hint():
		_last_impact_direction = Vector2.ZERO
		health.take_damage(amount)


func take_damage_from_hit(amount: float, world_direction: Vector2) -> void:
	if Engine.is_editor_hint():
		return
	var local_target := to_local(global_position + world_direction.normalized())
	_last_impact_direction = local_target.normalized()
	health.take_damage(amount)


func _on_damaged(_amount: float) -> void:
	if health.current_health <= 0.0:
		state = GlassState.BROKEN
		# Hitscan uses layer 1; bodies also use layer 3. No extra raycast needed.
		collision_layer = BODY_BARRIER_LAYER
	elif health.current_health <= health.max_health * 0.5:
		state = GlassState.CRACKED
	_refresh_visual()
	if state == GlassState.BROKEN:
		_scatter_shards()


func _scatter_shards() -> void:
	var direction := _last_impact_direction
	if direction.is_zero_approx():
		direction = Vector2.DOWN
	_shards.position = Vector2.ZERO
	var destination := direction * shard_scatter_distance
	if shard_scatter_time <= 0.0:
		_shards.position = destination
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shards, "position", destination, shard_scatter_time)


func _sync_size() -> void:
	if not is_node_ready():
		return
	_collision.shape.size = pane_size
	_visual.position = -pane_size * 0.5
	_visual.size = pane_size
	if _shards.texture != null:
		_shards.scale = Vector2(pane_size.x / _shards.texture.get_width(), 1.0)


func _refresh_visual() -> void:
	if not is_node_ready():
		return
	match state:
		GlassState.INTACT:
			_visual.texture = intact_texture
		GlassState.CRACKED:
			_visual.texture = cracked_texture
		GlassState.BROKEN:
			_visual.texture = broken_texture
	_shards.visible = state == GlassState.BROKEN
