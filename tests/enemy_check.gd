extends SceneTree
## Focused integration against the actual saved playground and physics/navigation server.

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	print("PASS: " if value else "FAIL: ", label)
	if not value:
		failures += 1


func ticks(count: int) -> void:
	for index in count:
		await physics_frame


func _run() -> void:
	var level = load("res://scenes/world/movement_test.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player = level.get_node("Player")
	player.freeze = true
	var enemy = level.get_node("PatrolEnemy")
	var behavior = enemy.get_node("Behavior")
	var movement = enemy.get_node("Movement")
	var perception = enemy.get_node("Perception")
	var noise = player.get_node("PlayerNoiseEmitter")
	await ticks(8)
	check(perception.target == player, "LevelSession injects Player into enemy")
	check(perception.noise_source == noise, "noise dependency is explicit")
	check(noise.radius_for_speed(19.0) == 0.0, "slow movement is silent")
	check(is_equal_approx(noise.radius_for_speed(70.0), 110.0), "noise interpolates")
	check(noise.radius_for_speed(500.0) == 220.0, "noise radius saturates")
	player.rotation = 0.0
	player.linear_velocity = Vector2(120, 0)
	check(noise.get_noise_radius() == 0.0, "lateral movement is not wheel rolling")
	player.linear_velocity = Vector2(0, -120)
	check(noise.get_noise_radius() == 220.0, "longitudinal velocity generates noise")
	player.linear_velocity = Vector2.ZERO
	var nav = level.get_node("LevelNavigation2D")
	print("Navigation bake ms: ", nav.bake_milliseconds)
	check(nav.navigation_polygon.get_polygon_count() > 0, "navigation baked")
	var map: RID = enemy.get_world_2d().navigation_map
	var path := NavigationServer2D.map_get_path(map, Vector2(180, 275), Vector2(180, 175), true)
	check(path.size() >= 3, "path detours around wall between patrol points")
	var ray := PhysicsRayQueryParameters2D.new()
	ray.collision_mask = 16
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	var clear := true
	for index in path.size() - 1:
		ray.from = path[index]
		ray.to = path[index + 1]
		clear = clear and enemy.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
	check(clear, "navigation segments do not cross full wall geometry")
	perception.target = null
	var visited := {}
	for frame in 1600:
		visited[behavior.waypoint_index] = true
		await physics_frame
	check(visited.size() == 3, "real movement visits all three patrol waypoints")
	print("Patrol visited: ", visited.keys(), " position: ", enemy.global_position,
		" path: ", enemy.get_node("NavigationAgent2D").get_current_navigation_path())
	behavior.patrol_mode = 1
	await ticks(90)
	var stationary: Vector2 = enemy.global_position
	await ticks(90)
	check(enemy.global_position.distance_to(stationary) < 0.1, "stationary patrol stops")
	movement.set_physics_process(false)
	behavior.set_physics_process(false)
	perception.target = player
	enemy.global_position = Vector2(180, 275)
	player.global_position = Vector2(180, 175)
	await ticks(2)
	perception.sample(Vector2.UP)
	check(not perception.saw_player, "wall blocks AI sight")
	player.global_position = Vector2(180, 320)
	await ticks(2)
	perception.sample(Vector2.UP)
	check(not perception.saw_player, "outside cone is not seen")
	perception.sample(Vector2.DOWN)
	check(perception.saw_player, "clear cone detects Player")
	player.global_position = Vector2(180, 650)
	await ticks(2)
	perception.sample(Vector2.DOWN)
	check(not perception.saw_player, "beyond sight distance is not seen")
	enemy.global_position = Vector2(504, 430)
	player.global_position = Vector2(504, 330)
	await ticks(2)
	perception.sample(Vector2.UP)
	check(perception.saw_player, "window does not block AI sight")
	enemy.global_position = Vector2(310, 430)
	player.global_position = Vector2(310, 330)
	await ticks(2)
	perception.sample(Vector2.UP)
	check(not perception.saw_player, "closed door blocks AI sight")
	var door = level.get_node("Environment/Doors/Door")
	door.body.rotation = PI * 0.5
	door.body.position = Vector2(0, 48)
	await ticks(2)
	perception.sample(Vector2.UP)
	check(perception.saw_player, "rotating door blocker opens real sight gap")
	player.global_position = Vector2(310, 500)
	await ticks(2)
	player.linear_velocity = Vector2.ZERO
	perception.sample(Vector2.UP)
	check(not perception.heard_player, "quiet Player behind enemy is not heard")
	player.linear_velocity = Vector2(0, -120)
	perception.sample(Vector2.UP)
	check(perception.heard_player and not perception.saw_player, "hearing detects outside cone")
	behavior._physics_process(0.016)
	check(behavior.state == 1, "hearing starts CHASE in stationary mode")
	player.linear_velocity = Vector2.ZERO
	var known: Vector2 = behavior.last_known_position
	player.global_position = Vector2(1050, 620)
	await ticks(2)
	behavior._physics_process(0.5)
	check(behavior.state == 1 and behavior.last_known_position == known,
		"lost target retains last known position, not hidden live position")
	behavior._physics_process(4.0)
	check(behavior.state == 0, "memory expires back to PATROL")
	var window = level.get_node("Environment/Windows/WindowShootingTest")
	window.take_damage(1000)
	check(enemy.collision_mask & 4 != 0 and window.collision_layer & 4 != 0,
		"broken window remains a physical enemy barrier")
	var closest := NavigationServer2D.map_get_closest_point(map, window.global_position)
	check(closest.distance_to(window.global_position) >= 30.0, "window volume excluded from navigation")
	# Real movement against a closed then open physical leaf (no door AI).
	door.body.rotation = 0.0
	door.body.position = Vector2(48, 0)
	enemy.global_position = Vector2(310, 440)
	enemy.velocity = Vector2.ZERO
	movement.set_physics_process(true)
	movement.set_destination(Vector2(310, 330), 55.0)
	await ticks(180)
	check(enemy.global_position.y >= 405.0, "closed physical door stops movement")
	door.body.rotation = PI * 0.5
	door.body.position = Vector2(0, 48)
	await ticks(240)
	check(enemy.global_position.y < 350.0, "open door permits movement through gap")
	# Hearing acquires a target across a wall, then the SAME agent pursues around it.
	enemy.global_position = Vector2(180, 275)
	enemy.velocity = Vector2.ZERO
	player.global_position = Vector2(360, 175)
	await ticks(2)
	player.linear_velocity = Vector2(0, -120)
	behavior._physics_process(0.016)
	check(behavior.state == 1, "hearing through wall acquires chase destination")
	behavior.set_physics_process(true)
	# Keep the target audible for this pathfinding test. A single sound now expires
	# before the slower, deliberately easier-to-escape enemy can round the wall.
	for frame in 600:
		player.linear_velocity = Vector2(0, -120)
		await physics_frame
	player.linear_velocity = Vector2.ZERO
	check(enemy.global_position.distance_to(player.global_position) < 60.0,
		"actual CHASE routes around the wall and stops near Player")
	level.queue_free()
	await process_frame
	print("ENEMY RESULT: ", failures, " failures")
	quit(failures)
