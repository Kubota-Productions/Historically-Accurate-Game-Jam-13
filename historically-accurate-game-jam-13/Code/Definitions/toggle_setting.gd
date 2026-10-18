@tool
class_name ToggleSetting
extends SettingDefinition

@export var default_value: bool = false


func get_default() -> Variant:
	return default_value


func sanitize(value: Variant) -> Variant:
	return value if value is bool else default_value
