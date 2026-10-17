@tool
class_name PickupAction
extends InteractionAction


func is_available(room: LaikaRoom, target: Interactable) -> bool:
	return super(room, target) and room.carry.item == null


func execute(room: LaikaRoom, target: Interactable) -> void:
	room.carry.take(target)


func configuration_errors(room: LaikaRoom, target: Interactable) -> PackedStringArray:
	var errors := super(room, target)
	if not target is PickupItem:
		errors.append("PickupAction works on a PickupItem.")
	return errors
