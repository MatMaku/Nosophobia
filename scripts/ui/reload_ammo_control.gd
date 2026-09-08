extends PanelContainer
## The same small view is either a loose one-round token or an indexed chamber.

@export var chamber_index: int = -1
@export var preview_scene: PackedScene
var reload_ui: Control

@onready var _icon: TextureRect = $Icon


func show_ammo(icon: Texture2D, loaded: bool) -> void:
	_icon.texture = icon if loaded else null


func _get_drag_data(_position: Vector2) -> Variant:
	if chamber_index >= 0 or reload_ui == null:
		return null
	var data: Dictionary = reload_ui.get_round_drag()
	if data.is_empty():
		return null
	var preview = preview_scene.instantiate()
	preview.get_node("Icon").texture = data.ammo.icon
	preview.get_node("Quantity").text = ""
	set_drag_preview(preview)
	return data


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return chamber_index >= 0 and reload_ui != null and reload_ui.can_load(chamber_index, data)


func _drop_data(_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_position, data):
		reload_ui.load_round(chamber_index, data)
