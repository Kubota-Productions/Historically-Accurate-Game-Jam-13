class_name PickupAction
extends InteractionAction


func is_available(room: LaikaRoom, target: LaikaInteractionPoint) -> bool:
	return super.is_available(room, target) and room.carry.item == null


func execute(room: LaikaRoom, target: LaikaInteractionPoint) -> void:
	room.carry.take(target)
