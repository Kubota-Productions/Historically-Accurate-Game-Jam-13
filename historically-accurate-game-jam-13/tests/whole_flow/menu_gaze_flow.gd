extends SceneTree

var menu: Control
var gaze: MenuGaze
var marker: Marker3D
var camera: Camera3D
var preview: TextureRect
var neutral: Vector3
var checks := 0
var failures := 0
var requests: Array[StringName] = []
var head_basis: Basis
var modifier_frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	menu = load("res://Scenes/GUI/Screens/MainMenu.tscn").instantiate()
	menu.theme = load("res://Resources/Themes/laika_theme.tres")
	var extra := Button.new()
	extra.name = "Extra"
	extra.text = "Extra"
	extra.custom_minimum_size.y = 76
	menu.get_node("Buttons").add_child(extra)
	marker = menu.get_node("3DsceneforMainmenu/LookAtTarget")
	neutral = marker.position
	root.add_child(menu)
	gaze = menu.get_node("MenuGaze")
	camera = gaze.preview_camera
	preview = gaze.preview
	var modifier: LookAtModifier3D = menu.get_node("3DsceneforMainmenu/Laika2/metarig/Skeleton3D/LookAtModifier3D")
	var skeleton := modifier.get_parent() as Skeleton3D
	modifier.modification_processed.connect(_record_head.bind(skeleton, modifier))
	menu.start_requested.connect(func() -> void: requests.append(&"start"))
	menu.settings_requested.connect(func() -> void: requests.append(&"settings"))
	menu.quit_requested.connect(func() -> void: requests.append(&"quit"))
	await process_frame
	await process_frame
	_check(preview.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The preview does not intercept mouse input")
	menu.open()
	await _move_mouse(Vector2(1700, 80))
	await _settle()
	_check(_aims_at(menu.get_node("%Start")), "Opening follows the default Start focus")
	var start_head := head_basis
	await _key(KEY_TAB)
	await _settle()
	_check(root.gui_get_focus_owner() == menu.get_node("%Settings") and _aims_at(menu.get_node("%Settings")), "Tab navigation moves the gaze to Settings")
	await _hover(menu.get_node("%Quit"))
	await _settle()
	_check(root.gui_get_focus_owner() == menu.get_node("%Settings") and _aims_at(menu.get_node("%Quit")), "Mouse hover takes priority over keyboard focus")
	_check(modifier_frames > 0 and not start_head.is_equal_approx(head_basis), "The existing modifier rotates the head between buttons")
	await _move_mouse(Vector2(1700, 80))
	await _settle()
	_check(_aims_at(menu.get_node("%Settings")), "Leaving a button restores the focused target")
	await _hover(extra)
	await _settle()
	_check(_aims_at(extra), "An additional button is connected without another handler")
	extra.disabled = true
	await _settle()
	_check(_aims_at(menu.get_node("%Settings")), "Disabled buttons do not capture the gaze")
	await _move_mouse(Vector2(1700, 80))
	menu.get_node("%Settings").release_focus()
	await _settle()
	_check(marker.position.distance_to(neutral) < 0.0001, "Without hover or focus the authored marker position is restored")
	menu.open()
	await _hover(menu.get_node("%Settings"))
	await _settle()
	_click(menu.get_node("%Settings"))
	_check(requests == [&"settings"], "Settings emits its action immediately on click")
	menu.hide()
	_check(not gaze.is_processing() and marker.position.is_equal_approx(neutral), "Hiding the menu stops gaze updates and resets the marker")
	menu.open()
	menu.focus_settings()
	await _move_mouse(Vector2(1700, 80))
	await _settle()
	_check(_aims_at(menu.get_node("%Settings")), "Returning from Settings follows the restored focus")
	for size: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1280, 800)]:
		root.size = size
		await process_frame
		await process_frame
		for name: String in ["Start", "Settings", "Quit"]:
			menu.get_node("%" + name).grab_focus()
			await _settle()
			_check(_aims_at(menu.get_node("%" + name)), "%s remains aligned at %s" % [name, size])
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	gaze.set_process(false)
	var positions: Array[Vector3] = []
	menu.get_node("%Quit").grab_focus()
	for fps: int in [30, 60, 144]:
		marker.position = neutral
		for frame: int in fps / 2:
			gaze._process(1.0 / fps)
		positions.append(marker.position)
	_check(positions[0].distance_to(positions[1]) < 0.0001 and positions[0].distance_to(positions[2]) < 0.0001, "Smoothing has the same response at 30, 60 and 144 FPS")
	gaze.set_process(true)
	_click(menu.get_node("%Start"))
	_check(requests.back() == &"start", "Start does not wait for the gaze animation")
	_click(menu.get_node("%Quit"))
	_check(requests.back() == &"quit", "Exit does not wait for the gaze animation")
	menu.queue_free()
	await process_frame
	await process_frame
	print("MENU_GAZE_FLOW: %d checks, %d failures (%s)" % [checks, failures, DisplayServer.get_name()])
	quit(0 if failures == 0 else 1)


func _record_head(skeleton: Skeleton3D, modifier: LookAtModifier3D) -> void:
	head_basis = skeleton.get_bone_global_pose(modifier.bone).basis
	modifier_frames += 1


func _aims_at(button: BaseButton) -> bool:
	var projected := camera.unproject_position(marker.global_position)
	var actual := preview.get_global_transform_with_canvas() * projected
	var authored := preview.get_global_transform_with_canvas() * camera.unproject_position(marker.get_parent_node_3d().to_global(neutral))
	var center := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var reference := gaze.button_container.get_global_transform_with_canvas() * (gaze.button_container.size * 0.5)
	var expected := authored + (center - reference) * gaze.gaze_strength
	return actual.distance_to(expected) < 2.0


func _hover(button: BaseButton) -> void:
	await _move_mouse(button.get_global_transform_with_canvas() * (button.size * 0.5))


func _move_mouse(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	root.push_input(event, true)
	await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _click(button: BaseButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_transform_with_canvas() * (button.size * 0.5)
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)


func _settle() -> void:
	var elapsed := 0.0
	var deadline := Time.get_ticks_msec() + 15000
	while elapsed < 0.8 and Time.get_ticks_msec() < deadline:
		await process_frame
		elapsed += menu.get_process_delta_time()
	await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
