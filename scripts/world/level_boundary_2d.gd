@tool
extends Line2D
## Native Line2D points are the only authored geometry. Children are derived outputs.

@export_group("Collision")
@export var collision_enabled: bool = true:
	set(value):
		collision_enabled = value
		_sync_enabled()
@export_group("Occlusion")
@export var occlusion_enabled: bool = true:
	set(value):
		occlusion_enabled = value
		_sync_enabled()

@onready var _collision: CollisionShape2D = $Collision/Polygon
@onready var _occluder: LightOccluder2D = $LightOccluder

var _last_points := PackedVector2Array()
var _last_closed: bool = false


func _ready() -> void:
	# Never modify another instance's shared resource (including editor duplicates).
	_occluder.occluder = OccluderPolygon2D.new()
	_collision.shape = ConcavePolygonShape2D.new()
	_sync_geometry(true)


func _draw() -> void:
	# Native point edits request a redraw. No editor polling or gameplay processing.
	if Engine.is_editor_hint() and is_node_ready():
		_sync_geometry()


func _sync_geometry(force: bool = false) -> void:
	_occluder.set_meta("vision_occlusion_width", width)
	if force or points != _last_points or closed != _last_closed:
		_last_points = points
		_last_closed = closed
		var segments := PackedVector2Array()
		if points.size() >= (3 if closed else 2):
			for index in points.size() - 1:
				segments.append(points[index])
				segments.append(points[index + 1])
			if closed:
				segments.append(points[-1])
				segments.append(points[0])
		_collision.shape.segments = segments
		_occluder.occluder.polygon = points
		_occluder.occluder.closed = closed
		_occluder.occluder.cull_mode = OccluderPolygon2D.CULL_DISABLED
		update_configuration_warnings()
	_sync_enabled()


func _sync_enabled() -> void:
	if not is_node_ready():
		return
	var valid := points.size() >= (3 if closed else 2)
	_collision.disabled = not collision_enabled or not valid
	_occluder.visible = occlusion_enabled and valid


func _get_configuration_warnings() -> PackedStringArray:
	if points.size() < (3 if closed else 2):
		return ["Use three points for a closed boundary, or two for an open wall."]
	return []
