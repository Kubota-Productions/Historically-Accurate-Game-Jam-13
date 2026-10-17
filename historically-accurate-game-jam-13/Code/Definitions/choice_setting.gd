@tool
class_name ChoiceSetting
extends SettingDefinition

@export var options: PackedStringArray = []
@export var default_value: int = 0


func get_default() -> Variant:
	return default_value


func sanitize(value: Variant) -> Variant:
	return value if value is int and value >= 0 and value < options.size() else default_value
