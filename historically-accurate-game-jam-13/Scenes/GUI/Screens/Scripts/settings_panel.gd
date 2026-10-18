@tool
class_name SettingsPanel
extends Control

signal close_requested

const SLIDER_ROW := preload("res://Scenes/GUI/Components/SliderRow.tscn")
const TOGGLE_ROW := preload("res://Scenes/GUI/Components/ToggleRow.tscn")
const CHOICE_ROW := preload("res://Scenes/GUI/Components/ChoiceRow.tscn")
const BINDING_ROW := preload("res://Scenes/GUI/Components/BindingRow.tscn")
const WINDOWED := DisplaySettings.WindowMode.WINDOWED

var preferences: GameSettings
var _rows: Dictionary[StringName, SettingRow] = {}
var _binding_rows: Dictionary[StringName, BindingRow] = {}
var _capture_action: StringName
var _draft_mode := WINDOWED
var _draft_size: Vector2i

@onready var tabs: TabContainer = %Tabs
@onready var window_mode: OptionButton = %WindowMode
@onready var resolution: OptionButton = %Resolution
@onready var revert_timer: Timer = %RevertTimer
@onready var binding_status: Label = %BindingStatus
@onready var _sections: Dictionary[SettingDefinition.Section, Container] = {
	SettingDefinition.Section.VIDEO: %VideoRows,
	SettingDefinition.Section.AUDIO: %AudioRows,
	SettingDefinition.Section.CONTROLS: %ControlRows,
}


func _ready() -> void:
	tabs.set_tab_title(0, tr("Video"))
	tabs.set_tab_title(1, tr("Audio"))
	tabs.set_tab_title(2, tr("Controls"))
	for action: StringName in PlayerBindings.ACTIONS:
		var binding: BindingRow = BINDING_ROW.instantiate()
		binding.action = action
		%Bindings.add_child(binding)
		_binding_rows[action] = binding
		binding.binding_requested.connect(begin_capture)
	if Engine.is_editor_hint():
		for definition: SettingDefinition in GameSettings.CATALOG.settings:
			_add_row(definition).show_value(definition.get_default())
		for mode: DisplaySettings.WindowMode in DisplaySettings.MODE_LABELS:
			window_mode.add_item(tr(DisplaySettings.MODE_LABELS[mode]))
		resolution.add_item("1280 × 720")
		return
	%Back.pressed.connect(close_requested.emit)
	%ApplyDisplay.pressed.connect(func() -> void: preferences.display.preview(_draft_mode, _draft_size))
	%KeepDisplay.pressed.connect(_keep_display)
	%RevertDisplay.pressed.connect(func() -> void: preferences.display.revert())
	%ResetBindings.pressed.connect(_reset_bindings)
	window_mode.item_selected.connect(_on_window_mode_selected)
	resolution.item_selected.connect(_on_resolution_selected)
	revert_timer.timeout.connect(func() -> void: preferences.display.revert())


func setup(settings: GameSettings) -> void:
	preferences = settings
	for definition: SettingDefinition in preferences.definitions.values():
		_add_row(definition).value_changed.connect(preferences.set_value)
	preferences.display.changed.connect(_show_display)


func row(id: StringName) -> SettingRow:
	return _rows[id]


func open() -> void:
	preferences.display.refresh_from_window()
	for id: StringName in _rows:
		_rows[id].show_value(preferences.get_value(id))
	_show_display()
	cancel_capture()
	tabs.current_tab = 0
	show()
	window_mode.grab_focus()


func close() -> void:
	cancel_capture()
	preferences.display.revert()
	preferences.save()
	hide()


func handle_cancel() -> void:
	if preferences.display.pending:
		preferences.display.revert()
	else:
		close_requested.emit()


func consume_input(event: InputEvent) -> bool:
	if _capture_action.is_empty():
		return false
	if not event.is_pressed() or (event is InputEventKey and event.echo):
		return true
	if event is InputEventKey and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		cancel_capture()
	elif event is InputEventKey or event is InputEventMouseButton:
		_apply_binding(PlayerBindings.normalized(event))
	return true


