@tool
extends SettingRow

@onready var editor: HSlider = %Slider


func setup(setting: SettingDefinition) -> void:
	super(setting)
	editor.min_value = setting.minimum
	editor.max_value = setting.maximum
	editor.step = setting.step
	editor.value_changed.connect(_on_value_changed)


func show_value(value: Variant) -> void:
	editor.set_value_no_signal(value)
	%Value.text = definition.format(value)


func _on_value_changed(value: float) -> void:
	%Value.text = definition.format(value)
	value_changed.emit(definition.id, value)
