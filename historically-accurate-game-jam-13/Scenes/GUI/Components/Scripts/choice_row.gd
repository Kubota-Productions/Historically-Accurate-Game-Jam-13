@tool
extends SettingRow

@onready var editor: OptionButton = %Choice


func setup(setting: SettingDefinition) -> void:
	super(setting)
	for option: String in setting.options:
		editor.add_item(tr(option))
	editor.item_selected.connect(func(index: int) -> void: value_changed.emit(setting.id, index))


func show_value(value: Variant) -> void:
	editor.select(value)
