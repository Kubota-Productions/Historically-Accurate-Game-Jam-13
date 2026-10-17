class_name SocketAction
extends InteractionAction

@export var empty_message: String = "Something goes in here. Probably not my nose."


func prompt(room: LaikaRoom, target: LaikaInteractionPoint) -> String:
	if room.carry.item != null and target.socket.accepts(room.carry.item):
		return tr("Place %s") % tr(room.carry.item.item_name)
	return "" if target.socket.is_full() else tr(target.display_name)


func execute(room: LaikaRoom, target: LaikaInteractionPoint) -> void:
	if room.carry.item != null:
		room.carry.store(target.socket)
	elif not target.socket.is_full():
		room.thought_requested.emit(empty_message)
