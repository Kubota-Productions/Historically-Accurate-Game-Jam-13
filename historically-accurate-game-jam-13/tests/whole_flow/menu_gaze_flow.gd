extends "res://tests/support/flow_test.gd"

var menu: MainMenu
var gaze: MenuGaze
var skeleton: Skeleton3D
var modifier: LookAtModifier3D
var neutral: Vector3
var head_basis: Basis
var requests: Array[StringName] = []


func run() -> void:
	menu = load("res://Scenes/GUI/Screens/MainMenu.tscn").instantiate()
	gaze = menu.get_node("MenuGaze")
	skeleton = menu.get_node("3DsceneforMainmenu/Laika2/metarig/Skeleton3D")
	modifier = skeleton.get_node("LookAtModifier3D")
	var source: Node = load("res://Assets/3D/Laika.blend").instantiate()
	var source_skeleton: Skeleton3D = source.get_node("metarig/Skeleton3D")
	var matches_source := skeleton.get_bone_count() == source_skeleton.get_bone_count()
	for bone: int in skeleton.get_bone_count():
		matches_source = matches_source and skeleton.get_bone_pose(bone).is_equal_approx(source_skeleton.get_bone_pose(bone))
	check(matches_source, "Menu inherits the current model pose without stale bone overrides")
	source.free()
	check(modifier.bone == skeleton.find_bone(modifier.bone_name), "Look-at targets the named head bone in the current rig")
	neutral = gaze.look_target.position
	root.add_child(menu)
	modifier.modification_processed.connect(func() -> void: head_basis = skeleton.get_bone_global_pose(modifier.bone).basis)
	menu.start_requested.connect(func() -> void: requests.append(&"start"))
	menu.settings_requested.connect(func() -> void: requests.append(&"settings"))
	menu.quit_requested.connect(func() -> void: requests.append(&"quit"))
	await frames(2)
	menu.open()
	check(gaze.preview.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Preview does not intercept button input")
	for size: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1280, 800)]:
		root.size = size
		await frames(2)
		await _point_at(Vector2(size) * Vector2(0.15, 0.25))
		var left := head_basis
		await _point_at(Vector2(size) * Vector2(0.85, 0.75))
		check(head_basis.is_finite() and not head_basis.is_equal_approx(left), "Head follows the cursor at %s" % size)
	menu.hide()
	check(not gaze.is_processing() and gaze.look_target.position.is_equal_approx(neutral), "Hidden menu resets gaze and stops processing")
	menu.open()
	menu.focus_settings()
	await _point_at(Vector2(300, 300))
	check(gaze.is_processing() and root.gui_get_focus_owner() == menu.get_node("%Settings"), "Returning to menu preserves Settings focus and resumes gaze")
	for entry: Array in [["Start", &"start"], ["Settings", &"settings"], ["Quit", &"quit"]]:
		click_on(menu.get_node("%" + entry[0]))
		check(requests.back() == entry[1], "%s responds without waiting for gaze" % entry[0])
	gaze.set_process(false)
	var positions: Array[Vector3] = []
	for fps: int in [30, 60, 144]:
		gaze.look_target.position = neutral
		for frame: int in fps:
			gaze._process(1.0 / fps)
		positions.append(gaze.look_target.position)
	check(positions[0].distance_to(positions[1]) < 0.0001 and positions[0].distance_to(positions[2]) < 0.0001, "Gaze smoothing is independent of frame rate")
	menu.queue_free()
	await frames(2)


func _point_at(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	root.push_input(event, true)
	await process_frame
	gaze.set_process(false)
	for frame: int in 120:
		gaze._process(1.0 / 60.0)
	await create_timer(1.1).timeout
	gaze.set_process(true)
