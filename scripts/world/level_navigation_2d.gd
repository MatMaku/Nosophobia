extends NavigationRegion2D
## One bake at level load. Outlines author the walkable envelope, not individual walls.
## Static wall/window obstructions are derived from their existing source geometry.

const Wall = preload("res://scripts/world/level_boundary_2d.gd")
const WindowPane = preload("res://scripts/world/window_2d.gd")

@export_range(1.0, 100.0, 1.0) var agent_clearance: float = 22.0
var bake_milliseconds: float = 0.0


func _ready() -> void:
	rebuild.call_deferred()


func rebuild() -> void:
	if navigation_polygon == null:
		push_warning("LevelNavigation2D needs a walkable outline drawn in the editor.")
		return
	var started := Time.get_ticks_usec()
	var source := NavigationMeshSourceGeometryData2D.new()
	for index in navigation_polygon.get_outline_count():
		source.add_traversable_outline(navigation_polygon.get_outline(index))
	_collect(get_tree().current_scene, source)
	var polygon := NavigationPolygon.new()
	polygon.agent_radius = agent_clearance
	for index in navigation_polygon.get_outline_count():
		polygon.add_outline(navigation_polygon.get_outline(index))
	NavigationServer2D.bake_from_source_geometry_data(polygon, source)
	navigation_polygon = polygon
	bake_milliseconds = (Time.get_ticks_usec() - started) / 1000.0


func _collect(node: Node, source: NavigationMeshSourceGeometryData2D) -> void:
	if node == null:
		return
	if node is Wall and node.collision_enabled:
		_add_wall(node, source)
	elif node is WindowPane:
		var half: Vector2 = node.pane_size * 0.5
		_add_outline(node, PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y)]), source)
	for child in node.get_children():
		_collect(child, source)


func _add_wall(wall: Line2D, source: NavigationMeshSourceGeometryData2D) -> void:
	# Short overlapping strokes preserve miter joints without treating the interior
	# of a closed boundary as a solid obstacle. The baker unions these polygons.
	var count := wall.points.size()
	if count < 2:
		return
	for index in count if wall.closed else count - 1:
		var path := PackedVector2Array([wall.points[index], wall.points[(index + 1) % count]])
		if wall.closed or index + 2 < count:
			path.append(wall.points[(index + 2) % count])
		for contour in Geometry2D.offset_polyline(path, wall.width * 0.5,
				Geometry2D.JOIN_MITER, Geometry2D.END_BUTT):
			_add_outline(wall, contour, source)


func _add_outline(node: Node2D, outline: PackedVector2Array,
		source: NavigationMeshSourceGeometryData2D) -> void:
	var transform := global_transform.affine_inverse() * node.global_transform
	source.add_obstruction_outline(transform * outline)
