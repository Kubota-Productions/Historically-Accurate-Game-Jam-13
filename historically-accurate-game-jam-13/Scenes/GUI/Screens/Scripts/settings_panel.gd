extends Control

signal close_requested

var preferences: GameSettings
var _capture_action: StringName
var _draft_resolution: Vector2i
var _sizes: Array[Vector2i] = []

@onready var tabs: TabContainer = %Tabs
@onready var sound: HSlider = %SoundVolume
@onready var music: HSlider = %MusicVolume
@onready var sensitivity: HSlider = %Sensitivity
@onready var window_mode: OptionButton = %WindowMode
@onready var resolution: OptionButton = %Resolution
@onready var dog_vision: CheckButton = %DogVision
@onready var panini_projection: CheckButton =%PaniniProjection
@onready var binding_rows: VBoxContainer = %Bindings


func _ready() -> void:
	%Back.pressed.connect(func() -> void: close_requested.emit())
	sound.value_changed.connect(_audio_changed)
	music.value_changed.connect(_audio_changed)
	sensitivity.value_changed.connect(_sensitivity_changed)
	window_mode.item_selected.connect(func(_index: int) -> void: _populate_resolutions())
	resolution.item_selected.connect(_resolution_selected)
	dog_vision.toggled.connect(func(enabled: bool) -> void: preferences.set_dog_vision(enabled))
	panini_projection.toggled.connect(func(enabled: bool) -> void: preferences.set_panini_projection(enabled))
	%ApplyDisplay.pressed.connect(func() -> void: preferences.preview_display(window_mode.selected, _draft_resolution))
	%KeepDisplay.pressed.connect(func() -> void: preferences.confirm_display())
	%RevertDisplay.pressed.connect(func() -> void: preferences.revert_display())
	%ResetBindings.pressed.connect(_reset_bindings)
	for row: Node in binding_rows.get_children():
		row.binding_requested.connect(begin_capture)


func _process(_delta: float) -> void:
	if not visible or preferences == null or not preferences.display_pending:
		return
	preferences.tick_display()
	%DisplayCountdown.text = "Keep these display settings? Reverting in %d s." % maxi(0, ceili((preferences.display_deadline - Time.get_ticks_msec()) / 1000.0))


func setup(settings: GameSettings) -> void:
	preferences = settings
	preferences.display_changed.connect(_populate_video)


func open() -> void:
	preferences.refresh_window_size()
	sound.set_value_no_signal(preferences.sound_volume)
	music.set_value_no_signal(preferences.music_volume)
	sensitivity.set_value_no_signal(preferences.sensitivity)
	_update_values()
	_populate_video()
	_refresh_bindings()
	%BindingStatus.text = "Select a binding, then press a key or mouse button. Esc cancels."
	tabs.current_tab = 0
	show()
	window_mode.grab_focus()


func close() -> void:
	cancel_capture()
	preferences.revert_display()
	preferences.save()
	hide()

func consume_input(event: InputEvent) -> bool:
	if _capture_action.is_empty():
		return false
	if not event.is_pressed():
		return true
	if event is InputEventKey:
		if event.echo:
			return true
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			cancel_capture()
			return true
		var key := InputEventKey.new()
		key.physical_keycode = event.physical_keycode if event.physical_keycode else event.keycode
		_apply_binding(key)
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = event.button_index
			_apply_binding(mouse)
	return true

func begin_capture(action: StringName) -> void:
	cancel_capture()
	_capture_action = action
	for row: Node in binding_rows.get_children():
		if row.action == action:
			row.show_capture()
	%BindingStatus.text = "Press a replacement key or mouse button. Esc cancels."

func cancel_capture() -> void:
	_capture_action = &""
	_refresh_bindings()
	%BindingStatus.text = "Select a binding, then press a key or mouse button. Esc cancels."

func _apply_binding(event: InputEvent) -> void:
	var result := preferences.bindings.assign(_capture_action, event)
	if not result.is_empty():
		%BindingStatus.text = result
		return
	var action := _capture_action
	_capture_action = &""
	_refresh_bindings()
	for row: Node in binding_rows.get_children():
		if row.action == action:
			row.focus_binding()
	%BindingStatus.text = "Binding updated."

func _refresh_bindings() -> void:
	for row: Node in binding_rows.get_children():
		row.refresh()

func _reset_bindings() -> void:
	cancel_capture()
	preferences.bindings.reset()
	_refresh_bindings()
	%BindingStatus.text = "Default controls restored."


func _audio_changed(_value: float) -> void:
	preferences.set_audio(sound.value, music.value)
	_update_values()


func _sensitivity_changed(value: float) -> void:
	preferences.set_sensitivity(value)
	_update_values()


func _update_values() -> void:
	%SoundValue.text = "%d%%" % roundi(sound.value * 100.0)
	%MusicValue.text = "%d%%" % roundi(music.value * 100.0)
	%SensitivityValue.text = "%.2f" % sensitivity.value


func _populate_video() -> void:
	dog_vision.set_pressed_no_signal(preferences.dog_vision)
	panini_projection.set_pressed_no_signal(preferences.panini_projection)
	window_mode.select(preferences.window_mode)
	_draft_resolution = preferences.resolution
	_populate_resolutions()
	%DisplayConfirmation.visible = preferences.display_pending
	%ApplyDisplay.visible = not preferences.display_pending
	window_mode.disabled = preferences.display_pending
	if visible and tabs.current_tab == 0:
		if preferences.display_pending:
			%KeepDisplay.grab_focus()
		else:
			window_mode.grab_focus()


func _populate_resolutions() -> void:
	_sizes = preferences.resolutions()
	resolution.clear()
	if window_mode.selected == GameSettings.WindowMode.WINDOWED:
		for size: Vector2i in _sizes:
			resolution.add_item("%d × %d" % [size.x, size.y])
		resolution.select(maxi(0, _sizes.find(_draft_resolution)))
		%DisplayHint.text = "Changes need confirmation within 15 seconds."
	else:
		resolution.add_item("Desktop resolution")
		%DisplayHint.text = "Fullscreen modes use the desktop resolution."
	resolution.disabled = window_mode.selected != GameSettings.WindowMode.WINDOWED or preferences.display_pending
	_update_display_apply()

func _resolution_selected(index: int) -> void:
	_draft_resolution = _sizes[index]
	_update_display_apply()

func _update_display_apply() -> void:
	var same_size := _draft_resolution == preferences.resolution or window_mode.selected != GameSettings.WindowMode.WINDOWED
	%ApplyDisplay.disabled = preferences.display_pending or (window_mode.selected == preferences.window_mode and same_size)
