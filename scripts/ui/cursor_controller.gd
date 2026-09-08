extends Node
## Semantic presentation only; weak owners prevent abandoned contexts.

enum State { DEFAULT, INTERACTABLE, GRABBING, AIMING }

@export_group("Default")
@export var default_texture: Texture2D
@export var default_hotspot := Vector2(6, 4)
@export_group("Interactable")
@export var interactable_texture: Texture2D
@export var interactable_hotspot := Vector2(16, 16)
@export_group("Grabbing")
@export var grabbing_texture: Texture2D
@export var grabbing_hotspot := Vector2(16, 16)
@export_group("Aiming")
@export var aiming_texture: Texture2D
@export var aiming_hotspot := Vector2(12, 12)

var current_state: State = State.DEFAULT
var _contexts: Dictionary = {}
var _applied_state: int = -1


func set_context(owner: Node, available: bool, active: bool, aiming: bool = false) -> void:
	_contexts[owner.get_instance_id()] = [weakref(owner), available, active, aiming]


func _process(_delta: float) -> void:
	var next := State.DEFAULT
	for key in _contexts.keys():
		var context: Array = _contexts[key]
		var owner = context[0].get_ref()
		if not is_instance_valid(owner) or not owner.is_inside_tree():
			_contexts.erase(key)
			continue
		if context[2]:
			next = State.GRABBING
		elif context[3] and next != State.GRABBING:
			next = State.AIMING
		elif context[1] and next == State.DEFAULT:
			next = State.INTERACTABLE
	current_state = next
	if _applied_state == next:
		return
	_applied_state = next
	var textures := [default_texture, interactable_texture, grabbing_texture, aiming_texture]
	var hotspots := [default_hotspot, interactable_hotspot, grabbing_hotspot, aiming_hotspot]
	# Native GUI drag uses CAN_DROP/FORBIDDEN shapes: preserve the semantic hand.
	for shape in range(Input.CURSOR_ARROW, Input.CURSOR_HELP + 1):
		Input.set_custom_mouse_cursor(textures[next], shape, hotspots[next])


func _exit_tree() -> void:
	for shape in range(Input.CURSOR_ARROW, Input.CURSOR_HELP + 1):
		Input.set_custom_mouse_cursor(null, shape)
