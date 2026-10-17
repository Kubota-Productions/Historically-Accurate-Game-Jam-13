@tool
class_name InteractionAction
extends Resource

@export var required_flag: StringName:
	set(value):
		required_flag = value
		emit_changed()


func is_available(room: LaikaRoom, _target: LaikaInteractionPoint) -> bool:
	return required_flag.is_empty() or room.progress.has_flag(required_flag)


func prompt(_room: LaikaRoom, target: LaikaInteractionPoint) -> String:
	return tr(target.display_name)


func execute(_room: LaikaRoom, _target: LaikaInteractionPoint) -> void:
	pass


func configuration_errors(_target: LaikaInteractionPoint, _room: LaikaRoom = null) -> PackedStringArray:
	return []
