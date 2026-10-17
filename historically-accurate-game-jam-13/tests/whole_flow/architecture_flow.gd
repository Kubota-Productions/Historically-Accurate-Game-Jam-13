extends SceneTree

class CounterAction extends InteractionAction:
	var count: int = 0

	func execute(_room: LaikaRoom, _target: LaikaInteractionPoint) -> void:
		count += 1

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var shell = load("res://Scenes/Game/Game.tscn").instantiate()
	root.add_child(shell)
	await process_frame
	await shell.start_game()
	var room: LaikaRoom = shell.room
	_check(room.control_enabled and not room.interactor.enabled, "Dialogue preserves movement and blocks world interactions")
	var before_walk := room.player.global_position
	var walk := InputEventAction.new()
	walk.action = &"forward"
	walk.pressed = true
	Input.parse_input_event(walk)
	for frame in 10:
		await physics_frame
	walk = InputEventAction.new()
	walk.action = &"forward"
	walk.pressed = false
	Input.parse_input_event(walk)
	_check(room.player.global_position.distance_to(before_walk) > 0.01 and shell.dialogue.active, "The player can actually walk while the conversation stays open")
	shell.dialogue.advance(true)
	shell.dialogue.advance(false)
	_check(room.interactor.enabled, "World interactions resume when dialogue finishes")

	var target := LaikaInteractionPoint.new()
	var action := CounterAction.new()
	target.action = action
	target.interaction_id = &"new_object_without_a_room_branch"
	room.add_child(target)
	room.interactor.target = target
	room.interact()
	_check(action.count == 1, "New interaction behavior works without changing the room")
	action.required_flag = &"custom_condition"
	room.interact()
	_check(action.count == 1, "Unmet authored conditions block activation")
	room.progress.set_flag(&"custom_condition", true)
	room.interact()
	_check(action.count == 2, "Meeting a condition enables the same interaction")
	target.hide()
	room.interact()
	_check(action.count == 2, "Hidden objects cannot be activated")

	var group := Node3D.new()
	group.scale = Vector3.ONE * 1.5
	room.add_child(group)
	var item := LaikaInteractionPoint.new()
	item.action = PickupAction.new()
	item.item_id = &"wrench"
	item.item_name = "wrench"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	item.add_child(mesh)
	item.add_child(shape)
	item.visual_root = mesh
	item.item_shape = shape
	group.add_child(item)
	var scale_before := item.global_basis.get_scale()
	room.interactor.target = item
	room.interact()
	_check(room.carry.item == item and item.global_basis.get_scale().is_equal_approx(scale_before), "A non-battery item can be carried without changing its size")
	var socket := ItemSocket.new()
	socket.capacity = 1
	room.add_child(socket)
	_check(not room.carry.store(socket) and room.carry.item == item, "A socket rejects the wrong item without dropping it")
	socket.accepted_item = &"wrench"
	_check(room.carry.store(socket) and socket.count == 1 and room.carry.item == null, "A socket accepts its configured item without room-specific code")
	_check(socket.is_full() and not socket.accepts(item), "A full socket cannot consume another item")

	var custom := SettingDefinition.new(&"invert_y", {"kind": SettingDefinition.Kind.TOGGLE, "section": &"input", "label": "Invert mouse Y", "default": false, "effect": [&"player", &"invert_y"]})
	var preferences := GameSettings.new()
	preferences.register(custom)
	preferences.register(SettingDefinition.new(&"test_choice", {"kind": SettingDefinition.Kind.CHOICE, "section": &"input", "label": "Test choice", "default": 0, "options": ["One", "Two"]}))
	preferences.initialize(root)
	var panel = load("res://Scenes/GUI/Screens/SettingsPanel.tscn").instantiate()
	panel.visible = false
	root.add_child(panel)
	panel.setup(preferences)
	panel.open()
	var choice: OptionButton = panel.row(&"test_choice").editor
	choice.item_selected.emit(1)
	_check(choice.item_count == 2 and preferences.get_value(&"test_choice") == 1, "New choice settings populate and apply from their definition")
	panel.row(&"invert_y").editor.button_pressed = true
	SettingsEffects.apply(preferences, {&"player": room.rig})
	_check(room.rig.invert_y and preferences.get_value(&"invert_y"), "One setting definition creates UI and applies the declared effect")
	preferences.save()
	var reloaded := GameSettings.new()
	reloaded.register(custom)
	reloaded.initialize(root)
	_check(reloaded.get_value(&"invert_y"), "A newly registered setting is saved and loaded automatically")
	preferences.set_value(&"sensitivity", NAN)
	_check(is_equal_approx(preferences.get_value(&"sensitivity"), 0.1), "Malformed numeric settings use their definition default")
	preferences.set_value(&"sensitivity", 10.0)
	_check(is_equal_approx(preferences.get_value(&"sensitivity"), 0.3), "Setting ranges are enforced by their definition")
	panel.queue_free()

	shell.preferences.set_value(&"panini_projection", true)
	_check(shell.projection.enabled, "Panini toggle drives the existing projection component")
	shell.preferences.save()
	var projection_reload := GameSettings.new()
	projection_reload.initialize(root)
	_check(projection_reload.get_value(&"panini_projection"), "Panini survives restarting settings")
	shell.preferences.set_value(&"panini_projection", false)
	_check(not shell.projection.enabled and room.is_inside_tree(), "Disabling Panini keeps the same room and camera")

	var session := DialogueSession.new()
	session.open(&"greeting", DialogueCatalog.lines(&"greeting"))
	session.advance(false)
	_check(session.index == 0, "Dialogue content enforces a bark response independently of UI")
	session.advance(true)
	_check(session.index == 1 and not session.requires_bark(), "Barking advances to the normal text line")
	session.advance(true)
	_check(session.index == 1, "A bark cannot skip a normal line")
	session.advance(false)
	_check(not session.active, "Dialogue completion is owned by the dialogue session")

	var motion: Node = room.camera.get_node("ViewModelMotion")
	var rest: Transform3D = motion.visual.transform
	var camera_rest := room.camera.global_transform
	room.camera.rotate_y(0.08)
	motion._process(1.0 / 60.0)
	_check(not motion.visual.basis.is_equal_approx(rest.basis) and motion.visual.position.is_equal_approx(rest.origin), "Turning adds snout lag without changing its authored position")
	room.camera.global_transform = camera_rest
	motion._process(0.5)
	_check(motion.visual.transform.is_equal_approx(rest), "A camera cut resets snout lag without an offset jump")

	var slow_trace := _sway_trace(30)
	var fast_trace := _sway_trace(144)
	_check(slow_trace.distance_to(fast_trace) < deg_to_rad(0.12), "Snout sway stays consistent across frame rates")

	var gaze: Node = room.get_node("Actors/Scientist/Gaze")
	var original_target: Node3D = gaze.target
	var gaze_target := Marker3D.new()
	room.add_child(gaze_target)
	gaze_target.global_position = gaze.head.global_position + Vector3(1, -0.5, -1)
	gaze.target = gaze_target
	var head_rest: Basis = gaze.head.basis
	var body_rest: Basis = gaze.torso.basis
	gaze._process(0.5)
	_check(not gaze.head.basis.is_equal_approx(head_rest) and not gaze.torso.basis.is_equal_approx(body_rest), "The scientist follows nearby targets with head and restrained torso movement")
	gaze_target.global_position += Vector3(20, 0, 0)
	gaze._process(2.0)
	_check(gaze.head.basis.is_equal_approx(head_rest), "The scientist returns to rest outside the follow range")
	gaze.target = original_target
	gaze_target.queue_free()

	_check(shell.transition.chapter_hold_seconds < 1.6, "Chapter transitions use the shorter configured hold")
	shell.queue_free()
	await process_frame
	await process_frame
	print("ARCHITECTURE_FLOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _sway_trace(fps: int) -> Vector2:
	var holder := Node3D.new()
	var camera := Camera3D.new()
	var visual := Node3D.new()
	holder.add_child(camera)
	holder.add_child(visual)
	var motion := Node.new()
	motion.set_script(load("res://Scenes/Player/Scripts/Components/viewmodel_sway.gd"))
	motion.camera = camera
	motion.visual = visual
	motion.render_as_viewmodel = false
	holder.add_child(motion)
	root.add_child(holder)
	var at_reverse := 0.0
	var largest_step := 0.0
	var previous := 0.0
	for frame: int in fps:
		var time := float(frame + 1) / fps
		var yaw := minf(time, 0.5 - time) * 120.0 if time <= 0.5 else 0.0
		camera.rotation.y = deg_to_rad(yaw)
		motion._process(1.0 / fps)
		var angle: float = motion._offset.y
		largest_step = maxf(largest_step, absf(angle - previous))
		previous = angle
		if frame + 1 == fps / 2:
			at_reverse = angle
	_check(largest_step <= deg_to_rad(0.8) * (1.0 - exp(-12.0 / fps)) * 2.01, "Direction changes remain smooth at %d FPS" % fps)
	_check(absf(previous) < deg_to_rad(0.01), "Snout settles after stopping at %d FPS" % fps)
	camera.rotation.y = PI - 0.001
	motion._process(0.5)
	camera.rotation.y = -PI + 0.002
	motion._process(1.0 / fps)
	_check(absf(motion._offset.y) > 0.000001 and absf(motion._offset.y) < deg_to_rad(0.2), "Yaw wrapping preserves a small continuous motion at %d FPS" % fps)
	holder.queue_free()
	return Vector2(at_reverse, previous)
