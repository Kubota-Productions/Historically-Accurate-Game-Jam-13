@tool
class_name SettingRow
extends HBoxContainer

signal value_changed(id: StringName, value: Variant)

var definition: SettingDefinition


func setup(setting: SettingDefinition) -> void:
	definition = setting
	%Title.text = tr(setting.label)


func show_value(_value: Variant) -> void:
	pass
