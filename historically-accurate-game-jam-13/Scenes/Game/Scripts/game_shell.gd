extends Node

enum Mode { MENU, PLAYING, PAUSED }

const DIALOGUE_PATH := "res://GameData/Dialogue/opening.json"
const FADE_OUT_SECONDS := 0.35
const FADE_IN_SECONDS := 0.65
const CHAPTER_HOLD_SECONDS := 1.6
const INTRO_PAUSE_SECONDS := 0.35

var mode: Mode = Mode.MENU
var room: LaikaRoom
var transitioning: bool = false
var preferences := GameSettings.new()
var _dialogues: Dictionary = {}
var _fade_tween: Tween

@onready var world_host: Node3D = $WorldHost
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
	_dialogues = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_PATH))
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
	completion.expired.connect(_on_completion_expired)
	completion.menu_requested.connect(return_to_menu)
	dialogue.finished.connect(_on_dialogue_finished)
	dialogue.line_changed.connect(func(waiting: bool) -> void: hud.set_dialogue_active(true, waiting))
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
	if completion.visible and event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if completion.is_menu_hit(event.position):
			return
		if event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	if event.is_action_pressed(&"bark"):
		_play_bark()
		room.bark()
	elif event.is_action_pressed(&"drop"):
		room.drop()
	elif event.is_action_pressed(&"interact"):
		room.interact()
	else:
		return
	get_viewport().set_input_as_handled()


func start_game() -> void:
	if transitioning:
		return
	transitioning = true
	await _cover("01  /  A VERY GOOD EMPLOYEE")
	if not is_inside_tree():
		return
	menu.hide()
	hud.hide()
	pause.hide()
	completion.close()
	settings.hide()
	dialogue.close()
	_replace_room(&"training")
	mode = Mode.PLAYING
	hud.set_chapter("01  /  EARTH · TRAINING ROOM")
	room.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _uncover()
	await get_tree().create_timer(INTRO_PAUSE_SECONDS).timeout
	if not is_inside_tree():
		return
	hud.show()
	transitioning = false
	room.begin()


func pause_game() -> void:
	mode = Mode.PAUSED
	get_tree().paused = true
	hud.hide()
	dialogue.hide()
	pause.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume_game() -> void:
	get_tree().paused = false
	mode = Mode.PLAYING
	pause.hide()
	hud.show()
	dialogue.visible = dialogue.active
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_completion_expired() -> void:
	if mode == Mode.PLAYING and not transitioning and not dialogue.active and not settings.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func open_settings() -> void:
	menu.hide()
	pause.hide()
	settings.open()


func close_settings() -> void:
	settings.close()
	if mode == Mode.MENU:
		menu.open()
		menu.focus_settings()
	else:
		pause.open()
		pause.focus_settings()


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


func _depart() -> void:
	if transitioning:
		return
	transitioning = true
	room.set_control_enabled(false)
	await _cover("02  /  SOMEONE ATE THE INSTRUCTIONS")
	if not is_inside_tree():
		return
	dialogue.close()
	hud.hide()
	_replace_room(&"station")
	hud.set_chapter("02  /  ORBIT · STATION")
	room.camera.make_current()
	await _uncover()
	await get_tree().create_timer(INTRO_PAUSE_SECONDS).timeout
	if not is_inside_tree():
		return
	hud.show()
	transitioning = false
	room.begin()


func _replace_room(id: StringName) -> void:
	if is_instance_valid(room):
		world_host.remove_child(room)
		room.queue_free()
	room = SceneCatalog.create_room(id)
	world_host.add_child(room)
	room.objective_changed.connect(hud.set_objective)
	room.prompt_changed.connect(hud.set_prompt)
	room.carrying_changed.connect(hud.set_carrying)
	room.thought_requested.connect(hud.show_thought)
	room.sniffing_changed.connect(hud.set_sniffing)
	room.dialogue_requested.connect(_open_dialogue)
	room.departure_requested.connect(_depart)
	room.rig.mouse_sensitivity = preferences.sensitivity
	hud.reset()


func _open_dialogue(id: StringName) -> void:
	if dialogue.active:
		return
	room.set_control_enabled(false)
	hud.set_dialogue_active(true)
	dialogue.open(id, _dialogues[str(id)].duplicate(true))


func _on_dialogue_finished(id: StringName) -> void:
	room.complete_dialogue(id)
	hud.set_dialogue_active(false)
	room.set_control_enabled(true)
	if id == &"robot":
		completion.open()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _play_bark() -> void:
	hud.show_thought("Woof!", 1.2)


func _cover(title: String) -> void:
	transition_title.text = title
	fade.modulate.a = 0.0
	fade.show()
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(fade, "modulate:a", 1.0, FADE_OUT_SECONDS).set_trans(Tween.TRANS_SINE)
	await _fade_tween.finished


func _uncover() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_interval(CHAPTER_HOLD_SECONDS if not transition_title.text.is_empty() else 0.15)
	_fade_tween.tween_property(fade, "modulate:a", 0.0, FADE_IN_SECONDS).set_trans(Tween.TRANS_SINE)
	await _fade_tween.finished
	if is_instance_valid(fade):
		fade.hide()


func _apply_preferences() -> void:
	dog_vision.visible = preferences.dog_vision
	if is_instance_valid(room):
		room.rig.mouse_sensitivity = preferences.sensitivity
	hud.refresh_bindings()
	dialogue.refresh_bindings()
