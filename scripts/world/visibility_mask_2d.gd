extends Node
## Rasterizes the exact LOS exterior for per-pixel entity clipping; no second LOS.

const SUBJECT_SHADER = preload("res://shaders/world/vision_subject.gdshader")

@export var shadow: MeshInstance2D
@onready var _mask: SubViewport = $Mask
@onready var _copy: MeshInstance2D = $Mask/ShadowCopy
var _material := ShaderMaterial.new()
var _mask_ready: bool = false


func _ready() -> void:
	_material.shader = SUBJECT_SHADER
	_material.set_shader_parameter("hidden_mask", _mask.get_texture())
	for subject in get_tree().get_nodes_in_group("vision_subject"):
		_register_subject(subject)
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.frame_pre_draw.connect(_sync_canvas)


func _on_node_added(node: Node) -> void:
	if node.is_in_group("vision_subject"):
		_register_subject.call_deferred(node)


func _register_subject(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_apply_material(node)


func _apply_material(node: Node) -> void:
	if node is CanvasItem:
		node.material = _material
	for child in node.get_children():
		_apply_material(child)


func update_mesh() -> void:
	_copy.mesh = shadow.mesh
	_copy.transform = shadow.global_transform
	if not _mask_ready:
		_mask_ready = true
		_material.set_shader_parameter("mask_ready", true)


func _sync_canvas() -> void:
	var viewport := get_viewport()
	var size := Vector2i(viewport.get_visible_rect().size).max(Vector2i(2, 2))
	if _mask.size != size:
		_mask.size = size
	if _mask.canvas_transform != viewport.canvas_transform:
		_mask.canvas_transform = viewport.canvas_transform


func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_sync_canvas)
