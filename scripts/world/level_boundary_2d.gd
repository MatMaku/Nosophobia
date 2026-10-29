@tool
extends Line2D
## Native Line2D points are the only authored geometry. Children are derived outputs.
## Points is the wall axis; Width extends equally to both sides. Closed joins last to first.
## For a doorway use two open paths separated by the opening. Keep Scale at (1, 1).

@export_group("Collision")
@export var collision_enabled: bool = true:
	set(value):
		collision_enabled = value
		_sync_enabled()
@export_group("Occlusion")
## Only decorative-light shadows; independent of body collision and player LOS.
@export var occlusion_enabled: bool = true:
	set(value):
		occlusion_enabled = value
		_sync_enabled()
## Player LOS only; does not change collision or decorative-light shadows.
@export var blocks_vision: bool = true:
	set(value):
		blocks_vision = value
		_sync_enabled()
## Whether unseen wall pixels receive the grey environment filter.
@export var affected_by_fog: bool = true:
	set(value):
		affected_by_fog = value
		if is_node_ready():
			$FogAppearance.affected_by_fog = value

@onready var _collision: CollisionShape2D = $Collision/Polygon
@onready var _occluder: LightOccluder2D = $LightOccluder
@onready var _vision_blocker: VisionBlocker2D = $VisionBlocker

var _last_points := PackedVector2Array()
var _last_closed: bool = false
var _last_width: float = -1.0


func _ready() -> void:
	# Never modify another instance's shared resource (including editor duplicates).
	_occluder.occluder = OccluderPolygon2D.new()
	_collision.shape = ConcavePolygonShape2D.new()
	$FogAppearance.affected_by_fog = affected_by_fog
	_sync_geometry(true)


func _draw() -> void:
	# Native point edits request a redraw. No editor polling or gameplay processing.
	if Engine.is_editor_hint() and is_node_ready():
		_sync_geometry()


func _sync_geometry(force: bool = false) -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("wall_width", width)
	if force or points != _last_points or closed != _last_closed or width != _last_width:
		_last_points = points
		_last_closed = closed
		_last_width = width
		var contours: Array[PackedVector2Array] = []
		if points.size() >= (3 if closed else 2) and width > 0.0:
			contours = Geometry2D.offset_polyline(points, width * 0.5,
				Geometry2D.JOIN_MITER,
				Geometry2D.END_JOINED if closed else Geometry2D.END_BUTT)
		# One wall outline: bodies/hitscan and LOS meet the same visible surface.
		var segments := PackedVector2Array()
		for contour in contours:
			for index in contour.size():
				segments.append(contour[index])
				segments.append(contour[(index + 1) % contour.size()])
		_collision.shape.segments = segments
		$AISightBlocker/Shape.shape = _collision.shape
		_vision_blocker.set_contours(contours)
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
	$AISightBlocker/Shape.disabled = not collision_enabled or not valid
	_occluder.visible = occlusion_enabled and valid
	_vision_blocker.collision_layer = VisionBlocker2D.LAYER if blocks_vision and valid else 0


func _get_configuration_warnings() -> PackedStringArray:
	if points.size() < (3 if closed else 2):
		return ["Use three points for a closed boundary, or two for an open wall."]
	if not scale.is_equal_approx(Vector2.ONE):
		return ["Keep Scale at (1, 1). Edit Points and Width for consistent wall thickness."]
	if width_curve != null or joint_mode != LINE_JOINT_SHARP \
			or begin_cap_mode != LINE_CAP_NONE or end_cap_mode != LINE_CAP_NONE \
			or not is_equal_approx(sharp_limit, 2.0):
		return ["Vision volume supports uniform Width, Sharp joints (limit 2) and None caps."]
	return []
