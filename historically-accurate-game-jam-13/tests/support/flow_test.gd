extends SceneTree

const GAME_SCENE := preload("res://Scenes/Game/Game.tscn")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await run()
	await frames(2)
	var label: String = get_script().resource_path.get_file().get_basename().to_upper()
	print("%s: %d checks, %d failures (%s)" % [label, checks, failures, DisplayServer.get_name()])
	quit(1 if failures else 0)


func run() -> void:
	pass


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func boot_shell() -> GameShell:
	root.size = Vector2i(1280, 720)
	var shell: GameShell = GAME_SCENE.instantiate()
	root.add_child(shell)
	await process_frame
	return shell


func frames(count: int) -> void:
	for frame: int in count:
		await process_frame


func press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func click(button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func click_at(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func wait_for(condition: Callable, seconds: float = 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return condition.call()


func click_on(control: Control) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_transform_with_canvas() * (control.size * 0.5)
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
