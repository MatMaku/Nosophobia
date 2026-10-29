extends SceneTree

var failures: int = 0
var deaths: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	print("PASS: " if value else "FAIL: ", label)
	if not value:
		failures += 1


func ticks(count: int = 3) -> void:
	for index in count:
		await physics_frame


func _run() -> void:
	var level = load("res://scenes/world/movement_test.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await ticks(8)
	var player = level.get_node("Player")
	var session = player.get_node("LevelSession")
	var settings = session.get_node("LevelDebug").settings
	var hud = session.get_node("HUD/PlayerHealthHUD")
	var menu = session.get_node("DebugMenu")
	var enemy = level.get_node("PatrolEnemy")
	var perception = enemy.get_node("Perception")
	var behavior = enemy.get_node("Behavior")
	var fog = session.get_node("BasicFog2D")
	var darkness = session.get_node("CameraDarkness")
	var lights: Array = session.get_node("LevelConnections").lights
	var original_light_states: Array[bool] = []
	for light in lights:
		original_light_states.append(light.enabled)
	check(not settings.show_debug_visuals and not settings.noclip and not settings.god_mode
		and settings.fog_enabled and settings.darkness_enabled and settings.enemy_detection_enabled,
		"session debug defaults")
	check(not player.get_node("Debug").visible and not enemy.get_node("HealthLabel").visible,
		"global OFF hides existing debug")
	settings.show_debug_visuals = true
	check(player.get_node("Debug").visible and perception.show_vision_debug,
		"global ON enables configured debug")
	enemy.show_hearing_debug = false
	settings.show_debug_visuals = false
	settings.show_debug_visuals = true
	check(not perception.show_hearing_debug, "local debug opt-out preserved")
	settings.show_debug_visuals = false
	check(not perception.show_vision_debug and not enemy.get_node("NavigationAgent2D").debug_enabled,
		"global OFF clears AI debug")
	check(hud.text == "Vida: 100 / 100", "initial health HUD")
	player.take_damage(25)
	check(player.health.current_health == 75 and hud.text == "Vida: 75 / 100", "damage updates HUD by signal")
	settings.god_mode = true
	player.take_damage(1000)
	check(player.health.current_health == 75, "god mode ignores damage without healing")
	settings.god_mode = false
	player.take_damage(50)
	check(hud.text == "Vida: 25 / 100", "health 25 updates synchronously")
	player.heal(200)
	check(player.health.current_health == 100, "healing clamps at maximum")
	player.max_health = 120
	check(hud.text == "Vida: 100 / 120", "maximum changes notify HUD")
	player.max_health = 100
	# Detection OFF immediately exits chase, then rejects both vision and noise.
	behavior.state = 1
	behavior.last_known_position = player.global_position
	settings.enemy_detection_enabled = false
	var late_enemy = load("res://scenes/prefabs/actors/enemies/patrol_enemy.tscn").instantiate()
	late_enemy.position = Vector2(1000, 100)
	level.add_child(late_enemy)
	await ticks()
	check(not late_enemy.get_node("Perception").detection_enabled
		and not late_enemy.get_node("HealthLabel").visible, "late enemy inherits session debug settings")
	late_enemy.queue_free()
	check(behavior.state == 0 and behavior.last_known_position == Vector2.ZERO,
		"detection OFF clears chase and memory immediately")
	player.linear_velocity = Vector2.UP.rotated(player.rotation) * 120
	perception.sample(enemy.global_position.direction_to(player.global_position))
	check(not perception.saw_player and not perception.heard_player, "detection OFF rejects both senses")
	var progress: int = behavior.waypoint_index
	await ticks(900)
	check(enemy.global_position.distance_to(Vector2(180, 275)) > 10.0
		or behavior.waypoint_index != progress, "AI still patrols while detection disabled")
	settings.enemy_detection_enabled = true
	check(perception.detection_enabled, "detection restored")
	settings.enemy_detection_enabled = false
	# Repeated presentation toggles preserve the live mask, geometry and AI state.
	var mask = fog.get_node("VisibilityMask/Mask")
	var texture = mask.get_texture()
	for index in 3:
		settings.fog_enabled = false
		settings.darkness_enabled = false
		check(not fog.get_node("Shadow").visible and not darkness.visible, "fog and darkness OFF")
		for light in lights:
			check(not light.enabled, "decorative lamp disabled in clear test view")
		check(not fog.get_node("VisibilityMask")._material.get_shader_parameter("mask_enabled"),
			"entities bypass clipping when fog disabled")
		await ticks()
		settings.fog_enabled = true
		settings.darkness_enabled = true
		check(mask.get_texture() == texture and fog.get_node("Shadow").visible and darkness.visible,
			"presentation ON reuses same viewport and texture")
		for light_index in lights.size():
			check(lights[light_index].enabled == original_light_states[light_index], "lamp state restored")
	check(not perception.detection_enabled, "fog toggles do not modify AI detection")
	# Physical test: use an impulse-like velocity; input and rolling physics remain unchanged.
	var original_mask: int = player.collision_mask
	var original_layer: int = player.collision_layer
	var shape = player.get_node("CollisionShape2D")
	var original_disabled: bool = shape.disabled
	var original_inertia: float = player.inertia
	settings.noclip = true
	await ticks()
	player.angular_velocity = 0.0
	player.apply_torque_impulse(1000.0)
	await ticks()
	check(absf(player.angular_velocity) > 0.01, "noclip preserves torque rotation")
	player.angular_velocity = 0.0
	player.rotation = 0.0
	player.sleeping = true
	Input.action_press("noclip_right")
	await ticks(10)
	check(player.linear_velocity.x > 200.0,
		"noclip WASD wakes body and moves sideways without lateral grip")
	Input.action_press("noclip_up")
	await ticks(3)
	check(player.linear_velocity.y < -100.0 and player.linear_velocity.length() <= 241.0,
		"noclip diagonal normalized")
	player.get_node("WheelchairInput").set_input_enabled(false)
	await ticks()
	check(player.linear_velocity.length() < 0.01, "UI gate stops keyboard noclip")
	Input.action_release("noclip_right")
	Input.action_release("noclip_up")
	player.get_node("WheelchairInput").set_input_enabled(true)
	settings.noclip = false
	await ticks()
	check(player.inertia == original_inertia, "noclip restores automatic/custom inertia")
	Input.action_press("noclip_right")
	await ticks()
	check(player.linear_velocity.length() < 0.01, "WASD inactive outside noclip")
	Input.action_release("noclip_right")
	player.rotation = 0
	player.angular_velocity = 0
	var cases := [Vector2(180, 280), Vector2(310, 440), Vector2(504, 440)]
	for start in cases:
		settings.noclip = true
		await ticks()
		player.global_position = start
		player.linear_velocity = Vector2(0, -220)
		await ticks(45)
		check(player.global_position.y < start.y - 70.0, "noclip crosses solid at " + str(start))
		player.global_position = start
		player.linear_velocity = Vector2.ZERO
		settings.noclip = false
		await ticks()
		check(player.collision_mask == original_mask and player.collision_layer == original_layer
			and shape.disabled == original_disabled, "noclip restores exact collision state")
		player.linear_velocity = Vector2(0, -220)
		await ticks(45)
		check(player.global_position.y >= start.y - 40.0, "restored wall/door/window blocks Player")
	shape.set_deferred("disabled", true)
	await ticks()
	settings.noclip = true
	await ticks()
	settings.noclip = false
	await ticks()
	check(shape.disabled, "pre-disabled shape remains disabled after noclip")
	shape.set_deferred("disabled", false)
	await ticks()
	settings.noclip = true
	await ticks()
	settings.noclip = false
	settings.noclip = true
	await ticks()
	settings.noclip = false
	await ticks()
	check(not shape.disabled, "rapid OFF/ON before deferred flush preserves original shape")
	# F1 is configured, while the menu handles the action rather than a physical key constant.
	var action := InputEventAction.new()
	action.action = &"toggle_debug_menu"
	action.pressed = true
	root.push_input(action)
	check(menu.is_open() and not player.get_node("WheelchairInput").input_enabled,
		"menu action opens and gates gameplay")
	root.push_input(action)
	check(not menu.is_open(), "menu action closes")
	player.health.died.connect(func(): deaths += 1)
	player.take_damage(1000)
	player.take_damage(1000)
	player.heal(1000)
	settings.god_mode = true
	await ticks()
	check(player.health.current_health == 0 and deaths == 1 and player.freeze,
		"death once, no negative health or resurrection; body safely frozen")
	check(not player.get_node("WheelchairInput").input_enabled, "death input cannot be re-enabled")
	check(hud.text.contains("sin vida"), "HUD shows death")
	root.push_input(action)
	check(menu.is_open() and not player.get_node("WheelchairInput").input_enabled,
		"debug menu remains usable after death without restoring gameplay input")
	level.queue_free()
	await process_frame
	print("PLAYER DEBUG RESULT: ", failures, " failures")
	quit(failures)
