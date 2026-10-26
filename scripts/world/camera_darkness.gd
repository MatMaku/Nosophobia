extends CanvasLayer
## Lamp centers are unrestricted; their darkness relief is clipped per pixel to LOS.

const MAX_LIGHTS: int = 32

@export var viewer: Node2D
@export var visibility_mask: SubViewport
@export var lights: Array[PointLight2D] = []
@export_group("Screen darkness")
## Radii measured as fractions of viewport height; independent of camera zoom.
@export_range(0.0, 1.0, 0.01) var clear_radius: float = 0.18
@export_range(0.1, 2.0, 0.01) var dark_radius: float = 0.75
@export_range(0.0, 1.0, 0.01) var darkness: float = 0.98
@export_range(0.1, 3.0, 0.05) var lamp_relief: float = 1.0

@onready var _cover: ColorRect = $Cover
var _light_data := PackedVector4Array()


func _ready() -> void:
	_light_data.resize(MAX_LIGHTS)
	if is_instance_valid(visibility_mask):
		_cover.material.set_shader_parameter("hidden_mask", visibility_mask.get_texture())
		_cover.material.set_shader_parameter("has_visibility_mask", true)
	RenderingServer.frame_pre_draw.connect(_sync)
	if lights.size() > MAX_LIGHTS:
		push_warning("CameraDarkness supports up to 32 configured lamps.")


func _sync() -> void:
	if not is_instance_valid(viewer):
		_cover.hide()
		return
	_cover.show()
	var size := get_viewport().get_visible_rect().size
	var count := 0
	for light in lights:
		if count == MAX_LIGHTS:
			break
		if not is_instance_valid(light) or not light.enabled or not light.is_visible_in_tree():
			continue
		if light.texture == null or light.energy <= 0.0:
			continue
		var pose := light.get_global_transform_with_canvas()
		var center := pose * light.offset
		var radius := light.texture.get_width() * light.texture_scale * pose.x.length() * 0.5
		_light_data[count] = Vector4(center.x, center.y, radius, light.energy * lamp_relief)
		count += 1
	var material := _cover.material as ShaderMaterial
	material.set_shader_parameter("viewport_size", size)
	material.set_shader_parameter("viewer_position", viewer.get_global_transform_with_canvas().origin)
	material.set_shader_parameter("clear_radius", clear_radius * size.y)
	material.set_shader_parameter("dark_radius", maxf(dark_radius, clear_radius + 0.01) * size.y)
	material.set_shader_parameter("darkness", darkness)
	material.set_shader_parameter("lamps", _light_data)
	material.set_shader_parameter("lamp_count", count)


func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_sync)
