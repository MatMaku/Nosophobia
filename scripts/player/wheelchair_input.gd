extends Node2D
## Tracks mouse motion in chair-local coordinates; owns no physics rules.

const WORLD_ITEM_COLLISION_MASK: int = 1 << 1

@export_range(1.0, 500.0, 1.0) var interaction_radius: float = 110.0

@onready var _pickup_interactor = $"../PickupInteractor"

var drag_active: bool = false
var input_enabled: bool = true
var mouse_local_position: Vector2 = Vector2.ZERO
## Not clamped: values outside the ring remain useful while dragging.
var mouse_normalized_position: Vector2 = Vector2.ZERO
var drag_start_global_position: Vector2 = Vector2.ZERO
## Motion consumed during the latest physics tick, in world and chair-local units.
var mouse_displacement: Vector2 = Vector2.ZERO
var local_mouse_displacement: Vector2 = Vector2.ZERO

var _pending_world_motion: Vector2 = Vector2.ZERO
var _pending_local_motion: Vector2 = Vector2.ZERO


func _ready() -> void:
	get_window().focus_exited.connect(_end_drag)


func _input(event: InputEvent) -> void:
	# Observe release even when a UI control will consume it.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag()
	elif event is InputEventMouseMotion and drag_active:
		# Leaving the ring cancels even if UI consumes the motion afterwards.
		if make_input_local(event).position.length() > interaction_radius:
			_end_drag()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	_update_mouse_position()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Physics picking runs after unhandled input. Leave item clicks unconsumed.
			var query := PhysicsPointQueryParameters2D.new()
			query.position = get_canvas_transform().affine_inverse() * event.position
			query.collision_mask = WORLD_ITEM_COLLISION_MASK
			query.collide_with_areas = true
			query.collide_with_bodies = false
			var hits := get_world_2d().direct_space_state.intersect_point(query, 1)
			for hit in hits:
				if _pickup_interactor.can_pickup(hit.collider):
					return
			# Test the position at press time, even if several events arrived together.
			mouse_local_position = make_input_local(event).position
			mouse_normalized_position = mouse_local_position / maxf(interaction_radius, 1.0)
			if mouse_local_position.length() <= interaction_radius:
				drag_active = true
				drag_start_global_position = to_global(mouse_local_position)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and drag_active:
		if make_input_local(event).position.length() > interaction_radius:
			_end_drag()
			return
		# Use vectors, not positions: moving/rotating the chair cannot invent a gesture.
		var world_motion := get_canvas_transform().affine_inverse().basis_xform(event.relative)
		_pending_world_motion += world_motion
		_pending_local_motion += global_transform.affine_inverse().basis_xform(world_motion)
		get_viewport().set_input_as_handled()


func consume_motion() -> Vector2:
	_update_mouse_position()
	# Also covers a changed radius or a moving interaction area between events.
	if drag_active and mouse_local_position.length() > interaction_radius:
		_end_drag()
	mouse_displacement = _pending_world_motion
	local_mouse_displacement = _pending_local_motion
	_pending_world_motion = Vector2.ZERO
	_pending_local_motion = Vector2.ZERO
	return local_mouse_displacement


func _update_mouse_position() -> void:
	mouse_local_position = get_local_mouse_position()
	mouse_normalized_position = mouse_local_position / maxf(interaction_radius, 1.0)


func _end_drag() -> void:
	drag_active = false
	_pending_world_motion = Vector2.ZERO
	_pending_local_motion = Vector2.ZERO
	mouse_displacement = Vector2.ZERO
	local_mouse_displacement = Vector2.ZERO


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		_end_drag()
