@tool
class_name InteractionAction
extends Resource

@export var required_flag: StringName


func is_available(room: LaikaRoom, _target: Interactable) -> bool:
	return required_flag.is_empty() or room.progress.has_flag(required_flag)


func prompt(_room: LaikaRoom, target: Interactable) -> String:
	return tr(target.display_name)


func execute(_room: LaikaRoom, _target: Interactable) -> void:
	pass


func configuration_errors(room: LaikaRoom, _target: Interactable) -> PackedStringArray:
	return unknown_flags(room, [required_flag])


func unknown_flags(room: LaikaRoom, flags: Array) -> PackedStringArray:
	var errors: PackedStringArray = []
	for flag: StringName in flags:
		if room and not flag.is_empty() and not room.progress.knows_flag(flag):
			errors.append("unknown flag '%s' in %s." % [flag, room.name])
	return errors


func _validate_property(property: Dictionary) -> void:
	if property.name.ends_with("_flag"):
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(RoomProgress.declared(&"FLAGS"))
