extends SceneTree

const Inventory = preload("res://scripts/inventory/inventory.gd")
const ItemStack = preload("res://scripts/inventory/item_stack.gd")
const Equipment = preload("res://scripts/inventory/equipment.gd")

var failures: int = 0
var shots: int = 0
var dry: int = 0
var segments: Array[Vector2] = []
var starts: Array[Vector2] = []


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1


func ticks(count: int = 3) -> void:
	for i in count:
		await physics_frame
		await process_frame


func point(position: Vector2, relative: Vector2 = Vector2.ZERO, held: bool = false) -> void:
	root.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.relative = relative
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(motion, true)
	await ticks()


func button(position: Vector2, index: MouseButton, pressed: bool) -> void:
	await point(position)
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)
	await ticks()


func click(position: Vector2) -> void:
	await button(position, MOUSE_BUTTON_LEFT, true)
	await button(position, MOUSE_BUTTON_LEFT, false)


func drag_to(source: Control, target: Vector2) -> void:
	var start := source.get_global_rect().get_center()
	await button(start, MOUSE_BUTTON_LEFT, true)
	await point(start + Vector2(18, 0), Vector2(18, 0), true)
	await point(target, target - start, true)
	await button(target, MOUSE_BUTTON_LEFT, false)


func _run() -> void:
	seed(12345)
	var revolver: ItemDefinition = load("res://resources/items/revolver_item.tres")
	var shotgun: ItemDefinition = load("res://resources/items/double_barrel_shotgun_item.tres")
	var ammo := revolver.firearm.compatible_ammo
	var shell := shotgun.firearm.compatible_ammo
	var model := Inventory.new(4)
	model.try_add(revolver, 2)
	check(model.get_item(0).firearm_state != model.get_item(1).firearm_state,
		"separate weapons have separate runtime state")
	var state := model.get_item(0).firearm_state
	model.try_add(ammo, 30)
	check(not model.try_load_round(state, 0, shell), "incompatible ammo rejected")
	check(model.try_load_round(state, 0, ammo), "one-round transfer succeeds")
	check(model.count_item(ammo) == 29 and state.get_loaded_count() == 1,
		"transfer consumes exactly one and loads exactly one")
	check(not model.try_load_round(state, 0, ammo), "occupied chamber rejects drop")
	check(not model.try_load_round(state, 6, ammo), "out-of-bounds chamber rejected")
	check(model.get_item(1).firearm_state.get_loaded_count() == 0, "second weapon stays empty")
	check(model.move(0, 3, model.get_item(0)) and model.get_item(3).firearm_state == state,
		"move retains firearm state")
	var equip := Equipment.new()
	equip.equip(model, 3, model.get_item(3))
	equip.unequip(model, 3, equip.get_weapon())
	check(model.get_item(3).firearm_state == state and state.get_loaded_count() == 1,
		"equip and unequip preserve loaded chambers")

	var main = load("res://scenes/app/main.tscn").instantiate()
	root.add_child(main)
	await ticks()
	var player = main.get_node("MovementTest/Player")
	# This fixture checks the upper obstacle; production now starts facing down.
	player.rotation = 0.0
	var pickup = player.get_node("PickupInteractor")
	var aim = player.get_node("WeaponAim")
	var firearm = player.get_node("FirearmController")
	var movement = player.get_node("WheelchairInput")
	var ui = main.get_node("HUD/InventoryUI")
	var reload_ui = main.get_node("HUD/WeaponReloadUI")
	var cursor = main.get_node("CursorController")
	firearm.shot_fired.connect(func(_origin: Vector2, _direction: Vector2): shots += 1)
	firearm.dry_fired.connect(func(): dry += 1)
	firearm.shot_resolved.connect(func(result):
		starts.append(result.start)
		segments.append(result.end))
	var center: Vector2 = player.get_global_transform_with_canvas().origin
	await button(center + Vector2(0, -90), MOUSE_BUTTON_RIGHT, true)
	check(not aim.is_aiming, "no weapon means no aiming")
	await button(center, MOUSE_BUTTON_RIGHT, false)

	var world = main.get_node("MovementTest/TestWeapon")
	world.global_position = player.global_position + Vector2.UP * pickup.pickup_distance * 0.5
	await ticks(1)
	await click(world.get_global_transform_with_canvas().origin)
	check(not is_instance_valid(world), "revolver picked up by actual world click")
	pickup.inventory.try_add(ammo, 30)
	pickup.inventory.try_add(shotgun)
	pickup.inventory.try_add(shell, 10)
	await click(ui.get_node("BackpackButton").get_global_rect().get_center())
	var grid = ui.get_node("Panel/Margin/Content/Slots")
	var weapon_slot = ui.get_node("Panel/Margin/Content/Weapon/WeaponSlot")
	await drag_to(grid.get_child(0), weapon_slot.get_global_rect().get_center())
	check(pickup.equipment.get_weapon() != null, "native inventory drag equips revolver")
	if pickup.equipment.get_weapon() == null:
		quit(1)
		return
	state = pickup.equipment.get_weapon().firearm_state
	check(state.get_capacity() == 6 and state.get_loaded_count() == 0, "revolver starts empty")
	check(reload_ui.get_node("WeaponButton").visible, "weapon HUD button appears")
	await button(center + Vector2(0, -90), MOUSE_BUTTON_RIGHT, true)
	check(aim.is_aiming and not ui.is_open(),
		"inventory outside RMB closes panel and aims")
	await button(center, MOUSE_BUTTON_RIGHT, false)
	await button(center + Vector2(0, -90), MOUSE_BUTTON_RIGHT, true)
	check(aim.is_aiming and not movement.input_enabled, "RMB aims and explicitly blocks movement")
	check(cursor.current_state == cursor.State.AIMING, "aiming cursor state")
	await click(center + Vector2(0, -90))
	check(dry == 1 and shots == 0 and segments.is_empty(), "dry fire has no shot or tracer")
	await button(center, MOUSE_BUTTON_RIGHT, false)
	check(not aim.is_aiming and movement.input_enabled, "release restores movement")
	for offset in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		var direction: Vector2 = aim.direction_toward(player.global_position + offset * 100)
		var forward := Vector2.UP.rotated(player.global_rotation)
		check(absf(rad_to_deg(forward.angle_to(direction))) <= 55.01, "aim clamped " + str(offset))
	var old_rotation: float = aim.rotation
	aim.rotation = 1.0
	var rotated_forward := Vector2.UP.rotated(aim.global_rotation)
	check(aim.direction_toward(aim.global_position + rotated_forward * 100).is_equal_approx(
		rotated_forward), "aim respects rotated chair orientation")
	aim.rotation = old_rotation
	await click(reload_ui.get_node("WeaponButton").get_global_rect().get_center())
	check(reload_ui.is_open() and reload_ui.get_loose_count() == 6, "0/6 plus 30 shows six tokens")
	await button(center, MOUSE_BUTTON_RIGHT, true)
	check(aim.is_aiming and not reload_ui.is_open(),
		"reload outside RMB closes panel and aims")
	await button(center, MOUSE_BUTTON_RIGHT, false)
	await click(reload_ui.get_node("WeaponButton").get_global_rect().get_center())
	var sockets = reload_ui.get_node("Panel/Margin/Content/LayoutHost").get_child(0).get_node("Sockets")
	var loose = reload_ui.get_node("Panel/Margin/Content/LooseRounds")
	await drag_to(loose.get_child(0), sockets.get_child(0).get_global_rect().get_center())
	check(state.get_loaded_count() == 1 and pickup.inventory.count_item(ammo) == 29,
		"native round drag loads one chamber")
	check(not movement.drag_active and shots == 0, "round drag does not move or fire")
	var before: int = pickup.inventory.count_item(ammo)
	await drag_to(loose.get_child(0), sockets.get_child(0).get_global_rect().get_center())
	check(pickup.inventory.count_item(ammo) == before, "native drop on loaded chamber rejected")
	await drag_to(loose.get_child(0), Vector2(800, 50))
	check(pickup.inventory.count_item(ammo) == before, "cancelled native drag preserves ammo")
	check(cursor.current_state != cursor.State.GRABBING, "cursor released after invalid drag")
	await drag_to(loose.get_child(0), sockets.get_child(2).get_global_rect().get_center())
	await drag_to(loose.get_child(0), sockets.get_child(4).get_global_rect().get_center())
	check(state.get_loaded_count() == 3, "non-consecutive chambers loaded")
	await click(reload_ui.get_node("WeaponButton").get_global_rect().get_center())
	await button(center + Vector2(0, -120), MOUSE_BUTTON_RIGHT, true)
	await button(center + Vector2(0, -120), MOUSE_BUTTON_LEFT, true)
	check(shots == 1 and segments.size() == 1 and state.get_loaded_count() == 2,
		"revolver trigger consumes one and casts one ray")
	check(player.linear_velocity.y > 0.1, "revolver recoil pushes chair backward")
	check(segments[0].y >= 385.0 and segments[0].y <= 387.0,
		"closed door clips hitscan endpoint")
	await ticks(30)
	check(shots == 1, "holding LMB is not automatic fire")
	await button(center, MOUSE_BUTTON_LEFT, false)
	await click(center + Vector2(0, -120))
	check(shots == 2 and state.get_loaded_count() == 1, "second trigger consumes second round")
	await click(center + Vector2(0, -120))
	check(shots == 2, "cooldown rejects rapid repeated trigger")
	await button(center, MOUSE_BUTTON_RIGHT, false)
	await ticks(40)
	check(main.get_node("Tracers").get_child_count() == 0, "tracers fade and free themselves")
	await click(reload_ui.get_node("WeaponButton").get_global_rect().get_center())
	check(state.get_loaded_count() == 1 and state.is_loaded(4), "reopen reflects remaining chamber")
	await click(reload_ui.get_node("WeaponButton").get_global_rect().get_center())
	pickup.equipment.unequip(pickup.inventory, 0, pickup.equipment.get_weapon())
	pickup.equipment.equip(pickup.inventory, 0, pickup.inventory.get_item(0))
	check(pickup.equipment.get_weapon().firearm_state == state and state.get_loaded_count() == 1,
		"re-equip after firing retains the one remaining round")
	# Match the specified limited-ammo display case without introducing production debug controls.
	for index in pickup.inventory.get_capacity():
		var entry = pickup.inventory.get_item(index)
		if entry != null and entry.definition == ammo:
			pickup.inventory.exchange(index, entry, null)
	pickup.inventory.try_add(ammo, 3)
	check(reload_ui.get_loose_count() == 3, "1/6 plus three ammo shows three tokens")
	for chamber in [0, 1, 2]:
		pickup.inventory.try_load_round(state, chamber, ammo)
	pickup.inventory.try_add(ammo, 30)
	check(reload_ui.get_loose_count() == 2, "4/6 plus 30 shows two tokens")
	# Equip shotgun from its existing backpack slot.
	for index in pickup.inventory.get_capacity():
		var entry = pickup.inventory.get_item(index)
		if entry != null and entry.definition == shotgun:
			pickup.equipment.equip(pickup.inventory, index, entry)
			break
	await ticks()
	state = pickup.equipment.get_weapon().firearm_state
	check(state.get_capacity() == 2 and not aim.is_aiming, "shotgun swap resets aim and has two chambers")
	await click(reload_ui.get_node("WeaponButton").get_global_rect().get_center())
	sockets = reload_ui.get_node("Panel/Margin/Content/LayoutHost").get_child(0).get_node("Sockets")
	check(sockets.get_child_count() == 2, "shotgun uses its two-socket layout")
	for i in 2:
		await drag_to(loose.get_child(0), sockets.get_child(i).get_global_rect().get_center())
	check(state.get_loaded_count() == 2 and pickup.inventory.count_item(shell) == 8,
		"shotgun loads two individual shells")
	await click(reload_ui.get_node("WeaponButton").get_global_rect().get_center())
	await ticks(60)
	center = player.get_global_transform_with_canvas().origin
	await button(center + Vector2(0, -120), MOUSE_BUTTON_RIGHT, true)
	var prior_segments := segments.size()
	var prior_shots := shots
	await click(center + Vector2(0, -120))
	check(shots == prior_shots + 1 and state.get_loaded_count() == 1,
		"shotgun consumes one shell per trigger")
	check(segments.size() == prior_segments + shotgun.firearm.pellet_count,
		"shotgun creates one ray and tracer per configured pellet")
	var base := Vector2.UP.rotated(player.global_rotation)
	for index in range(prior_segments, segments.size()):
		var ray := segments[index] - starts[index]
		check(absf(rad_to_deg(base.angle_to(ray))) <= 9.1, "pellet inside spread cone")
	await button(center, MOUSE_BUTTON_RIGHT, false)
	await click(reload_ui.get_node("WeaponButton").get_global_rect().get_center())
	check(reload_ui.get_loose_count() == 1, "1/2 shotgun shows one loose shell")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/firearm_preview.png")
	print("RESULT: ", failures, " failures")
	quit(failures)
