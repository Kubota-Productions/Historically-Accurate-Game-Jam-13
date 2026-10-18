@tool
class_name ExitAction
extends InteractionAction

@export var destination: RoomDefinition
@export var blocked_message: String


func is_available(_room: LaikaRoom, _target: Interactable) -> bool:
	return true


func execute(room: LaikaRoom, target: Interactable) -> void:
	if super.is_available(room, target):
		room.departure_requested.emit(destination)
	else:
		room.thought_requested.emit(blocked_message)


func configuration_errors(room: LaikaRoom, target: Interactable) -> PackedStringArray:
	var errors := super(room, target)
	if destination == null:
		errors.append("destination: choose a room.")
	return errors
