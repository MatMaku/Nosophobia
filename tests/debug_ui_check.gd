extends SceneTree
## Run with rendering enabled: native keyboard/mouse GUI routing and screenshots.

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	print("PASS: " if value else "FAIL: ", label)
	if not value:
		failures += 1


func ticks(count: int = 3) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func key_f1(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F1
	event.pressed = true
	event.echo = echo
	root.push_input(event, true)
	event = InputEventKey.new()
	event.physical_keycode = KEY_F1
	root.push_input(event, true)
	await ticks()


func click(point: Vector2) -> void:
	root.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await ticks()


func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + name + ".png")


func _run() -> void:
	var main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await ticks(12)
	var player = main.get_node("MovementTest/Player")
	player.freeze = true
	var session = player.get_node("LevelSession")
	var menu = session.get_node("DebugMenu")
	var settings = session.get_node("LevelDebug").settings
	var movement = player.get_node("WheelchairInput")
	var options = menu.get_node("Blocker/Panel/Margin/Options")
	await capture("health_hud_default")
	await key_f1()
	check(menu.is_open(), "F1 action opens menu")
	await key_f1(true)
	check(menu.is_open(), "held key echo does not toggle repeatedly")
	for flag in menu.FLAGS:
		var old: bool = settings.get(flag)
		await click(options.get_node(flag).get_global_rect().get_center())
		check(settings.get(flag) == not old, "native checkbox controls " + flag)
		check(not movement.drag_active and not movement.input_enabled, "menu never starts chair gesture")
	await capture("debug_menu_clear")
	await click(root.get_visible_rect().size * 0.5)
	check(not movement.drag_active, "menu backdrop blocks world click")
	settings.show_debug_visuals = false
	await capture("debug_menu_clear_no_lines")
	for flag in menu.FLAGS:
		settings.set(flag, flag in ["enemy_detection_enabled", "fog_enabled", "darkness_enabled"])
	await key_f1()
	check(not menu.is_open() and movement.input_enabled, "closing menu restores gameplay gate")
	player.take_damage(25)
	await ticks()
	await capture("health_hud_75")
	main.queue_free()
	await process_frame
	print("DEBUG UI RESULT: ", failures, " failures")
	quit(failures)
