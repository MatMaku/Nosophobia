extends Node
## Level-local registry. Discovery runs once; additions/removals are event-driven.

signal door_added(door: Node2D)
signal piece_registered(node: Node)

const WorldItem = preload("res://scripts/items/world_item.gd")
const Door = preload("res://scripts/world/door_2d.gd")
const Light = preload("res://scripts/world/decorative_light_2d.gd")
const PatrolEnemy = preload("res://scripts/enemies/patrol_enemy.gd")

var level: Node
var player: RigidBody2D
var doors: Array[Node2D] = []
var items: Array[WorldItem] = []
var blockers: Array[VisionBlocker2D] = []
var lights: Array[PointLight2D] = []
var visibility_test: Callable
var _pickup: Node


func bind_level(root: Node, actor: RigidBody2D, test: Callable) -> void:
	level = root
	player = actor
	visibility_test = test
	_pickup = player.get_node("PickupInteractor")
	_register_tree(level)
	get_tree().node_added.connect(_on_node_added)


func _register_tree(node: Node) -> void:
	register_piece(node)
	for child in node.get_children():
		_register_tree(child)


func _on_node_added(node: Node) -> void:
	register_piece.call_deferred(node)


func register_piece(node: Node) -> void:
	if not is_instance_valid(node) or not level.is_ancestor_of(node):
		return
	piece_registered.emit(node)
	if node is WorldItem and not items.has(node):
		items.append(node)
		node.visibility_test = visibility_test
		if not node.pickup_requested.is_connected(_pickup.request_pickup):
			node.pickup_requested.connect(_pickup.request_pickup)
		node.tree_exiting.connect(func(): items.erase(node), CONNECT_ONE_SHOT)
	elif node is PatrolEnemy:
		node.bind_player(player)
	elif node is Door and not doors.has(node):
		doors.append(node)
		door_added.emit(node)
		node.tree_exiting.connect(func(): doors.erase(node), CONNECT_ONE_SHOT)
	elif node is VisionBlocker2D and not blockers.has(node):
		blockers.append(node)
		node.tree_exiting.connect(func(): blockers.erase(node), CONNECT_ONE_SHOT)
	elif node is Light:
		var light := node.get_node("PointLight2D") as PointLight2D
		if not lights.has(light):
			lights.append(light)
			node.tree_exiting.connect(func(): lights.erase(light), CONNECT_ONE_SHOT)
