extends Node2D
## A separate 2D canvas produces visibility, never decorative illumination.

const VISIBILITY_OCCLUSION: int = 1

@export_group("Vision Shape")
@export_range(32.0, 500.0, 1.0) var peripheral_radius: float = 150.0
@export_range(32.0, 700.0, 1.0) var forward_radius: float = 320.0
@export_range(0.05, 0.6, 0.01) var edge_softness: float = 0.28
@export_range(0.5, 4.0, 0.1) var forward_shape_power: float = 1.6
@export_group("Occlusion Thickness")
## Fraction of wall/door visual width, centered on its source segment. Zero is a line.
@export_range(0.0, 1.0, 0.05) var occlusion_thickness_ratio: float = 0.5
## World-space tolerance for authored joints, not a blur radius.
@export_group("Occlusion Joints")
@export_range(0.1, 2.0, 0.1) var occlusion_join_margin: float = 1.0
@export_range(0.5, 15.0, 0.5) var closed_joint_angle_degrees: float = 4.0

@onready var _mask: SubViewport = $VisibilityMask
@onready var _surface: Polygon2D = $VisibilityMask/MaskSurface
@onready var _origin: Node2D = $VisibilityMask/VisionOrigin
@onready var _occluder_root: Node2D = $VisibilityMask/Occluders
@onready var _vision_light: PointLight2D = $VisibilityMask/VisionOrigin/VisionLight

var _sources: Array[LightOccluder2D] = []
var _copies: Array[LightOccluder2D] = []
var _segments: Array[PackedVector2Array] = []
var _widths: PackedFloat32Array = []
var _joints: Array[Vector4i] = []
var _bridges: Array[LightOccluder2D] = []


func _ready() -> void:
	_vision_light.texture = _create_vision_texture()
	_vision_light.texture_scale = maxf(forward_radius, peripheral_radius) / 128.0
	get_viewport().size_changed.connect(_resize_mask)
	_resize_mask()
	# Camera and mask use the same canvas transform, immediately before rendering.
	RenderingServer.frame_pre_draw.connect(_sync_mask)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_mask):
		RenderingServer.frame_pre_draw.disconnect(_sync_mask)


func bind_occluders(sources: Array[LightOccluder2D]) -> void:
	for copy in _copies + _bridges:
		copy.free()
	_copies.clear()
	_sources.clear()
	_segments.clear()
	_widths.clear()
	_joints.clear()
	_bridges.clear()
	for source in sources:
		if source.occluder == null:
			continue
		var width := maxf(float(source.get_meta("vision_occlusion_width", 0.0)), 0.0)
		var points := source.occluder.polygon
		if width <= 0.0:
			_add_copy(source, PackedVector2Array(), 0.0)
			continue
		var count := points.size() if source.occluder.closed else points.size() - 1
		for index in maxi(count, 0):
			var edge := PackedVector2Array([points[index], points[(index + 1) % points.size()]])
			if not edge[0].is_equal_approx(edge[1]):
				_add_copy(source, edge, width)
	# Author connections once. A swinging door keeps the hinge connection;
	# its free-end bridge is disabled as soon as it separates from the wall.
	for first in _copies.size():
		if _widths[first] <= 0.0:
			continue
		for second in range(first + 1, _copies.size()):
			if _widths[second] <= 0.0:
				continue
			for a in 2:
				for b in 2:
					var distance := _endpoint(first, a).distance_to(_endpoint(second, b))
					if distance <= occlusion_join_margin:
						_joints.append(Vector4i(first, a, second, b))
						_bridges.append(_new_edge())
	_sync_mask()


func _new_edge() -> LightOccluder2D:
	var copy := LightOccluder2D.new()
	copy.occluder = OccluderPolygon2D.new()
	copy.occluder.closed = false
	copy.occluder_light_mask = VISIBILITY_OCCLUSION
	_occluder_root.add_child(copy)
	return copy


