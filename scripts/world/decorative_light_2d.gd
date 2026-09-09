extends Node2D
## Builds a small imperfect light mask once; only subtle energy variation runs per frame.

const TEXTURE_SIZE: int = 128

@export_group("Light character")
@export_range(0.0, 1.0, 0.01) var edge_hardness: float = 0.78
@export_range(0.0, 0.3, 0.01) var noise_amount: float = 0.1
@export_range(1.0, 12.0, 0.25) var noise_scale: float = 5.0
@export_range(0.0, 2.0, 0.05) var noise_speed: float = 0.35

@onready var _light: PointLight2D = $PointLight2D

var _base_energy: float
var _elapsed: float = 0.0
var _phase: float


func _ready() -> void:
	_base_energy = _light.energy
	_phase = float(abs(get_path().hash()) % 1000) * TAU / 1000.0
	_light.texture = _build_light_texture()
	set_process(noise_amount > 0.0 and noise_speed > 0.0)


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
	var edge_width := lerpf(0.48, 0.12, edge_hardness)
	var edge_start := 1.0 - edge_width
	var levels := roundi(lerpf(14.0, 6.0, edge_hardness))
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var centered := Vector2(x, y) / float(TEXTURE_SIZE - 1) * 2.0 - Vector2.ONE
			var radial_distance := centered.length()
			var sample := noise.get_noise_2d(float(x), float(y))
			var warped_radius := radial_distance + sample * noise_amount
			var alpha := 1.0 - smoothstep(edge_start, 1.0, warped_radius)
			var edge_mix := smoothstep(0.25, 1.0, radial_distance)
			alpha *= 1.0 - (sample * 0.5 + 0.5) * noise_amount * 0.12 * edge_mix
			alpha = round(alpha * levels) / float(levels)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
