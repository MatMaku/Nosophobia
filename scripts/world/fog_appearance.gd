extends Node
## Environment-only presentation choice; never changes collision or vision blockers.

const UNFILTERED_Z: int = 100 # After environment fog (99), before Player visual (101).

@export var visuals: Array[CanvasItem] = []
@export var affected_by_fog: bool = true:
	set(value):
		affected_by_fog = value
		if is_node_ready():
			_apply()

var _original_order: Array[Vector2i] = []


func _ready() -> void:
	for visual in visuals:
		if not is_instance_valid(visual):
			_original_order.append(Vector2i.ZERO)
			push_warning("FogAppearance has an unassigned visual.")
			continue
		_original_order.append(Vector2i(visual.z_index, int(visual.z_as_relative)))
	_apply()


func _apply() -> void:
	for index in visuals.size():
		var visual := visuals[index]
		if not is_instance_valid(visual):
			continue
		visual.z_index = _original_order[index].x if affected_by_fog else UNFILTERED_Z
		visual.z_as_relative = bool(_original_order[index].y) if affected_by_fog else false
