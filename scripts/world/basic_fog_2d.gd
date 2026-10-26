extends Node2D
## Current LOS controls entity disclosure and desaturates the known environment.

const CORNER_EPSILON: float = 0.00001

@export_range(64, 1024, 1) var ray_count: int = 256
@export var show_rays: bool = false:
	set(value):
		show_rays = value
		queue_redraw()
@export_range(64.0, 2000.0, 16.0) var vision_radius: float = 650.0
@export_range(0.1, 1.0, 0.05) var unseen_brightness: float = 0.45

@onready var _shadow: MeshInstance2D = $Shadow
@onready var _visibility_mask: Node = $VisibilityMask
var _viewer: Node2D
var _blockers: Array[VisionBlocker2D] = []
var _query := PhysicsRayQueryParameters2D.new()
var _segments := PackedVector2Array()
var _corners := PackedVector2Array()
var _hits := PackedVector2Array()
var last_update_usec: int = 0


func _ready() -> void:
	process_physics_priority = 100
	_query.collision_mask = VisionBlocker2D.LAYER
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	set_physics_process(false)


func bind_viewer(viewer: Node2D, blockers: Array[VisionBlocker2D]) -> void:
	_viewer = viewer
	_blockers = blockers
	set_physics_process(true)


func is_position_visible(point: Vector2) -> bool:
	return _hits.size() >= 3 and Geometry2D.is_point_in_polygon(point, _hits)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_viewer):
		return
	var started := Time.get_ticks_usec()
	var origin := _viewer.global_position
	# The exterior mesh must cover the camera even when sight radius is smaller.
	var inverse := get_viewport().canvas_transform.affine_inverse()
	var size := get_viewport_rect().size
	var radius := 1.0
	for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		radius = maxf(radius, origin.distance_to(inverse * corner))
	radius *= 2.0
	var segments := PackedVector2Array()
	var inside := false
	for blocker in _blockers:
		if not is_instance_valid(blocker) or not blocker.is_inside_tree():
			continue
		if not (blocker.collision_layer & VisionBlocker2D.LAYER):
			continue
		var edges := blocker.get_world_endpoints()
		if edges.is_empty():
			continue
		segments.append_array(edges)
		inside = inside or blocker.contains_world_point(origin)
	if segments != _segments:
		_cache_corners(segments)
	var angles: Array[float] = []
	for index in ray_count:
		angles.append(TAU * index / ray_count)
	for corner in _corners:
		if origin.distance_squared_to(corner) > vision_radius * vision_radius:
			continue
		var angle := (corner - origin).angle()
		# Sample each side, not the numerically ambiguous exact tangent to a vertex.
		for offset in [-CORNER_EPSILON, CORNER_EPSILON]:
			angles.append(fposmod(angle + offset, TAU))
	angles.sort()
	_hits.clear()
	var ends := PackedVector2Array()
	_query.from = origin
	var previous := -1.0
	var space := get_world_2d().direct_space_state
	for angle in angles:
		if angle - previous < 0.0000001:
			continue
		previous = angle
		var direction := Vector2.from_angle(angle)
		_query.to = origin + direction * vision_radius
		var hit := space.intersect_ray(_query) if not inside else {}
		_hits.append(origin if inside else hit.get("position", _query.to))
		ends.append(origin + direction * maxf(radius, vision_radius))
	_build_shadow(ends)
	_shadow.material.set_shader_parameter("unseen_brightness", unseen_brightness)
	_visibility_mask.update_mesh()
	if show_rays:
		queue_redraw()
	last_update_usec = Time.get_ticks_usec() - started


func _cache_corners(segments: PackedVector2Array) -> void:
	_segments = segments
	_corners = segments.duplicate()
	# Intersecting solids also create silhouette corners; no geometry is altered.
	for first in range(0, segments.size(), 2):
		var a := segments[first]
		var b := segments[first + 1]
		var bounds := Rect2(a, b - a).abs()
		for second in range(first + 2, segments.size(), 2):
			var c := segments[second]
			var d := segments[second + 1]
			if not bounds.intersects(Rect2(c, d - c).abs(), true):
				continue
			var crossing: Variant = Geometry2D.segment_intersects_segment(a, b, c, d)
			if crossing != null:
				_corners.append(crossing)


func _build_shadow(ends: PackedVector2Array) -> void:
	var vertices := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(_hits.size() * 2)
	indices.resize(_hits.size() * 6)
	for index in _hits.size():
		vertices[index * 2] = to_local(_hits[index])
		vertices[index * 2 + 1] = to_local(ends[index])
	for index in _hits.size():
		var a := index * 2
		var b := ((index + 1) % _hits.size()) * 2
		var offset := index * 6
		indices[offset] = a
		indices[offset + 1] = a + 1
		indices[offset + 2] = b + 1
		indices[offset + 3] = a
		indices[offset + 4] = b + 1
		indices[offset + 5] = b
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_shadow.mesh = mesh


func _draw() -> void:
	if show_rays and is_instance_valid(_viewer):
		for hit in _hits:
			draw_line(to_local(_viewer.global_position), to_local(hit), Color.CYAN)
