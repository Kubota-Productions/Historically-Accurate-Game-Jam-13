extends "res://tests/support/flow_test.gd"


func run() -> void:
	print("INSPECTION: boot")
	var shell := await boot_shell()
	shell.transition.fade_out_seconds = 0.0
	shell.transition.fade_in_seconds = 0.0
	shell.transition.intro_pause_seconds = 0.0
	shell.transition.chapter_hold_seconds = 0.0
	shell.transition.menu_hold_seconds = 0.0
	await shell.enter_room(load("res://GameData/Rooms/station.tres"))
	print("INSPECTION: started")
	shell.dialogue.close()
	shell._sync_context()
	await frames(2)
	var item: PickupItem = shell.room.get_node("Pickups/Battery1/Item")
	var original_transform := item.global_transform
	var original_parent := item.get_parent()
	var original_layer := item.collision_layer
	shell.room.interactor.target = item
	var previous_mouse_mode := Input.mouse_mode
	check(shell.inspect_item(), "A focused pickup opens in inspection")
	await frames(2)
	print("INSPECTION: opened")
	await _capture("battery")
	check(shell.inspection.visible and not shell.hud.visible, "Inspection replaces the gameplay HUD")
	check(not shell.room.control_enabled and not shell.room.interactor.enabled, "Movement and world interactions are blocked")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Inspection releases the cursor")
	check(item.global_transform == original_transform and item.get_parent() == original_parent and item.collision_layer == original_layer, "Inspection does not move or alter the original item")
	check(shell.inspection.pivot.get_child_count() == 1, "The isolated viewport contains a preview model")
	check(shell.inspection._bounds(shell.inspection._model).size.length() > 0.01, "The current battery model is found outside its empty Visuals node")
	var yaw := shell.room.rig.yaw
	var before := shell.inspection.pivot.basis
	var center := shell.inspection.preview.get_global_rect().get_center()
	_mouse(shell, MOUSE_BUTTON_LEFT, true, center)
	var motion := InputEventMouseMotion.new()
	motion.position = center + Vector2(90, 30)
	motion.relative = Vector2(90, 30)
	shell._input(motion)
	_mouse(shell, MOUSE_BUTTON_LEFT, false, motion.position)
	check(not shell.inspection.pivot.basis.is_equal_approx(before), "Dragging rotates the preview")
	check(is_equal_approx(shell.room.rig.yaw, yaw), "Dragging does not turn the player")
	var distance := shell.inspection.camera.position.z
	_mouse(shell, MOUSE_BUTTON_WHEEL_UP, true, center)
	check(shell.inspection.camera.position.z < distance, "Scrolling zooms toward the object")
	for n: int in 80:
		_mouse(shell, MOUSE_BUTTON_WHEEL_UP, true, center)
	check(is_equal_approx(shell.inspection._zoom, 0.65), "Zoom has a safe lower bound")
	shell.inspection.reset_view()
	check(shell.inspection.pivot.basis.is_equal_approx(Basis.IDENTITY) and is_equal_approx(shell.inspection._zoom, 1.0), "Reset restores orientation and framing")
	await press(&"drop")
	check(shell.inspection.visible and item.get_parent() == original_parent, "Gameplay drop does not run during inspection")
	await key(KEY_ESCAPE)
	check(not shell.inspection.visible and shell.mode == GameShell.Mode.PLAYING, "Escape closes inspection without opening pause")
	check(shell.room.control_enabled and shell.hud.visible, "Closing restores gameplay controls and HUD")
	check(Input.mouse_mode == previous_mouse_mode, "Closing restores the previous mouse mode")
	shell.room.carry.take(item)
	var held_transform := item.transform
	check(shell.inspect_item(), "A held item can be inspected")
	check(shell.room.carry.item == item and item.transform == held_transform, "Inspection preserves the held item and its pose")
	shell.pause_game()
	check(not shell.inspection.visible and shell.mode == GameShell.Mode.PAUSED, "Pausing closes inspection")
	shell.resume_game()
	check(shell.inspect_item(), "Inspection remains available after resume")
	shell.inspection.close()
	await _parts(shell)
	print("INSPECTION: parts complete")
	var other: PickupItem = shell.room.get_node("Pickups/Battery2/Item")
	shell.room.carry.item = null
	shell.room.interactor.target = other
	check(shell.inspect_item(), "A second item can be inspected")
	other.queue_free()
	await frames(2)
	check(not shell.inspection.visible and shell.room.control_enabled, "Removing the source closes the preview and restores control")
	shell.free()


func _parts(shell: GameShell) -> void:
	var item := shell.room.carry.item
	item.inspection_scene = load("res://Scenes/Shared/Inspection/ExampleReceiver.tscn")
	var activated: Array[StringName] = []
	item.inspection_part_activated.connect(func(id: StringName) -> void: activated.append(id))
	check(shell.inspect_item(), "An authored inspection scene can replace the mesh snapshot")
	print("INSPECTION: authored scene")
	await physics_frame
	await physics_frame
	var view := shell.inspection
	var part: InspectionPart = view._model.get_node("Receiver/Hinge/Part")
	var point := view.camera.unproject_position(part.global_position)
	var screen_point := view.preview.global_position + point * view.preview.size / Vector2(view.viewport.size)
	check(view._part_at(screen_point) == part, "A mouse ray finds an inspection part in its own 3D world")
	_mouse(shell, MOUSE_BUTTON_LEFT, true, screen_point)
	_mouse(shell, MOUSE_BUTTON_LEFT, false, screen_point)
	check(activated == [&"battery_cover"] and part.activated, "Clicking a part animates it and emits its ID on the source")
	check(item.inspected_parts.has(&"battery_cover"), "Part progress belongs to the original item")
	await frames(45)
	await _capture("receiver")
	check(view._part_at(screen_point) == null, "An activated part cannot fire repeatedly")
	view.close()
	check(shell.inspect_item(), "An inspected object can be reopened")
	part = view._model.get_node("Receiver/Hinge/Part")
	check(part.activated and is_equal_approx(view._model.get_node("Receiver/Hinge").rotation.y, -1.8), "Reopening restores the opened cover pose")
	await shell.return_to_menu()
	check(not view.visible and shell.mode == GameShell.Mode.MENU, "Returning to menu cleans up inspection")
	await shell.enter_room(load("res://GameData/Rooms/station.tres"))
	shell.dialogue.close()
	shell._sync_context()


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not root.use_hdr_2d and image.get_format() == Image.FORMAT_RGBA8, "Capture uses the display-space SDR root viewport")
	check(image.save_png("/tmp/laika-inspection-%s.png" % label) == OK, "Inspection screenshot saved")


func _mouse(shell: GameShell, button: MouseButton, pressed: bool, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	shell._input(event)
