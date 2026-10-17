extends Node

enum Mode { MENU, PLAYING, PAUSED }

var mode: Mode = Mode.MENU
var room: LaikaRoom
var transitioning: bool = false
var preferences := GameSettings.new()
var _world_actions: Dictionary[StringName, Callable] = {}

@onready var transition: Node = $ScreenTransition
@onready var world_host: Node3D = %WorldHost
@onready var projection: Node3D = $WorldPresentation
@onready var dog_vision: CanvasLayer = $DogVisionFilter
@onready var menu = %MainMenu
@onready var hud = %HUD
@onready var dialogue = %Dialogue
@onready var pause = %PauseMenu
@onready var settings = %SettingsPanel
@onready var completion = %CompletionNotice
@onready var fade: ColorRect = %Fade
@onready var transition_title: Label = %TransitionTitle


func _ready() -> void:
	preferences.initialize(get_window())
	settings.setup(preferences)
	preferences.changed.connect(_apply_preferences)
	preferences.bindings.changed.connect(_apply_preferences)
	menu.start_requested.connect(start_game)
	menu.settings_requested.connect(open_settings)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	pause.resume_requested.connect(resume_game)
	pause.settings_requested.connect(open_settings)
	pause.menu_requested.connect(return_to_menu)
	settings.close_requested.connect(close_settings)
	completion.menu_requested.connect(return_to_menu)
	dialogue.finished.connect(_on_dialogue_finished)
	dialogue.line_changed.connect(func(_waiting: bool) -> void: _sync_context())
	dialogue.bark_requested.connect(_play_bark)
	_replace_room(&"training")
	_apply_preferences()
	fade.hide()
	menu.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if settings.visible and settings.consume_input(event):
		get_viewport().set_input_as_handled()
		return
	if transitioning:
		if event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		if settings.visible:
			if preferences.display_pending:
				preferences.revert_display()
			else:
				close_settings()
		elif mode == Mode.PLAYING:
			pause_game()
		elif mode == Mode.PAUSED:
			resume_game()
		get_viewport().set_input_as_handled()
		return
	if mode != Mode.PLAYING or settings.visible:
		return
	if dialogue.active:
		if event.is_action_pressed(&"bark"):
			if dialogue.requires_bark():
				dialogue.advance(true)
			else:
				_play_bark()
				dialogue.show_bark_feedback()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"interact"):
			dialogue.advance(false)
			get_viewport().set_input_as_handled()
		return
	for action: StringName in _world_actions:
		if event.is_action_pressed(action):
			_world_actions[action].call()
			get_viewport().set_input_as_handled()
			return


func start_game() -> void:
	if transitioning:
		return
	transitioning = true
	await _cover(SceneCatalog.ROOMS[&"training"].title)
	if not is_inside_tree():
		return
	menu.hide()
	hud.hide()
	pause.hide()
	completion.close()
	settings.hide()
	dialogue.close()
	if not _replace_room(&"training"):
		_cancel_transition()
		return
	mode = Mode.PLAYING
	hud.set_chapter(SceneCatalog.ROOMS[&"training"].heading)
	room.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _uncover()
	await get_tree().create_timer(transition.intro_pause_seconds).timeout
	if not is_inside_tree():
		return
	hud.show()
	transitioning = false
	room.begin()
	_sync_context()


func pause_game() -> void:
	mode = Mode.PAUSED
	get_tree().paused = true
	hud.hide()
	dialogue.hide()
	pause.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sync_context()


func resume_game() -> void:
	get_tree().paused = false
	mode = Mode.PLAYING
	pause.hide()
	hud.show()
	dialogue.visible = dialogue.active
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_sync_context()


func open_settings() -> void:
	menu.hide()
	pause.hide()
	settings.open()
	_sync_context()


func close_settings() -> void:
	settings.close()
	if mode == Mode.MENU:
		menu.open()
		menu.focus_settings()
	else:
		pause.open()
		pause.focus_settings()
	_sync_context()


func return_to_menu() -> void:
	if transitioning:
		return
	transitioning = true
	await _cover("")
	if not is_inside_tree():
		return
	get_tree().paused = false
	mode = Mode.MENU
	pause.hide()
	completion.close()
	settings.hide()
	hud.hide()
	dialogue.close()
	_replace_room(&"training")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.open()
	await _uncover()
	if is_inside_tree():
		transitioning = false


func _depart(destination: StringName = &"station") -> void:
	if transitioning or not SceneCatalog.ROOMS.has(destination):
		return
	transitioning = true
	room.set_control_enabled(false)
	await _cover(SceneCatalog.ROOMS[destination].title)
	if not is_inside_tree():
		return
	dialogue.close()
	hud.hide()
	if not _replace_room(destination):
		_cancel_transition()
		return
	hud.set_chapter(SceneCatalog.ROOMS[destination].heading)
	room.camera.make_current()
	await _uncover()
	await get_tree().create_timer(transition.intro_pause_seconds).timeout
	if not is_inside_tree():
		return
	hud.show()
	transitioning = false
	room.begin()
	_sync_context()


func _replace_room(id: StringName) -> bool:
	var candidate := SceneCatalog.create_room(id)
	if candidate == null:
		return false
	world_host.add_child(candidate)
	if not candidate.configured:
		world_host.remove_child(candidate)
		candidate.queue_free()
		return false
	if is_instance_valid(room):
		world_host.remove_child(room)
		room.queue_free()
	room = candidate
	room.objective_changed.connect(hud.set_objective)
	room.prompt_changed.connect(hud.set_prompt)
	room.carrying_changed.connect(hud.set_carrying)
	room.thought_requested.connect(hud.show_thought)
	room.sniffing_changed.connect(hud.set_sniffing)
	room.dialogue_requested.connect(_open_dialogue)
	room.departure_requested.connect(_depart)
	room.completed.connect(_on_room_completed)
	_world_actions = {&"bark": _play_bark, &"drop": room.drop, &"interact": room.interact}
	_apply_preferences()
	hud.reset()

	return true


func _open_dialogue(id: StringName) -> bool:
	if dialogue.active:
		return false
	var lines := DialogueCatalog.lines(id)
	var opened: bool = not lines.is_empty() and dialogue.open(id, lines)
	_sync_context()
	return opened


func _on_dialogue_finished(id: StringName) -> void:
	room.complete_dialogue(id)
	_sync_context()


func _sync_context() -> void:
	if not is_instance_valid(room):
		return
	var playing: bool = mode == Mode.PLAYING and not transitioning and not settings.visible
	room.set_interactions_enabled(playing and not dialogue.active)
	hud.set_dialogue_active(dialogue.active, dialogue.requires_bark())


func _on_room_completed() -> void:
	completion.open()


func _play_bark() -> void:
	hud.show_thought("Woof!", 1.2)


func _cover(title: String) -> void:
	await transition.cover(title)


func _uncover() -> void:
	await transition.reveal()


func _apply_preferences() -> void:
	SettingsEffects.apply(preferences, {&"dog_vision": dog_vision, &"projection": projection, &"player": room.rig if is_instance_valid(room) else null})
	hud.refresh_bindings()
	dialogue.refresh_bindings()


func _cancel_transition() -> void:
	transitioning = false
	mode = Mode.MENU
	get_tree().paused = false
	fade.hide()
	hud.hide()
	dialogue.close()
	menu.open()
	if is_instance_valid(room) and room.configured:
		room.set_control_enabled(false)
		room.menu_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
