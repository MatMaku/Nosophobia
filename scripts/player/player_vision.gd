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
		# Thick walls use a private far-edge polygon; zero-width occluders stay shared.
		if _get_occlusion_width(source) > 0.0:
			copy.occluder = OccluderPolygon2D.new()
		else:
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
		var width := _get_occlusion_width(source)
		if width > 0.0:
			if copy.occluder == source.occluder:
				copy.occluder = OccluderPolygon2D.new()
			_sync_far_edge(source, copy, width)
		else:
			copy.occluder = source.occluder


func _get_occlusion_width(source: LightOccluder2D) -> float:
	return maxf(float(source.get_meta("vision_occlusion_width", 0.0)), 0.0)


func _sync_far_edge(source: LightOccluder2D, copy: LightOccluder2D, width: float) -> void:
	var authored := source.occluder.polygon
	if authored.size() < 2:
		copy.occluder.polygon = authored
		return
	var viewer := source.to_local(global_position)
	var normals: Array[Vector2] = []
	var segment_count := authored.size() if source.occluder.closed else authored.size() - 1
	for index in segment_count:
		var next := (index + 1) % authored.size()
		var midpoint := (authored[index] + authored[next]) * 0.5
		var normal := (authored[next] - authored[index]).orthogonal().normalized()
		if normal.dot(midpoint - viewer) < 0.0:
			normal = -normal
		normals.append(normal)
	var far_edge := PackedVector2Array()
	for index in authored.size():
		var normal: Vector2
		if not source.occluder.closed and index == 0:
			normal = normals[0]
		elif not source.occluder.closed and index == authored.size() - 1:
			normal = normals[-1]
		else:
			var previous := normals[(index - 1 + normals.size()) % normals.size()]
			var following := normals[index % normals.size()]
			var joined := previous + following
			normal = following if joined.is_zero_approx() else joined.normalized()
			var projection := maxf(absf(normal.dot(following)), 0.25)
			normal /= projection
		far_edge.append(authored[index] + normal * width * 0.5)
	copy.occluder.polygon = far_edge
	copy.occluder.closed = source.occluder.closed
	copy.occluder.cull_mode = OccluderPolygon2D.CULL_DISABLED
