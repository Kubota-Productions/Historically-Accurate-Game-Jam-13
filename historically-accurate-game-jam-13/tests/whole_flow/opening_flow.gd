extends SceneTree

var shell: Node
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	shell = load("res://Scenes/Game/Game.tscn").instantiate()
	root.add_child(shell)
	await process_frame
	_check(shell.menu.visible and not shell.hud.visible, "Boot opens only the main menu")
	_check(not shell.room.control_enabled, "The menu does not move the player")
	_check(root.gui_get_focus_owner() == shell.menu.get_node("%Start"), "Start has keyboard focus")
	_check_landing_camera()
	var floor_asset: Node3D = shell.room.get_node("Geometry/Architecture/Floor")
	floor_asset.enabled = false
	await process_frame
	await process_frame
	_check(not floor_asset.visible and not floor_asset.get_node("Surface").use_collision, "A floor asset disables geometry and collision together")
	floor_asset.enabled = true
	await process_frame
	await process_frame
	_check(floor_asset.visible and floor_asset.get_node("Surface").use_collision, "A floor asset restores its authored collision")
	var stand_asset: Node3D = shell.room.get_node("Props/TrainingStand")
	stand_asset.enabled = false
	await process_frame
	await process_frame
	_check(not stand_asset.get_node("Base").use_collision and stand_asset.get_node("Slots/CollisionShape3D").disabled, "A stand disables both its body and interaction shapes")
	stand_asset.enabled = true
	await process_frame
	await process_frame
	_check(stand_asset.get_node("Base").use_collision and not stand_asset.get_node("Slots/CollisionShape3D").disabled, "A stand restores both collision types")
	shell.menu.settings_requested.emit()
	_check(shell.settings.visible and not shell.menu.visible, "Settings replace menu input")
	shell.settings.get_node("%Sensitivity").value = 0.16
	_check(is_equal_approx(shell.room.rig.mouse_sensitivity, 0.16), "Sensitivity applies to the camera")
	await _press(&"ui_cancel")
	_check(shell.menu.visible and not shell.settings.visible, "Escape returns from settings")
	_check(root.gui_get_focus_owner() == shell.menu.get_node("%Settings"), "Settings focus is restored")
	await _observe_start_transition()
	_check(shell.dialogue.active and not shell.room.control_enabled, "Greeting owns player input")
	var greeting: Array = shell.dialogue._lines.duplicate(true)
	var previous_time_scale := Engine.time_scale
	Engine.time_scale = 0.0
	shell.dialogue.open(&"greeting", greeting)
	await process_frame
	await process_frame
	shell.dialogue._entrance.custom_step(0.1)
	_check(shell.dialogue.modulate.a > 0.0 and shell.dialogue.modulate.a < 1.0, "Dialogue fades in rather than appearing instantly")
	Engine.time_scale = previous_time_scale
	await _click(MOUSE_BUTTON_LEFT)
	_check(shell.dialogue._index == 0, "Interaction does not substitute for the bark action")
	await _press(&"bark")
	_check(shell.dialogue._index == 1, "Only Bark answers a bark request")
	await _press(&"ui_cancel")
	_check(paused and shell.pause.visible, "Escape pauses during a dialogue")
	shell.pause.settings_requested.emit()
	await _press(&"ui_cancel")
	_check(paused and shell.pause.visible, "Closing settings preserves pause")
	await _press(&"ui_cancel")
	_check(not paused and shell.dialogue.visible, "Resume restores the active dialogue")
	await _press(&"interact")
	_check(shell.room.step == LaikaRoom.Step.FETCH and shell.room.control_enabled, "Greeting starts the collection task")
	_check(shell.hud.objective.size.y > 0 and not shell.hud.objective.text.is_empty(), "The current objective occupies a visible text row")
	_check(_snout_in_frame(), "The existing snout is visible under the gameplay camera")
	await _jump()
	await _aim(Vector3(1.5, 0, 0.2), shell.room.get_node("Props/TrainingStand/TestButton").global_position)
	_check(_target_is(&"button"), "The test button is reachable from dog height")
	await _press(&"interact")
	_check(shell.room.step == LaikaRoom.Step.FETCH, "Pressing the button early is recoverable")
	await _aim(Vector3(-2.8, 0, 2.5), shell.room.get_node("Pickups/Battery1/Item").global_position)
	_check(_target_is(&"battery1"), "The first battery is reachable by raycast")
	var pickup_scale: Vector3 = shell.room.target.global_basis.get_scale()
	await _click(MOUSE_BUTTON_LEFT)
	_check(shell.room.carried != null, "LMB picks up a battery")
	_check(shell.room.carried.global_basis.get_scale().is_equal_approx(pickup_scale), "Picking up a battery preserves its physical scale")
	var held_position: Vector2 = shell.room.camera.unproject_position(shell.room.carried.global_position)
	var view_size: Vector2 = shell.room.camera.get_viewport().get_visible_rect().size
	_check(absf(held_position.x - view_size.x * 0.5) < view_size.x * 0.02 and held_position.y > view_size.y * 0.8 and held_position.y < view_size.y * 1.1, "The held battery sits centrally below the nose")
	await _click(MOUSE_BUTTON_RIGHT)
	_check(shell.room.carried == null and shell.room.get_node("Pickups/Battery1/Item").collision_layer == 2, "RMB puts the battery down safely")
	var dropped_mesh: MeshInstance3D = shell.room.get_node("Pickups/Battery1/Item/Cell")
	_check(dropped_mesh.layers == 1 and not dropped_mesh.material_override.no_depth_test, "A dropped battery restores its world rendering")
	_check(shell.room.get_node("Pickups/Battery1/Item").global_position.distance_to(shell.room.player.global_position) < 1.2, "Dropped batteries stay near the dog")
	await _aim(Vector3(-2.8, 0, 2.5), shell.room.get_node("Pickups/Battery1/Item").global_position)
	await _press(&"interact")
	var held_battery: Node = shell.room.carried
	await _aim(Vector3(2.65, 0, 1.8), shell.room.get_node("Pickups/Battery2/Item").global_position)
	await _click(MOUSE_BUTTON_LEFT)
	_check(_target_is(&"battery2") and shell.room.carried == held_battery, "LMB keeps the held battery when aiming at another pickup")
	_check(shell.hud.prompt.text.is_empty(), "A held item does not advertise a second LMB action")
	await _aim(Vector3(-2.8, 0, 2.5), Vector3(-2.8, 0, 1.5))
	await _click(MOUSE_BUTTON_LEFT)
	_check(shell.room.carried == held_battery, "LMB keeps the held battery when looking at empty floor")
	await _click(MOUSE_BUTTON_RIGHT)
	_check(shell.room.carried == null, "Only the dedicated put-down action releases the held item")
	await _aim(Vector3(-2.8, 0, 2.5), shell.room.get_node("Pickups/Battery1/Item").global_position)
	await _click(MOUSE_BUTTON_LEFT)
	_check(shell.room.carried != null, "A put-down item can be picked up again")
	await _aim(Vector3(0, 0, 0.3), shell.room.get_node("Props/TrainingStand/Slots").global_position)
	_check(_target_is(&"stand"), "The battery stand is reachable")
	await _click(MOUSE_BUTTON_LEFT)
	_check(shell.room.batteries == 1 and shell.room.carried == null, "The same LMB action installs the battery")
	var installed_mesh: MeshInstance3D = shell.room.get_node("Props/TrainingStand/Cell1")
	_check(installed_mesh.mesh.get_aabb().size.is_equal_approx(dropped_mesh.mesh.get_aabb().size), "Installed batteries retain the pickup dimensions")
	await _aim(Vector3(2.65, 0, 1.8), shell.room.get_node("Pickups/Battery2/Item").global_position)
	_check(_target_is(&"battery2"), "The second battery is reachable")
	await _press(&"interact")
	await _aim(Vector3(0, 0, 0.3), shell.room.get_node("Props/TrainingStand/Slots").global_position)
	await _press(&"interact")
	_check(shell.room.batteries == 2 and shell.room.step == LaikaRoom.Step.POWER, "Two batteries unlock the test")
	await _aim(Vector3(1.5, 0, 0.2), shell.room.get_node("Props/TrainingStand/TestButton").global_position)
	await _press(&"interact")
	_check(shell.dialogue.active, "The successful test opens the scientist's dialogue")
	await _press(&"bark")
	await _press(&"interact")
	_check(shell.room.step == LaikaRoom.Step.CAPSULE, "The scientist unlocks departure")
	await _aim(Vector3(1.5, 0, 0.2), shell.room.get_node("Props/TrainingStand/TestButton").global_position)
	await _press(&"interact")
	_check(not shell.dialogue.active and "Test complete" in shell.hud.thought.text, "Repeating a completed test does not ask for more batteries")
	_check(shell.room.batteries == 2 and shell.room.step == LaikaRoom.Step.CAPSULE and "capsule" in shell.hud.objective.text, "Repeating the button preserves batteries and the capsule objective")
	await _aim(Vector3(3.6, 0, -1.2), shell.room.get_node("Props/Capsule/Entry").global_position)
	_check(_target_is(&"capsule"), "The capsule can be entered from the front")
	await _press(&"interact")
	await _settle_transition()
	_check(shell.room.station and shell.dialogue.active, "Departure fades into station arrival")
	_check(_snout_in_frame(), "The snout remains visible on the station")
	_check(not shell.hud.thought_panel.visible, "Room transitions clear the previous thought")
	await _press(&"bark")
	await _press(&"interact")
	await _aim(Vector3(0, 0, 1.2), shell.room.get_node("Actors/Robot/Interaction").global_position)
	_check(_target_is(&"robot"), "The robot is reachable")
	await _press(&"interact")
	_check(shell.dialogue.active and shell.dialogue._dialogue_id == &"robot", "The robot has a separate speaker and dialogue")
	await _press(&"bark")
	_check(shell.dialogue._index == 1 and "Continue dialogue" in shell.dialogue.response.text, "Answering the robot clearly requests the next context action")
	await _press(&"bark")
	_check(shell.dialogue._index == 1 and "Woof!" in shell.dialogue.response.text, "A second bark visibly responds without skipping the robot's text")
	await _click(MOUSE_BUTTON_LEFT)
	_check(not shell.dialogue.active and shell.completion.visible and shell.room.control_enabled, "Finishing the robot shows a notice without blocking the player")
	_check(shell.hud.visible and shell.mode == shell.Mode.PLAYING and not paused, "The notice keeps the game and HUD active")
	_check(shell.room.step == LaikaRoom.Step.COMPLETE and shell.hud.objective.text == "Playground complete", "The old talk-to-robot objective is completed")
	await _press(&"bark")
	_check(shell.hud.thought_panel.visible and shell.hud.thought.text == "Woof!", "Barking still responds while exploring after completion")
	await _aim(Vector3(0, 0, 1.2), shell.room.get_node("Actors/Robot/Interaction").global_position)
	await _press(&"interact")
	_check(not shell.dialogue.active and shell.room.control_enabled, "Revisiting the robot after completion does not restart a blocking dialogue")
	await process_frame
	await process_frame
	await _click_at(shell.completion.get_node("%MainMenu").get_global_rect().get_center())
	await _settle_transition()
	_check(not paused and shell.menu.visible and not shell.dialogue.active, "Return to menu clears pause and dialogue")
	_check(not shell.completion.visible and shell.completion.get_node("%Lifetime").is_stopped(), "Leaving through the notice cancels its timer")
	await shell.start_game()
	_check(shell.room.batteries == 0 and shell.room.carried == null, "A new mission resets the room")
	await _press(&"bark")
	await _press(&"interact")
	var previous_focus: Control = root.gui_get_focus_owner()
	shell.completion.open()
	_check(root.gui_get_focus_owner() == previous_focus and shell.completion.get_node("%Lifetime").time_left > 4.9, "The notice lasts five seconds without stealing focus")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	shell.completion.get_node("%Lifetime").start(0.05)
	await create_timer(0.15, true, false, true).timeout
	await process_frame
	var mouse_look_restored := DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_check(not shell.completion.visible and shell.room.control_enabled and mouse_look_restored, "Notice expiry restores mouse look while keeping gameplay active")
	shell.pause_game()
	shell.completion.open()
	shell.completion.get_node("%Lifetime").start(0.05)
	await create_timer(0.15, true, false, true).timeout
	await process_frame
	_check(not shell.completion.visible and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Notice expiry does not close or capture the pause menu")
	await _press(&"ui_cancel")
	shell.queue_free()
	await process_frame
	await process_frame
	print("OPENING_FLOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


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
		_check(bounded, "Landing camera stays bounded with a %.3f second frame" % delta)
		_check(absf(rig._dip) < 0.002, "Landing camera settles with a %.3f second frame" % delta)
	rig._dip = 0.0
	rig._dip_velocity = 0.0
	rig._process(0.0)


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


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


func _target_is(id: StringName) -> bool:
	return is_instance_valid(shell.room.target) and shell.room.target.interaction_id == id


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
			input_blocked = input_blocked and not shell.room.control_enabled and not shell.dialogue.active
			if shell.fade.visible and shell.fade.modulate.a >= 0.999:
				if title_started < 0:
					title_started = Time.get_ticks_msec()
			else:
				if not saw_reveal:
					saw_reveal = true
					title_elapsed = Time.get_ticks_msec() - title_started
					reveal_transform = shell.room.camera.global_transform
				camera_stable = camera_stable and root.get_camera_3d() == shell.room.camera
				camera_stable = camera_stable and reveal_transform.is_equal_approx(shell.room.camera.global_transform)
				if not shell.fade.visible and revealed_at < 0:
					revealed_at = Time.get_ticks_msec()
		await process_frame
	_check(saw_reveal and camera_stable and root.get_camera_3d() == shell.room.camera and reveal_transform.is_equal_approx(shell.room.camera.global_transform), "The player camera is stable throughout reveal and greeting")
	_check(title_elapsed >= 1300, "The chapter title remains readable before revealing the room")
	_check(revealed_at >= 0 and Time.get_ticks_msec() - revealed_at >= 250, "The room appears before the greeting starts")
	_check(input_blocked and not shell.transitioning, "Input stays blocked until the opening transition finishes")


func _settle_transition() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while shell.transitioning and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not shell.transitioning, "Transition finishes within fifteen seconds")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _click(button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _click_at(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _jump() -> void:
	var baseline: float = shell.room.player.global_position.y
	var peak: float = 0.0
	var event := InputEventAction.new()
	event.action = &"Jump"
	event.pressed = true
	Input.parse_input_event(event)
	for frame in range(50):
		await physics_frame
		peak = maxf(peak, shell.room.player.global_position.y - baseline)
	event = InputEventAction.new()
	event.action = &"Jump"
	event.pressed = false
	Input.parse_input_event(event)
	_check(peak > 0.55 and peak < 0.85, "The dog jumps approximately 0.7 metres")


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
