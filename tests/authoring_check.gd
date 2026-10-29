extends SceneTree
## Run with --headless --path . --script res://tests/authoring_check.gd

const Stack = preload("res://scripts/inventory/item_stack.gd")
const Inventory = preload("res://scripts/inventory/inventory.gd")
var failures := 0
var loaded := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	print("PASS: " if value else "FAIL: ", label)
	if not value:
		failures += 1


func piece(path: String) -> Node:
	return load("res://scenes/prefabs/" + path + ".tscn").instantiate()


func load_all(folder: String) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in ["tscn", "tres"]:
			check(load(folder.path_join(file)) != null, "load " + file)
			loaded += 1
	for sub in DirAccess.get_directories_at(folder):
		load_all(folder.path_join(sub))


func _run() -> void:
	load_all("res://scenes")
	load_all("res://resources")
	var level := Node2D.new()
	root.add_child(level)
	current_scene = level
	var nested := Node2D.new()
	level.add_child(nested)
	var player = piece("actors/player")
	player.name = "ArbitrarySpawnName"
	nested.add_child(player)
	player.freeze = true
	var key = piece("items/key_item")
	var other_key = piece("items/key_item")
	key.key_id = &"basement"
	key.display_name = "Basement key"
	nested.add_child(key)
	nested.add_child(other_key)
	check(other_key.key_id == &"test_room", "key edit isolates other definition")
	check(key.definition.key_id == &"basement", "key proxy has one source")
	var saved := PackedScene.new()
	check(saved.pack(key) == OK, "pack key")
	var restored = saved.instantiate()
	check(restored.key_id == &"basement" and restored.display_name == "Basement key",
		"key proxy persists only through definition")
	restored.free()
	var ammo = piece("items/ammo_item")
	var ammo2 = piece("items/ammo_item")
	nested.add_child(ammo)
	nested.add_child(ammo2)
	check(ammo.definition == ammo2.definition, "ammo identity shared")
	var inventory := Inventory.new(4)
	inventory.try_add(ammo.definition, 20)
	inventory.try_add(ammo2.definition, 15)
	check(inventory.get_item(0).quantity == 30 and inventory.get_item(1).quantity == 5,
		"canonical ammo merges with overflow")
	var weapon = piece("items/weapon_item")
	nested.add_child(weapon)
	var stack := Stack.new(weapon.definition, 1)
	check(stack.firearm_state.definition.compatible_ammo == ammo.definition, "reload identity")
	var weapon2 := Stack.new(weapon.definition, 1)
	check(stack.firearm_state != weapon2.firearm_state, "weapon runtime state isolated")
	var shape = ammo.get_node("CollisionShape2D").shape
	ammo.world_visual_scale = 0.9
	check(ammo.get_node("Sprite2D").scale == Vector2(0.9, 0.9)
		and shape.radius == 20.0, "visual scale does not change click shape")
	var door = piece("environment/door_2d")
	door.key_id = &"basement"
	door.position = Vector2(200, 200)
	nested.add_child(door)
	var door2 = piece("environment/door_2d")
	door2.position = Vector2(400, 200)
	nested.add_child(door2)
	door.leaf_size = Vector2(120, 16)
	check(door.get_node("DoorBody/Visual").size == Vector2(120, 16)
		and door.get_node("DoorBody/CollisionShape2D").shape.size == Vector2(109, 16),
		"door size synchronizes visual and collision tolerance")
	check(door2.get_node("DoorBody/CollisionShape2D").shape.size == Vector2(85, 12),
		"door shape isolated")
	check(door.accepts_key(key.key_id) and not door.accepts_key(other_key.key_id), "door key matching")
	var window = piece("environment/window_2d")
	nested.add_child(window)
	window.pane_size = Vector2(160, 24)
	check(window.get_node("CollisionShape2D").shape.size == Vector2(160, 24), "window resize")
	window.take_damage_from_hit(40.0, Vector2.RIGHT)
	check(window.state == 1, "window cracked")
	window.take_damage_from_hit(40.0, Vector2.RIGHT)
	check(window.state == 2 and window.collision_layer == 4
		and window.get_node("Shards").visible, "broken window retains body barrier only")
	var wall = piece("environment/level_boundary_2d")
	wall.position = Vector2(800, 800)
	nested.add_child(wall)
	wall.points = PackedVector2Array([Vector2.ZERO, Vector2(100, 0), Vector2(100, 100)])
	wall.closed = false
	wall.width = 24
	wall._sync_geometry(true)
	check(wall.get_node("Collision/Polygon").shape.segments ==
		wall.get_node("VisionBlocker/Segments").shape.segments, "wall collision and LOS same contour")
	var lamp = piece("effects/decorative_light_2d")
	lamp.light_radius = 100.0
	nested.add_child(lamp)
	check(lamp.get_node("PointLight2D").texture != null and
		is_equal_approx(lamp.get_node("PointLight2D").texture_scale, 1.5625), "light radius and texture")
	var enemy = piece("actors/enemies/enemy_base")
	enemy.max_health = 50.0
	nested.add_child(enemy)
	enemy.take_damage(25.0)
	check(enemy.health.current_health == 25.0, "enemy root health")
	enemy.take_damage(25.0)
	check(enemy.is_queued_for_deletion(), "enemy death")
	for i in 5:
		await physics_frame
		await process_frame
	var space := level.get_world_2d().direct_space_state
	for mask in [1, 8]:
		var ray := PhysicsRayQueryParameters2D.create(Vector2(850, 750), Vector2(850, 850), mask)
		ray.collide_with_areas = mask == 8
		ray.collide_with_bodies = mask == 1
		var hit := space.intersect_ray(ray)
		check(not hit.is_empty() and is_equal_approx(hit.position.y, 788.0),
			"wall near surface blocks physical/hitscan and vision mask " + str(mask))
		var door_ray := PhysicsRayQueryParameters2D.create(Vector2(260, 160), Vector2(260, 240), mask)
		door_ray.collide_with_areas = mask == 8
		door_ray.collide_with_bodies = mask == 1
		var door_hit := space.intersect_ray(door_ray)
		check(not door_hit.is_empty() and is_equal_approx(door_hit.position.y, 192.0),
			"resized door blocks mask " + str(mask))
	check(wall.get_node("LightOccluder").occluder_light_mask == 2 and
		door.get_node("DoorBody/LightOccluder").occluder_light_mask == 2,
		"decorative shadow masks preserved")
	var session = player.get_node("LevelSession")
	var registry = session.get_node("LevelConnections")
	check(registry.items.has(ammo) and registry.doors.size() == 2, "nested auto integration")
	check(ammo.pickup_requested.get_connections().size() == 1, "pickup connected once")
	check(session.get_node("CameraDarkness").lights.has(lamp.get_node("PointLight2D")),
		"light registered without arrays")
	var late_lamp = piece("effects/decorative_light_2d")
	nested.add_child(late_lamp)
	await process_frame
	await process_frame
	check(registry.lights.size() == 2, "runtime light registered")
	var dropped = session.get_node("WorldItemDrops").spawn_dropped_item(stack, Vector2(200, 0))
	check(dropped != null and dropped.get_item_stack() == stack and registry.items.has(dropped),
		"runtime drop keeps loaded state and registers immediately")
	key.position = player.position
	key.pickup_requested.emit(key)
	check(key.is_queued_for_deletion(), "nested key pickup signal works")
	check(door.unlock_with_key(&"basement"), "unlock matching door")
	door.open_after_unlock()
	for i in 30:
		await physics_frame
	check(not door.body.freeze, "door resumes physics after opening")
	level.queue_free()
	await process_frame
	print("RESULT: ", failures, " failures; ", loaded, " resources loaded")
	quit(failures)
