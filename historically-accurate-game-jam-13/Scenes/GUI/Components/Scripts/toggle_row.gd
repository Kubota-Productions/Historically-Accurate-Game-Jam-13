@tool
extends SettingRow

@onready var editor: CheckButton = %Toggle


func setup(setting: SettingDefinition) -> void:
	super(setting)
	editor.toggled.connect(func(pressed: bool) -> void: value_changed.emit(setting.id, pressed))


func show_value(value: Variant) -> void:
	editor.set_pressed_no_signal(value)
