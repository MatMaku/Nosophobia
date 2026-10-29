@tool
extends Node2D
## Builds a small imperfect light mask once; only subtle energy variation runs per frame.

const TEXTURE_SIZE: int = 128

@export_group("Light")
@export var light_color: Color = Color(1, 0.88, 0.72):
	set(value):
		light_color = value
		_refresh_settings()
@export_range(0.0, 8.0, 0.05) var light_energy: float = 1.0:
	set(value):
		light_energy = value
		_refresh_settings()
## World-space radius at root Scale=1. Does not increase player visibility.
@export_range(8.0, 1000.0, 1.0) var light_radius: float = 64.0:
	set(value):
		light_radius = value
		_refresh_settings()
@export_group("Light character")
@export_range(0.0, 1.0, 0.01) var edge_hardness: float = 0.78:
	set(value):
		edge_hardness = value
		_queue_texture()
@export_range(0.1, 1.0, 0.01) var center_intensity: float = 0.72:
	set(value):
		center_intensity = value
		_queue_texture()
@export_range(0.0, 0.3, 0.01) var noise_amount: float = 0.1:
	set(value):
		noise_amount = value
		_queue_texture()
		_refresh_settings()
@export_range(1.0, 12.0, 0.25) var noise_scale: float = 5.0:
	set(value):
		noise_scale = value
		_queue_texture()
## Subtle energy variation only in gameplay; zero disables flicker.
@export_range(0.0, 2.0, 0.05) var noise_speed: float = 0.35:
	set(value):
		noise_speed = value
		_refresh_settings()

@onready var _light: PointLight2D = $PointLight2D

var _base_energy: float
var _elapsed: float = 0.0
var _phase: float
var _texture_pending := false


func _ready() -> void:
	_phase = float(abs(get_path().hash()) % 1000) * TAU / 1000.0
	_light.texture = _build_light_texture()
	_refresh_settings()


func _refresh_settings() -> void:
	if not is_node_ready():
		return
	_base_energy = light_energy
	_light.energy = light_energy
	_light.color = light_color
	_light.texture_scale = light_radius * 2.0 / TEXTURE_SIZE
	set_process(not Engine.is_editor_hint() and noise_amount > 0.0 and noise_speed > 0.0)


func _queue_texture() -> void:
	if is_node_ready() and not _texture_pending:
		_texture_pending = true
		_refresh_texture.call_deferred()


func _refresh_texture() -> void:
	_texture_pending = false
	_light.texture = _build_light_texture()


func _process(delta: float) -> void:
	_elapsed += delta
	var primary := sin(_elapsed * noise_speed * TAU + _phase)
	var secondary := sin(_elapsed * noise_speed * 1.73 * TAU + _phase * 0.61)
	var variation := (primary + secondary * 0.35) * noise_amount * 0.08
	_light.energy = _base_energy * (1.0 + variation)


func _build_light_texture() -> ImageTexture:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = get_path().hash()
	noise.frequency = noise_scale / float(TEXTURE_SIZE)
	var falloff_power := lerpf(1.1, 2.2, edge_hardness)
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var centered := Vector2(x, y) / float(TEXTURE_SIZE - 1) * 2.0 - Vector2.ONE
			var radial_distance := centered.length()
			var sample := noise.get_noise_2d(float(x), float(y))
			var warped_radius := radial_distance + sample * noise_amount
			var distance_falloff := 1.0 - smoothstep(0.0, 1.0, warped_radius)
			var alpha := center_intensity * pow(distance_falloff, falloff_power)
			var edge_mix := smoothstep(0.25, 1.0, radial_distance)
			alpha *= 1.0 - (sample * 0.5 + 0.5) * noise_amount * 0.12 * edge_mix
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
