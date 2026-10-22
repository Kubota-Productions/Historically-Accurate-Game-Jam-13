class_name GameShell
extends Node

enum Mode { MENU, PLAYING, PAUSED, CREDITS }

@export var first_room: RoomDefinition

var mode := Mode.MENU
var room: LaikaRoom
var transitioning: bool = false
var preferences := GameSettings.new()

@onready var audio: GameAudio = $Audio
@onready var transition: ScreenTransition = %ScreenTransition
@onready var world_host: Node3D = %WorldHost
@onready var projection: ScreenspaceProjection = %WorldPresentation
@onready var dog_vision: CanvasLayer = %DogVisionFilter
@onready var menu: MainMenu = %MainMenu
@onready var hud: GameHud = %HUD
@onready var dialogue: DialoguePanel = %Dialogue
@onready var pause: PauseMenu = %PauseMenu
@onready var settings: SettingsPanel = %SettingsPanel
@onready var credits: CreditsScreen = %Credits
@onready var completion: CompletionNotice = %CompletionNotice
@onready var inspection: ItemInspection = %ItemInspection


func _ready() -> void:
	preferences.restore(get_window())
	settings.setup(preferences)
	preferences.changed.connect(_apply_preferences)
	preferences.bindings.changed.connect(_apply_preferences)
	menu.start_requested.connect(start_game)
	menu.settings_requested.connect(open_settings)
	menu.quit_requested.connect(get_tree().quit)
	pause.resume_requested.connect(resume_game)
	pause.settings_requested.connect(open_settings)
	pause.menu_requested.connect(return_to_menu)
	settings.close_requested.connect(close_settings)
	completion.menu_requested.connect(return_to_menu)
	inspection.closed.connect(_inspection_closed)
	credits.finished.connect(return_to_menu)
	dialogue.session.finished.connect(_on_dialogue_finished)
	dialogue.session.line_changed.connect(_sync_context)
	dialogue.session.bark_requested.connect(_bark)
	_replace_room(first_room)
	_apply_preferences()
	menu.open()
	audio.set_menu_active(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if settings.visible and settings.consume_input(event):
		get_viewport().set_input_as_handled()
	elif inspection.visible:
		if inspection.consume_input(event):
			get_viewport().set_input_as_handled()
	elif transitioning:
		if event.is_pressed():
			get_viewport().set_input_as_handled()
	elif mode == Mode.CREDITS:
		if event.is_action_pressed(&"ui_cancel"):
			credits.finish()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()
	elif mode == Mode.PLAYING and not settings.visible and _play(event):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	hud.set_inspection_available(room.inspection_target() != null)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and mode == Mode.PLAYING and not transitioning and not inspection.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func start_game() -> void:
	await enter_room(first_room)


func pause_game() -> void:
	if mode != Mode.PLAYING or transitioning:
		return
	mode = Mode.PAUSED
	inspection.close()
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
	dialogue.visible = dialogue.session.active
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
	await transition.cover("")
	if not is_inside_tree():
		return
	get_tree().paused = false
	mode = Mode.MENU
	_hide_screens()
	_replace_room(first_room)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.open()
	audio.set_menu_active(true)
	await transition.reveal()
	if not is_inside_tree():
		return
	transitioning = false


func enter_room(definition: RoomDefinition) -> void:
	if transitioning:
		return
	transitioning = true
	audio.set_menu_active(false)
	room.set_control_enabled(false)
	await transition.cover(definition.title)
	if not is_inside_tree():
		return
	_hide_screens()
	if not _replace_room(definition):
		_cancel_transition()
		return
	mode = Mode.PLAYING
	hud.set_chapter(definition.heading)
	room.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await transition.reveal()
	await get_tree().create_timer(transition.intro_pause_seconds).timeout
	if not is_inside_tree():
		return
	hud.show()
	transitioning = false
	room.begin()
	_sync_context()


func _replace_room(definition: RoomDefinition) -> bool:
	inspection.close()
	var candidate := definition.instantiate()
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
	audio.bind_room(room)
	room.thought_requested.connect(hud.show_thought)
	room.sniffing_changed.connect(hud.set_sniffing)
	room.dialogue_requested.connect(_open_dialogue)
	room.departure_requested.connect(enter_room)
	room.completed.connect(finish_game)
	_apply_preferences()
	hud.reset()
	hud.get_node("%Jump").visible = room.movement_enabled
	return true


func finish_game() -> void:
	if transitioning or mode != Mode.PLAYING:
		return
	transitioning = true
	room.set_control_enabled(false)
	await transition.cover("")
	if not is_inside_tree():
		return
	_hide_screens()
	get_tree().paused = false
	mode = Mode.CREDITS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	credits.open()
	credits.set_process(false)
	credits.menu_button.disabled = true
	await transition.reveal()
	if is_inside_tree():
		transitioning = false
		credits.set_process(true)
		credits.menu_button.disabled = false


func _cancel_transition() -> void:
	transitioning = false
	mode = Mode.MENU
	get_tree().paused = false
	transition.clear()
	_hide_screens()
	menu.open()
	audio.set_menu_active(true)
	room.set_control_enabled(false)
	room.menu_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _hide_screens() -> void:
	inspection.close()
	credits.close()
	menu.hide()
	pause.hide()
	settings.hide()
	hud.hide()
	completion.close()
	dialogue.close()


func _cancel() -> void:
	if settings.visible:
		settings.handle_cancel()
	elif mode == Mode.PLAYING:
		pause_game()
	elif mode == Mode.PAUSED:
		resume_game()


func _play(event: InputEvent) -> bool:
	var session := dialogue.session
	if event.is_action_pressed(&"inspect") and not session.active:
		inspect_item()
	elif event.is_action_pressed(&"bark"):
		if session.requires_bark():
			session.advance(true)
		else:
			_bark()
			if session.active:
				dialogue.show_bark_feedback()
	elif event.is_action_pressed(&"interact"):
		if session.active:
			session.advance(false)
		else:
			room.interact()
	elif event.is_action_pressed(&"drop") and not session.active:
		room.drop()
	else:
		return false
	return true


func inspect_item() -> bool:
	if mode != Mode.PLAYING or transitioning or settings.visible or dialogue.session.active:
		return false
	var target := room.inspection_target()
	if target == null or not inspection.open(target):
		return false
	hud.hide()
	_sync_context()
	return true


func _inspection_closed() -> void:
	if mode == Mode.PLAYING and not transitioning and not settings.visible:
		hud.show()
	_sync_context()


func _bark() -> void:
#	hud.show_bark()
	if audio.profile:
		audio.play(audio.profile.bark, room.player)


func _open_dialogue(next: Dialogue) -> void:
	dialogue.open(next)
	_sync_context()


func _on_dialogue_finished(finished: Dialogue) -> void:
	room.progress.dialogue_finished(finished)
	_sync_context()


func _sync_context() -> void:
	var playing := mode == Mode.PLAYING and not transitioning and not settings.visible
	playing = playing and not inspection.visible
	room.set_control_enabled(playing)
	room.set_interactions_enabled(playing and not dialogue.session.active)
	hud.set_dialogue_active(dialogue.session.active, dialogue.session.requires_bark())


func _apply_preferences(_id: StringName = &"") -> void:
	audio.apply_settings(preferences)
	dog_vision.visible = preferences.get_value(&"dog_vision")
	projection.enabled = preferences.get_value(&"panini_projection")
	room.rig.mouse_sensitivity = preferences.get_value(&"sensitivity")
	hud.refresh_bindings()
	dialogue.refresh_bindings()
