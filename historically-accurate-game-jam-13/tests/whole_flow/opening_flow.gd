extends "res://tests/support/flow_test.gd"

var shell: GameShell


func run() -> void:
	shell = await boot_shell()
	check(shell.menu.visible and not shell.hud.visible and not shell.transition.fade.visible, "Boot opens only the main menu, uncovered")
	check(not shell.room.control_enabled, "The menu does not move the player")
	check(root.gui_get_focus_owner() == shell.menu.get_node("%Start"), "Start has keyboard focus")
	_check_landing_camera()
	var floor_asset: Node3D = shell.room.get_node("Geometry/Architecture/Floor")
	floor_asset.enabled = false
	await process_frame
	await process_frame
	check(not floor_asset.visible and not floor_asset.get_node("Surface").use_collision, "A floor asset disables geometry and collision together")
	floor_asset.enabled = true
	await process_frame
	await process_frame
	check(floor_asset.visible and floor_asset.get_node("Surface").use_collision, "A floor asset restores its authored collision")
	var stand_asset: Node3D = shell.room.get_node("Props/TrainingStand")
	stand_asset.enabled = false
	await process_frame
	await process_frame
	check(not stand_asset.get_node("Base").use_collision and stand_asset.get_node("Slots/CollisionShape3D").disabled, "A stand disables both its body and interaction shapes")
	stand_asset.enabled = true
	await process_frame
	await process_frame
	check(stand_asset.get_node("Base").use_collision and not stand_asset.get_node("Slots/CollisionShape3D").disabled, "A stand restores both collision types")
	shell.menu.settings_requested.emit()
	check(shell.settings.visible and not shell.menu.visible, "Settings replace menu input")
	shell.settings.row(&"sensitivity").editor.value = 0.16
	check(is_equal_approx(shell.room.rig.mouse_sensitivity, 0.16), "Sensitivity applies to the camera")
	await press(&"ui_cancel")
	check(shell.menu.visible and not shell.settings.visible, "Escape returns from settings")
	check(root.gui_get_focus_owner() == shell.menu.get_node("%Settings"), "Settings focus is restored")
	await _observe_start_transition()
	check(shell.dialogue.session.active and shell.room.control_enabled and not shell.room.interactor.enabled, "Greeting allows movement while owning context actions")
	var greeting := shell.dialogue.session.dialogue
	shell.dialogue.close()
	var previous_time_scale := Engine.time_scale
	Engine.time_scale = 0.0
	shell.dialogue.open(greeting)
	await process_frame
	await process_frame
	shell.dialogue.entrance.custom_step(0.1)
	check(shell.dialogue.modulate.a > 0.0 and shell.dialogue.modulate.a < 1.0, "Dialogue fades in rather than appearing instantly")
	Engine.time_scale = previous_time_scale
	await click(MOUSE_BUTTON_LEFT)
	check(shell.dialogue.session.index == 0, "Interaction does not substitute for the bark action")
	await press(&"bark")
	check(shell.dialogue.session.index == 1, "Only Bark answers a bark request")
	await press(&"ui_cancel")
	check(paused and shell.pause.visible, "Escape pauses during a dialogue")
	shell.pause.settings_requested.emit()
	await press(&"ui_cancel")
	check(paused and shell.pause.visible, "Closing settings preserves pause")
	await press(&"ui_cancel")
	check(not paused and shell.dialogue.visible, "Resume restores the active dialogue")
	await press(&"interact")
	check(shell.room.progress.has_flag(&"fetch") and shell.room.control_enabled, "Greeting starts the collection task")
	check(shell.hud.objective.size.y > 0 and not shell.hud.objective.text.is_empty(), "The current objective occupies a visible text row")
	check(_snout_in_frame(), "The existing snout is visible under the gameplay camera")
	await _jump()
	await _aim(Vector3(1.5, 0, 0.2), shell.room.get_node("Props/TrainingStand/TestButton").global_position)
	check(_target_is("Props/TrainingStand/TestButton"), "The test button is reachable from dog height")
	await press(&"interact")
	check(shell.room.progress.has_flag(&"fetch") and not shell.dialogue.session.active, "Pressing the button early is recoverable")
	await _aim(Vector3(-2.8, 0, 2.5), shell.room.get_node("Pickups/Battery1/Item").global_position)
	check(_target_is("Pickups/Battery1/Item"), "The first battery is reachable by raycast")
	var pickup_scale: Vector3 = shell.room.interactor.target.global_basis.get_scale()
	await click(MOUSE_BUTTON_LEFT)
	check(shell.room.carry.item != null, "LMB picks up a battery")
	check(shell.room.carry.item.global_basis.get_scale().is_equal_approx(pickup_scale), "Picking up a battery preserves its physical scale")
	var held_position: Vector2 = shell.room.camera.unproject_position(shell.room.carry.item.global_position)
	var view_size: Vector2 = shell.room.camera.get_viewport().get_visible_rect().size
	var lower_frame := 0.65 if DisplayServer.get_name() == "headless" else 0.8
	check(absf(held_position.x - view_size.x * 0.5) < view_size.x * 0.02 and held_position.y > view_size.y * lower_frame and held_position.y < view_size.y * 1.1, "The held battery sits centrally below the nose")
	await click(MOUSE_BUTTON_RIGHT)
	check(shell.room.carry.item == null and shell.room.get_node("Pickups/Battery1/Item").collision_layer == 2, "RMB puts the battery down safely")
	var dropped_mesh: MeshInstance3D = shell.room.get_node("Pickups/Battery1/Item/Visuals/Mesh")
	check(dropped_mesh.layers == 1 and not dropped_mesh.material_override.no_depth_test, "A dropped battery restores its world rendering")
	check(shell.room.get_node("Pickups/Battery1/Item").global_position.distance_to(shell.room.player.global_position) < 1.2, "Dropped batteries stay near the dog")
	await _aim(Vector3(-2.8, 0, 2.5), shell.room.get_node("Pickups/Battery1/Item").global_position)
	await press(&"interact")
	var held_battery: Node = shell.room.carry.item
	await _aim(Vector3(2.65, 0, 1.8), shell.room.get_node("Pickups/Battery2/Item").global_position)
	await click(MOUSE_BUTTON_LEFT)
	check(_target_is("Pickups/Battery2/Item") and shell.room.carry.item == held_battery, "LMB keeps the held battery when aiming at another pickup")
	check(shell.hud.prompt.text.is_empty(), "A held item does not advertise a second LMB action")
	await _aim(Vector3(-2.8, 0, 2.5), Vector3(-2.8, 0, 1.5))
	await click(MOUSE_BUTTON_LEFT)
	check(shell.room.carry.item == held_battery, "LMB keeps the held battery when looking at empty floor")
	await click(MOUSE_BUTTON_RIGHT)
	check(shell.room.carry.item == null, "Only the dedicated put-down action releases the held item")
	await _aim(Vector3(-2.8, 0, 2.5), shell.room.get_node("Pickups/Battery1/Item").global_position)
	await click(MOUSE_BUTTON_LEFT)
	check(shell.room.carry.item != null, "A put-down item can be picked up again")
	await _aim(Vector3(0, 0, 0.3), shell.room.get_node("Props/TrainingStand/Slots").global_position)
	check(_target_is("Props/TrainingStand/Slots"), "The battery stand is reachable")
	await click(MOUSE_BUTTON_LEFT)
	check(shell.room.progress.socket.count == 1 and shell.room.carry.item == null, "The same LMB action installs the battery")
	var installed_mesh: MeshInstance3D = shell.room.get_node("Props/TrainingStand/Cell1")
	check(installed_mesh.mesh.get_aabb().size.is_equal_approx(dropped_mesh.mesh.get_aabb().size), "Installed batteries retain the pickup dimensions")
	await _aim(Vector3(2.65, 0, 1.8), shell.room.get_node("Pickups/Battery2/Item").global_position)
	check(_target_is("Pickups/Battery2/Item"), "The second battery is reachable")
	await press(&"interact")
	await _aim(Vector3(0, 0, 0.3), shell.room.get_node("Props/TrainingStand/Slots").global_position)
	await press(&"interact")
	check(shell.room.progress.socket.is_full() and not shell.room.progress.has_flag(&"fetch"), "Two batteries unlock the test")
	await _aim(Vector3(1.5, 0, 0.2), shell.room.get_node("Props/TrainingStand/TestButton").global_position)
	await press(&"interact")
	check(shell.dialogue.session.active, "The successful test opens the scientist's dialogue")
	await press(&"bark")
	await press(&"interact")
	check(shell.room.progress.has_flag(&"departure_ready"), "The scientist unlocks departure")
	await _aim(Vector3(1.5, 0, 0.2), shell.room.get_node("Props/TrainingStand/TestButton").global_position)
	await press(&"interact")
	check(not shell.dialogue.session.active and "Test complete" in shell.hud.thought.text, "Repeating a completed test does not ask for more batteries")
	check(shell.room.progress.socket.count == 2 and shell.room.progress.has_flag(&"departure_ready") and "capsule" in shell.hud.objective.text, "Repeating the button preserves batteries and the capsule objective")
	await _aim(Vector3(3.6, 0, -1.2), shell.room.get_node("Props/Capsule/Entry").global_position)
	check(_target_is("Props/Capsule/Entry"), "The capsule can be entered from the front")
	await press(&"interact")
	await _settle_transition()
	check(shell.room.progress is StationProgress and shell.dialogue.session.active, "Departure fades into station arrival")
	check(_snout_in_frame(), "The snout remains visible on the station")
	check(not shell.hud.thought_panel.visible, "Room transitions clear the previous thought")
	await press(&"bark")
	await press(&"interact")
	await _aim(Vector3(0, 0, 1.2), shell.room.get_node("Actors/Robot/Interaction").global_position)
	check(_target_is("Actors/Robot/Interaction"), "The robot is reachable")
	shell.room.rig.set_process_unhandled_input(true)
	await press(&"interact")
	check(shell.dialogue.session.active and shell.dialogue.session.dialogue == StationProgress.ROBOT, "The robot has a separate speaker and dialogue")
	await press(&"bark")
	check(shell.dialogue.session.index == 1 and "Continue dialogue" in shell.dialogue.response.text, "Answering the robot clearly requests the next context action")
	await press(&"bark")
	check(shell.dialogue.session.index == 1 and "Woof!" in shell.dialogue.response.text, "A second bark visibly responds without skipping the robot's text")
	await click(MOUSE_BUTTON_LEFT)
	check(not shell.dialogue.session.active and shell.completion.visible and shell.room.control_enabled, "Finishing the robot shows a notice without blocking the player")
	var look_yaw: float = shell.room.rig.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30, 0)
	Input.parse_input_event(motion)
	await process_frame
	var look_works: bool = shell.room.rig.is_processing_unhandled_input() if DisplayServer.get_name() == "headless" else not is_equal_approx(shell.room.rig.yaw, look_yaw)
	check(look_works, "Completion keeps mouse look responsive immediately")
	check(shell.hud.visible and shell.mode == shell.Mode.PLAYING and not paused, "The notice keeps the game and HUD active")
	check(shell.room.progress.has_flag(&"complete") and shell.hud.objective.text == "Playground complete", "The old talk-to-robot objective is completed")
	await press(&"bark")
	check(shell.hud.thought_panel.visible and shell.hud.thought.text == "Woof!", "Barking still responds while exploring after completion")
	await _aim(Vector3(0, 0, 1.2), shell.room.get_node("Actors/Robot/Interaction").global_position)
	await press(&"interact")
	check(not shell.dialogue.session.active and shell.room.control_enabled, "Revisiting the robot after completion does not restart a blocking dialogue")
	await process_frame
	await process_frame
	await press(&"ui_cancel")
	await click_at(shell.completion.get_node("%MainMenu").get_global_rect().get_center())
	await _settle_transition()
	check(not paused and shell.menu.visible and not shell.dialogue.session.active, "Return to menu clears pause and dialogue")
	check(not shell.completion.visible and shell.completion.lifetime.is_stopped(), "Leaving through the notice cancels its timer")
	await shell.start_game()
	check(shell.room.progress.socket.count == 0 and shell.room.carry.item == null, "A new mission resets the room")
	await press(&"bark")
	await press(&"interact")
	var previous_focus: Control = root.gui_get_focus_owner()
	shell.completion.open()
	check(root.gui_get_focus_owner() == previous_focus and shell.completion.lifetime.time_left > 4.9, "The notice lasts five seconds without stealing focus")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	shell.completion.lifetime.start(0.05)
	await create_timer(0.15, true, false, true).timeout
	await process_frame
	var mouse_look_restored := DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	check(not shell.completion.visible and shell.room.control_enabled and mouse_look_restored, "Notice expiry keeps mouse look and gameplay active")
	shell.pause_game()
	shell.completion.open()
	shell.completion.lifetime.start(0.05)
	await create_timer(0.15, true, false, true).timeout
	await process_frame
	check(not shell.completion.visible and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Notice expiry does not close or capture the pause menu")
	await press(&"ui_cancel")
	shell.queue_free()
	await process_frame
	await process_frame


func _check_landing_camera() -> void:
	var rig: FPSCamera = shell.room.rig
	for delta: float in [1.0 / 60.0, 0.1, 0.25]:
		rig._dip = 0.0
		rig._dip_velocity = 0.0
		rig._on_landed(rig.landing_dip_full_speed)
		var bounded := true
		for frame: int in 60:
			rig._process(delta)
			bounded = bounded and is_finite(rig._dip) and absf(rig._dip) <= rig.landing_dip + 0.001
		check(bounded, "Landing camera stays bounded with a %.3f second frame" % delta)
		check(absf(rig._dip) < 0.002, "Landing camera settles with a %.3f second frame" % delta)
	rig._dip = 0.0
	rig._dip_velocity = 0.0
	rig._process(0.0)


func _aim(position: Vector3, point: Vector3) -> void:
	var room: LaikaRoom = shell.room
	room.rig.set_process_unhandled_input(false)
	room.player.teleport(position)
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	var direction := (point - room.camera.global_position).normalized()
	room.rig.set_look(atan2(-direction.x, -direction.z), asin(direction.y))
	await process_frame
	await process_frame
	await process_frame


func _target_is(path: NodePath) -> bool:
	return shell.room.interactor.target == shell.room.get_node(path)


func _observe_start_transition() -> void:
	var started := false
	var saw_reveal := false
	var camera_stable := true
	var input_blocked := true
	var title_started: int = -1
	var title_elapsed: int = 0
	var revealed_at: int = -1
	var reveal_transform: Transform3D
	var deadline := Time.get_ticks_msec() + 15000
	shell.start_game.call_deferred()
	while (not started or shell.transitioning) and Time.get_ticks_msec() < deadline:
		started = started or shell.transitioning
		if started and shell.mode == shell.Mode.PLAYING:
			input_blocked = input_blocked and not shell.room.control_enabled and not shell.dialogue.session.active
			if shell.transition.fade.visible and shell.transition.fade.modulate.a >= 0.999:
				if title_started < 0:
					title_started = Time.get_ticks_msec()
			else:
				if not saw_reveal:
					saw_reveal = true
					title_elapsed = Time.get_ticks_msec() - title_started
					reveal_transform = shell.room.camera.global_transform
				camera_stable = camera_stable and shell.room.camera.get_viewport().get_camera_3d() == shell.room.camera
				camera_stable = camera_stable and reveal_transform.is_equal_approx(shell.room.camera.global_transform)
				if not shell.transition.fade.visible and revealed_at < 0:
					revealed_at = Time.get_ticks_msec()
		await process_frame
	check(saw_reveal and camera_stable and shell.room.camera.get_viewport().get_camera_3d() == shell.room.camera and reveal_transform.is_equal_approx(shell.room.camera.global_transform), "The player camera is stable throughout reveal and greeting")
	check(title_elapsed >= 700, "The chapter title remains readable before revealing the room")
	check(revealed_at >= 0 and Time.get_ticks_msec() - revealed_at >= 100, "The room appears before the greeting starts")
	check(input_blocked and not shell.transitioning, "Input stays blocked until the opening transition finishes")


func _settle_transition() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while shell.transitioning and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not shell.transitioning, "Transition finishes within fifteen seconds")


func _jump() -> void:
	var baseline: float = shell.room.player.global_position.y
	var peak: float = 0.0
	var event := InputEventAction.new()
	event.action = &"jump"
	event.pressed = true
	Input.parse_input_event(event)
	for frame in range(50):
		await physics_frame
		peak = maxf(peak, shell.room.player.global_position.y - baseline)
	event = InputEventAction.new()
	event.action = &"jump"
	event.pressed = false
	Input.parse_input_event(event)
	check(peak > 0.55 and peak < 0.85, "The dog jumps approximately 0.7 metres")


func _snout_in_frame() -> bool:
	var camera: Camera3D = shell.room.camera
	var snout: Node3D = camera.get_node("Snout")
	var frame := camera.get_viewport().get_visible_rect()
	var visible_vertices := 0
	for part: MeshInstance3D in snout.find_children("*", "MeshInstance3D", true, false):
		for vertex: Vector3 in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var point := part.to_global(vertex)
			if not camera.is_position_behind(point) and frame.has_point(camera.unproject_position(point)):
				visible_vertices += 1
	return snout.is_visible_in_tree() and visible_vertices > 24