func begin_capture(action: StringName) -> void:
	cancel_capture()
	_capture_action = action
	_binding_rows[action].show_capture()
	binding_status.text = tr("Press a replacement key or mouse button. Esc cancels.")


func cancel_capture() -> void:
	_capture_action = &""
	_refresh_bindings()
	binding_status.text = tr("Select a binding, then press a key or mouse button. Esc cancels.")


func is_capturing() -> bool:
	return not _capture_action.is_empty()


func _process(_delta: float) -> void:
	if not revert_timer.is_stopped():
		%DisplayCountdown.text = tr("Keep these display settings? Reverting in %d s.") % ceili(revert_timer.time_left)


func _add_row(definition: SettingDefinition) -> SettingRow:
	var setting_row: SettingRow = _row_scene(definition).instantiate()
	_sections[definition.section].add_child(setting_row)
	setting_row.setup(definition)
	_rows[definition.id] = setting_row
	return setting_row


func _row_scene(definition: SettingDefinition) -> PackedScene:
	if definition is SliderSetting:
		return SLIDER_ROW
	if definition is ToggleSetting:
		return TOGGLE_ROW
	return CHOICE_ROW


func _show_display() -> void:
	var display := preferences.display
	_draft_mode = display.mode
	_draft_size = display.size
	_refresh_display_options()
	%DisplayConfirmation.visible = display.pending
	%ApplyDisplay.visible = not display.pending
	if display.pending:
		revert_timer.start()
	else:
		revert_timer.stop()
	if visible and tabs.current_tab == 0:
		(%KeepDisplay if display.pending else window_mode).grab_focus()


func _refresh_display_options() -> void:
	var display := preferences.display
	window_mode.clear()
	for mode: DisplaySettings.WindowMode in DisplaySettings.MODE_LABELS:
		window_mode.add_item(tr(DisplaySettings.MODE_LABELS[mode]), mode)
	window_mode.select(window_mode.get_item_index(_draft_mode))
	resolution.clear()
	if _draft_mode == WINDOWED:
		for option: Vector2i in display.sizes():
			resolution.add_item("%d × %d" % [option.x, option.y])
			resolution.set_item_metadata(-1, option)
			if option == _draft_size:
				resolution.select(resolution.item_count - 1)
	else:
		resolution.add_item(tr("Desktop resolution"))
	window_mode.disabled = display.pending
	resolution.disabled = display.pending or _draft_mode != WINDOWED
	%DisplayHint.text = tr("Changes need confirmation within 15 seconds.") if _draft_mode == WINDOWED else tr("Fullscreen modes use the desktop resolution.")
	var unchanged := _draft_mode == display.mode and (_draft_size == display.size or _draft_mode != WINDOWED)
	%ApplyDisplay.disabled = display.pending or unchanged


func _on_window_mode_selected(index: int) -> void:
	_draft_mode = window_mode.get_item_id(index) as DisplaySettings.WindowMode
	_refresh_display_options()


func _on_resolution_selected(index: int) -> void:
	_draft_size = resolution.get_item_metadata(index)
	_refresh_display_options()


func _keep_display() -> void:
	preferences.display.confirm()
	preferences.save()


func _apply_binding(event: InputEvent) -> void:
	var problem := preferences.bindings.problem(_capture_action, event)
	if not problem.is_empty():
		binding_status.text = problem
		return
	var action := _capture_action
	preferences.bindings.assign(action, event)
	cancel_capture()
	_binding_rows[action].button.grab_focus()
	binding_status.text = tr("Binding updated.")


func _refresh_bindings() -> void:
	for binding: BindingRow in _binding_rows.values():
		binding.refresh()


func _reset_bindings() -> void:
	preferences.bindings.reset()
	cancel_capture()
	binding_status.text = tr("Default controls restored.")
