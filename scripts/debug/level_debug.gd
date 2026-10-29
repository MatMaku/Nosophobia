extends Node
## Session-owned adapters. Discovery is event-driven through LevelConnections, never per frame.
const DecorativeLight = preload("res://scripts/world/decorative_light_2d.gd")

var settings := DebugSettings.new()
var _player: RigidBody2D
var _fog: Node2D
var _darkness: CanvasLayer
var _visuals: Array[Node] = []
var _enemies: Array[Node] = []
var _ambient: Dictionary = {}
var _lights: Dictionary = {}


func bind(player: RigidBody2D, fog: Node2D, darkness: CanvasLayer, registry: Node) -> void:
	_player = player
	_fog = fog
	_darkness = darkness
	registry.piece_registered.connect(_register_piece)
	settings.changed.connect(_apply)
	_apply()


func _register_piece(node: Node) -> void:
	if node.has_method("set_debug_visuals_enabled") and not _visuals.has(node):
		_visuals.append(node)
		node.set_debug_visuals_enabled(settings.show_debug_visuals)
		node.tree_exiting.connect(func(): _visuals.erase(node), CONNECT_ONE_SHOT)
	if node.has_method("set_detection_enabled") and not _enemies.has(node):
		_enemies.append(node)
		node.set_detection_enabled(settings.enemy_detection_enabled)
		node.tree_exiting.connect(func(): _enemies.erase(node), CONNECT_ONE_SHOT)
	if node is CanvasModulate and not _ambient.has(node):
		_ambient[node] = node.color
		node.color = _ambient[node] if settings.darkness_enabled else Color.WHITE
		node.tree_exiting.connect(func(): _ambient.erase(node), CONNECT_ONE_SHOT)
	if node is PointLight2D and node.get_parent() is DecorativeLight and not _lights.has(node):
		_lights[node] = node.enabled
		node.enabled = _lights[node] and settings.darkness_enabled
		node.tree_exiting.connect(func(): _lights.erase(node), CONNECT_ONE_SHOT)


func _apply() -> void:
	_player.god_mode = settings.god_mode
	_player.set_noclip(settings.noclip)
	_fog.set_presentation_enabled(settings.fog_enabled)
	_darkness.visible = settings.darkness_enabled
	for node in _visuals:
		node.set_debug_visuals_enabled(settings.show_debug_visuals)
	for enemy in _enemies:
		enemy.set_detection_enabled(settings.enemy_detection_enabled)
	for ambient in _ambient:
		ambient.color = _ambient[ambient] if settings.darkness_enabled else Color.WHITE
	for light in _lights:
		light.enabled = _lights[light] and settings.darkness_enabled
