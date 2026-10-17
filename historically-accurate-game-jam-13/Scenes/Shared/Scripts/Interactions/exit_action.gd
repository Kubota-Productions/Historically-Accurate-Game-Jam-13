@tool
class_name ExitAction
extends InteractionAction

@export var destination: StringName:
	set(value):
		destination = value
		emit_changed()
@export var blocked_message: String:
	set(value):
		blocked_message = value
		emit_changed()


func is_available(_room: LaikaRoom, _target: LaikaInteractionPoint) -> bool:
	return true


func execute(room: LaikaRoom, _target: LaikaInteractionPoint) -> void:
	if required_flag.is_empty() or room.progress.has_flag(required_flag):
		room.departure_requested.emit(destination)
	else:
		room.thought_requested.emit(blocked_message)


func configuration_errors(_target: LaikaInteractionPoint, _room: LaikaRoom = null) -> PackedStringArray:
	return [] if SceneCatalog.ROOMS.has(destination) else ["destination: unknown room '%s'." % destination]
