extends Control

signal close_requested

const ROW := preload("res://Scenes/GUI/Components/SettingRow.tscn")
const BINDING_ROW := preload("res://Scenes/GUI/Components/BindingRow.tscn")

var preferences: GameSettings
var _capture_action: StringName
var _draft: Dictionary = {}
var _rows: Dictionary[StringName, Control] = {}

@onready var tabs: TabContainer = %Tabs
@onready var binding_rows: VBoxContainer = %Bindings

var window_mode: OptionButton:
	get: return row(&"window_mode").editor
var resolution: OptionButton:
	get: return row(&"resolution").editor


func _ready() -> void:
	tabs.set_tab_title(0, tr("Video"))
	tabs.set_tab_title(1, tr("Audio"))
	tabs.set_tab_title(2, tr("Controls"))
	%Back.pressed.connect(func() -> void: close_requested.emit())
	%ApplyDisplay.pressed.connect(func() -> void: preferences.preview_display(_draft.window_mode, _draft.resolution))
	%KeepDisplay.pressed.connect(func() -> void: preferences.confirm_display())
	%RevertDisplay.pressed.connect(func() -> void: preferences.revert_display())
	%ResetBindings.pressed.connect(_reset_bindings)
	for action: StringName in PlayerBindings.ACTIONS:
		var binding: Control = BINDING_ROW.instantiate()
		binding.action = action
		binding_rows.add_child(binding)
		binding.binding_requested.connect(begin_capture)


func setup(settings: GameSettings) -> void:
	preferences = settings
	var groups := {&"display": %VideoRows, &"audio": %AudioRows, &"input": %ControlRows}
	for definition: SettingDefinition in preferences.definitions.values():
		var setting_row: Control = ROW.instantiate()
		setting_row.definition = definition
		groups[definition.section].add_child(setting_row)
		_rows[definition.id] = setting_row
		setting_row.value_changed.connect(_setting_changed)
	preferences.display_changed.connect(_populate_video)


func row(id: StringName) -> Control:
	return _rows[id]


func open() -> void:
	preferences.refresh_window_size()
	for id: StringName in _rows:
		if not preferences.definitions[id].confirmation:
			_rows[id].refresh(preferences.get_value(id))
	_populate_video()
	cancel_capture()
	tabs.current_tab = 0
	show()
	window_mode.grab_focus()


func close() -> void:
	cancel_capture()
	preferences.revert_display()
	preferences.save()
	hide()


func _process(_delta: float) -> void:
	if not visible or preferences == null or not preferences.display_pending:
		return
	preferences.tick_display()
	%DisplayCountdown.text = tr("Keep these display settings? Reverting in %d s.") % maxi(0, ceili((preferences.display_deadline - Time.get_ticks_msec()) / 1000.0))


func _setting_changed(id: StringName, value: Variant) -> void:
	if preferences.definitions[id].confirmation:
		_draft[id] = value
		_refresh_display_rows()
	else:
		preferences.set_value(id, value)


func _populate_video() -> void:
	_draft = {&"window_mode": preferences.window_mode, &"resolution": preferences.resolution}
	_refresh_display_rows()
	%DisplayConfirmation.visible = preferences.display_pending
	%ApplyDisplay.visible = not preferences.display_pending
	if visible and tabs.current_tab == 0:
		if preferences.display_pending:
			%KeepDisplay.grab_focus()
		else:
			window_mode.grab_focus()


func _refresh_display_rows() -> void:
	var modes: Array = []
	for index: int in preferences.definitions[&"window_mode"].options.size():
		modes.append([preferences.definitions[&"window_mode"].options[index], index])
	row(&"window_mode").refresh(_draft.window_mode, modes)
	var sizes: Array = []
	if _draft.window_mode == GameSettings.WindowMode.WINDOWED:
		for size: Vector2i in preferences.resolutions():
			sizes.append(["%d × %d" % [size.x, size.y], size])
	else:
		sizes.append([tr("Desktop resolution"), _draft.resolution])
	row(&"resolution").refresh(_draft.resolution, sizes)
	window_mode.disabled = preferences.display_pending
	resolution.disabled = _draft.window_mode != GameSettings.WindowMode.WINDOWED or preferences.display_pending
	%DisplayHint.text = tr("Changes need confirmation within 15 seconds.") if _draft.window_mode == GameSettings.WindowMode.WINDOWED else tr("Fullscreen modes use the desktop resolution.")
	var unchanged: bool = _draft.window_mode == preferences.window_mode and (_draft.resolution == preferences.resolution or _draft.window_mode != GameSettings.WindowMode.WINDOWED)
	%ApplyDisplay.disabled = preferences.display_pending or unchanged


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
	%BindingStatus.text = tr("Press a replacement key or mouse button. Esc cancels.")

func cancel_capture() -> void:
	_capture_action = &""
	_refresh_bindings()
	%BindingStatus.text = tr("Select a binding, then press a key or mouse button. Esc cancels.")

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
	%BindingStatus.text = tr("Binding updated.")

func _refresh_bindings() -> void:
	for row: Node in binding_rows.get_children():
		row.refresh()

func _reset_bindings() -> void:
	cancel_capture()
	preferences.bindings.reset()
	_refresh_bindings()
	%BindingStatus.text = tr("Default controls restored.")
