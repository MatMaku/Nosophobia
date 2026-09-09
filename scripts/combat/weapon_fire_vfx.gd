extends Node2D
## World-space shot presentation. Templates and tuning live in the scene.

@export_group("Flash")
@export_range(0.01, 0.2, 0.01) var flash_lifetime: float = 0.05
@export_range(0.0, 8.0, 0.1) var default_light_energy: float = 1.2
@export_range(0.01, 0.2, 0.01) var default_light_duration: float = 0.05
@export_group("Smoke")
@export var smoke_textures: Array[Texture2D] = []
@export_range(0, 5, 1) var smoke_puff_count: int = 3
@export_range(0.05, 2.0, 0.05) var smoke_lifetime: float = 0.65
@export var smoke_distance: float = 12.0
@export var smoke_scale_growth: float = 1.5

@onready var _flash_template: Sprite2D = $FlashTemplate
@onready var _smoke_template: Sprite2D = $SmokeTemplate
@onready var _light_template: PointLight2D = $LightTemplate
var _random := RandomNumberGenerator.new()


func show_shot(origin: Vector2, direction: Vector2,
		light_energy: float = -1.0, light_duration: float = -1.0) -> void:
	var flash := _flash_template.duplicate() as Sprite2D
	add_child(flash)
	flash.global_position = origin
	flash.global_rotation = direction.angle() - PI * 0.5
	flash.show()
	var flash_tween := flash.create_tween()
	flash_tween.tween_interval(flash_lifetime)
	flash_tween.tween_callback(flash.queue_free)
	_show_light(origin,
		default_light_energy if light_energy < 0.0 else light_energy,
		default_light_duration if light_duration < 0.0 else light_duration)
	if smoke_textures.is_empty():
		return
	for puff in smoke_puff_count:
		_show_smoke(origin, direction)


func _show_smoke(origin: Vector2, direction: Vector2) -> void:
	var smoke := _smoke_template.duplicate() as Sprite2D
	smoke.texture = smoke_textures[_random.randi_range(0, smoke_textures.size() - 1)]
	add_child(smoke)
	smoke.global_position = origin
	smoke.global_rotation = _random.randf_range(-PI, PI)
	smoke.show()
	var drift := direction.rotated(_random.randf_range(-0.5, 0.5))
	var distance := smoke_distance * _random.randf_range(0.7, 1.3)
	var lifetime := smoke_lifetime * _random.randf_range(0.85, 1.15)
	var growth := smoke_scale_growth * _random.randf_range(0.9, 1.1)
	var movement := smoke.create_tween().set_parallel(true)
	movement.tween_property(smoke, "global_position", origin + drift * distance, lifetime)
	movement.tween_property(smoke, "scale", smoke.scale * growth, lifetime)
	var fade := smoke.create_tween()
	fade.tween_interval(lifetime * 0.25)
	fade.tween_property(smoke, "modulate:a", 0.0, lifetime * 0.75)
	fade.tween_callback(smoke.queue_free)


func _show_light(origin: Vector2, energy: float, lifetime: float) -> void:
	if energy <= 0.0 or lifetime <= 0.0:
		return
	var light := _light_template.duplicate() as PointLight2D
	add_child(light)
	light.global_position = origin
	light.energy = energy
	light.show()
	var tween := light.create_tween()
	tween.tween_property(light, "energy", 0.0, lifetime)
	tween.tween_callback(light.queue_free)


func show_impact(position: Vector2, normal: Vector2) -> void:
	if not smoke_textures.is_empty():
		_show_smoke(position, normal)
