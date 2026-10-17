@tool
class_name SettingDefinition
extends Resource

enum Section { VIDEO, AUDIO, CONTROLS }

@export var id: StringName
@export var label: String
@export var section: Section


func get_default() -> Variant:
	return null


func sanitize(_value: Variant) -> Variant:
	return get_default()


func apply(_value: Variant) -> void:
	pass
