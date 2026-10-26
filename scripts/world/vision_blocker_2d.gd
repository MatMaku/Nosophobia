@tool
class_name VisionBlocker2D
extends Area2D
## Full LOS boundary, separate from body collision and decorative light occlusion.

const LAYER: int = 1 << 3

@onready var _shape: CollisionShape2D = $Segments
var _contours: Array[PackedVector2Array] = []


func set_contours(contours: Array[PackedVector2Array]) -> void:
	if not is_node_ready():
		return
	_contours = contours
	var segments := PackedVector2Array()
	for contour in contours:
		for index in contour.size():
			segments.append(contour[index])
			segments.append(contour[(index + 1) % contour.size()])
	var geometry := ConcavePolygonShape2D.new()
	geometry.segments = segments
	_shape.shape = geometry


func get_world_endpoints() -> PackedVector2Array:
	var result := PackedVector2Array()
	if _shape.disabled or not (_shape.shape is ConcavePolygonShape2D):
		return result
	# Read the same transform as the physics query, including moving door leaves.
	var pose := PhysicsServer2D.area_get_transform(get_rid()) * _shape.transform
	for point in _shape.shape.segments:
		result.append(pose * point)
	return result


func contains_world_point(point: Vector2) -> bool:
	var local := PhysicsServer2D.area_get_transform(get_rid()).affine_inverse() * point
	var crossings := 0
	for contour in _contours:
		if Geometry2D.is_point_in_polygon(local, contour):
			crossings += 1
	return crossings % 2 == 1


