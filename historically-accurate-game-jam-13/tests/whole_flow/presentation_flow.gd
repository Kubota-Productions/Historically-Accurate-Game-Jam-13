extends "res://tests/support/flow_test.gd"


func run() -> void:
	var shell := await boot_shell()
	await shell.start_game()
	var room := shell.room
	_catalog_rows_appear()
	_projection_follows_its_toggle(shell.projection)
	var motion: ViewmodelSway = room.camera.get_node("ViewModelMotion")
	var rest: Transform3D = motion.visual.transform
	var camera_rest := room.camera.global_transform
	room.camera.rotate_y(0.08)
	motion._process(1.0 / 60.0)
	check(not motion.visual.basis.is_equal_approx(rest.basis) and motion.visual.position.is_equal_approx(rest.origin), "Turning adds snout lag without changing its authored position")
	room.camera.global_transform = camera_rest
	motion._process(0.5)
	check(motion.visual.transform.is_equal_approx(rest), "A camera cut resets snout lag without an offset jump")

	var slow_trace := _sway_trace(30)
	var fast_trace := _sway_trace(144)
	check(slow_trace.distance_to(fast_trace) < deg_to_rad(0.12), "Snout sway stays consistent across frame rates")

	var gaze: NpcGaze = room.get_node("Actors/Scientist/Gaze")
	var original_target: Node3D = gaze.target
	var gaze_target := Marker3D.new()
	room.add_child(gaze_target)
	gaze_target.global_position = gaze.look_at.global_position + Vector3(1, 0, 0)
	gaze.target = gaze_target
	gaze._process(0.5)
	check(gaze.look_at.influence > 0.9, "The scientist follows a nearby target through the authored LookAtModifier")
	gaze_target.global_position += Vector3(20, 0, 0)
	gaze._process(2.0)
	check(is_zero_approx(gaze.look_at.influence), "The scientist returns to rest outside the follow range")
	gaze.target = original_target
	gaze_target.queue_free()

	shell.queue_free()


func _projection_follows_its_toggle(projection: ScreenspaceProjection) -> void:
	projection.enabled = true
	check(projection.viewport.size == Vector2i(Vector2(root.size) * projection.upscale), "Projection renders the world at its upscale")
	check(projection.material.get_shader_parameter(&"enabled"), "Projection enables its shader")
	projection.enabled = false
	check(projection.viewport.size == root.size and not projection.material.get_shader_parameter(&"enabled"), "Disabled projection renders at window size")
	root.size = Vector2i(1024, 600)
	check(projection.viewport.size == root.size, "Projection follows window resizes")
	root.size = Vector2i(1280, 720)


func _catalog_rows_appear() -> void:
	var choice := ChoiceSetting.new()
	choice.id = &"test_choice"
	choice.label = "Test choice"
	choice.options = ["One", "Two"]
	var catalog := SettingsCatalog.new()
	catalog.settings.append(choice)
	var preferences := GameSettings.new(catalog)
	var panel: SettingsPanel = load("res://Scenes/GUI/Screens/SettingsPanel.tscn").instantiate()
	panel.visible = false
	root.add_child(panel)
	panel.setup(preferences)
	panel.open()
	var editor: OptionButton = panel.row(&"test_choice").editor
	editor.item_selected.emit(1)
	check(editor.item_count == 2 and preferences.get_value(&"test_choice") == 1, "A new catalog entry creates its row and applies its value")
	check(panel.row(&"test_choice").get_parent() == panel.get_node("%VideoRows"), "Rows appear in their section")
	panel.free()


func _sway_trace(fps: int) -> Vector2:
	var holder := Node3D.new()
	var camera := Camera3D.new()
	var visual := Node3D.new()
	holder.add_child(camera)
	holder.add_child(visual)
	var motion := ViewmodelSway.new()
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
		var angle: float = motion.offset.y
		largest_step = maxf(largest_step, absf(angle - previous))
		previous = angle
		if frame + 1 == fps >> 1:
			at_reverse = angle
	check(largest_step <= deg_to_rad(0.8) * (1.0 - exp(-12.0 / fps)) * 2.01, "Direction changes remain smooth at %d FPS" % fps)
	check(absf(previous) < deg_to_rad(0.01), "Snout settles after stopping at %d FPS" % fps)
	camera.rotation.y = PI - 0.001
	motion._process(0.5)
	camera.rotation.y = -PI + 0.002
	motion._process(1.0 / fps)
	check(absf(motion.offset.y) > 0.000001 and absf(motion.offset.y) < deg_to_rad(0.2), "Yaw wrapping preserves a small continuous motion at %d FPS" % fps)
	holder.queue_free()
	return Vector2(at_reverse, previous)