func _add_copy(source: LightOccluder2D, edge: PackedVector2Array, width: float) -> void:
	var copy := _new_edge()
	if width <= 0.0:
		copy.occluder = source.occluder
	_sources.append(source)
	_copies.append(copy)
	_segments.append(edge)
	_widths.append(width)


func _endpoint(index: int, endpoint: int) -> Vector2:
	return _sources[index].to_global(_segments[index][endpoint])


func get_visibility_texture() -> ViewportTexture:
	return _mask.get_texture()


func _create_vision_texture() -> ImageTexture:
	const TEXTURE_SIZE: int = 256
	const HALF_SIZE: float = TEXTURE_SIZE * 0.5
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var maximum_radius := maxf(peripheral_radius, forward_radius)
	var peripheral_ratio := peripheral_radius / maximum_radius
	var forward_ratio := forward_radius / maximum_radius
	var fade_start := 1.0 - edge_softness
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var position := (Vector2(x + 0.5, y + 0.5) / HALF_SIZE) - Vector2.ONE
			var distance := position.length()
			var direction := position / distance if distance > 0.0 else Vector2.UP
			var frontness := clampf(-direction.y, 0.0, 1.0)
			frontness = frontness * frontness * (3.0 - 2.0 * frontness)
			var reach := lerpf(peripheral_ratio, forward_ratio,
				pow(frontness, forward_shape_power))
			var normalized_distance := distance / reach
			var alpha := 1.0 - smoothstep(fade_start, 1.0, normalized_distance)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


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
		if not copy.global_transform.is_equal_approx(source.global_transform):
			copy.global_transform = source.global_transform
		if _widths[index] <= 0.0:
			continue
		var edge := _segments[index]
		_set_edge(copy, edge[0], edge[1],
			_widths[index] * clampf(occlusion_thickness_ratio, 0.0, 1.0))
	for index in _joints.size():
		var joint := _joints[index]
		var bridge := _bridges[index]
		bridge.visible = _copies[joint.x].visible and _copies[joint.z].visible
		if not bridge.visible:
			continue
		bridge.visible = _joint_is_closed(joint)
		if not bridge.visible:
			continue
		# Joints reference source centerlines, not the corners of thickened polygons.
		var start := _endpoint(joint.x, joint.y)
		var end := _endpoint(joint.z, joint.w)
		bridge.visible = not start.is_equal_approx(end)
		var overlap := start.direction_to(end) * occlusion_join_margin
		_set_edge(bridge, start - overlap, end + overlap)


func _joint_is_closed(joint: Vector4i) -> bool:
	if _endpoint(joint.x, joint.y).distance_to(
		_endpoint(joint.z, joint.w)) > occlusion_join_margin:
		return false
	var first_is_dynamic := bool(_sources[joint.x].get_meta("vision_dynamic_joint", false))
	var second_is_dynamic := bool(_sources[joint.z].get_meta("vision_dynamic_joint", false))
	if not first_is_dynamic and not second_is_dynamic:
		return true
	var first := _sources[joint.x].global_transform.basis_xform(
		_segments[joint.x][1] - _segments[joint.x][0]).normalized()
	var second := _sources[joint.z].global_transform.basis_xform(
		_segments[joint.z][1] - _segments[joint.z][0]).normalized()
	var minimum_alignment := cos(deg_to_rad(closed_joint_angle_degrees))
	return absf(first.dot(second)) >= minimum_alignment


func _set_edge(copy: LightOccluder2D, start: Vector2, end: Vector2,
		thickness: float = 0.0) -> void:
	var edge := PackedVector2Array([start, end])
	var closed := thickness > 0.0
	if closed:
		var normal := start.direction_to(end).orthogonal() * thickness * 0.5
		edge = PackedVector2Array([start + normal, end + normal,
			end - normal, start - normal])
	# Avoid dirtying unchanged shadow geometry. No per-frame nodes or miters.
	if copy.occluder.closed != closed:
		copy.occluder.closed = closed
	if copy.occluder.polygon != edge:
		copy.occluder.polygon = edge
