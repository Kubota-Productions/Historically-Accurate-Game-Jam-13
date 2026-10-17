class_name InteractionAction
extends Resource

@export var required_flag: StringName


func is_available(room: LaikaRoom, _target: LaikaInteractionPoint) -> bool:
	return required_flag.is_empty() or room.progress.has_flag(required_flag)


func prompt(_room: LaikaRoom, target: LaikaInteractionPoint) -> String:
	return tr(target.display_name)


func execute(_room: LaikaRoom, _target: LaikaInteractionPoint) -> void:
	pass
