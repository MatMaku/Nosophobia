extends Node2D
## A separate 2D canvas produces visibility, never decorative illumination.

const VISIBILITY_OCCLUSION: int = 1

@onready var _mask: SubViewport = $VisibilityMask
@onready var _surface: Polygon2D = $VisibilityMask/MaskSurface
@onready var _origin: Node2D = $VisibilityMask/VisionOrigin
@onready var _occluder_root: Node2D = $VisibilityMask/Occluders

var _sources: Array[LightOccluder2D] = []
var _copies: Array[LightOccluder2D] = []


func _ready() -> void:
	get_viewport().size_changed.connect(_resize_mask)
	_resize_mask()
	# Synchronize after camera/input processing, immediately before rendering.
	RenderingServer.frame_pre_draw.connect(_sync_mask)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_mask):
		RenderingServer.frame_pre_draw.disconnect(_sync_mask)


func bind_occluders(sources: Array[LightOccluder2D]) -> void:
	for copy in _copies:
		copy.free()
	_copies.clear()
	_sources.assign(sources)
	for source in _sources:
		var copy := LightOccluder2D.new()
		# Share the resource: editing the world polygon also edits visibility geometry.
		copy.occluder = source.occluder
		copy.occluder_light_mask = VISIBILITY_OCCLUSION
		_occluder_root.add_child(copy)
		_copies.append(copy)
	_sync_mask()


func get_visibility_texture() -> ViewportTexture:
	return _mask.get_texture()


func _resize_mask() -> void:
	var extent := Vector2i(get_viewport_rect().size).max(Vector2i(2, 2))
	_mask.size = extent
	_surface.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(extent.x, 0), Vector2(extent), Vector2(0, extent.y),
	])


func _sync_mask() -> void:
	_mask.canvas_transform = get_viewport().canvas_transform
	_surface.transform = _mask.canvas_transform.affine_inverse()
	_origin.global_transform = global_transform
	for index in _sources.size():
		var source := _sources[index]
		var copy := _copies[index]
		copy.visible = is_instance_valid(source) and source.is_visible_in_tree()
		if not copy.visible:
			continue
		copy.visible = (source.occluder_light_mask & VISIBILITY_OCCLUSION) != 0
		copy.global_transform = source.global_transform
		copy.occluder = source.occluder
