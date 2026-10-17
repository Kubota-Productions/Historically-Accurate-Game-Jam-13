@tool
class_name SocketAction
extends InteractionAction

@export var mismatch_message: String = "That does not fit here.":
	set(value):
		mismatch_message = value
		emit_changed()
@export var empty_message: String = "Something goes in here. Probably not my nose.":
	set(value):
		empty_message = value
		emit_changed()


func is_available(room: LaikaRoom, target: LaikaInteractionPoint) -> bool:
	return super.is_available(room, target) and target.socket != null and not target.socket.is_full()


func prompt(room: LaikaRoom, target: LaikaInteractionPoint) -> String:
	if room.carry.item != null and target.socket.accepts(room.carry.item):
		return tr("Place %s") % tr(room.carry.item.item_name)
	return "" if target.socket.is_full() else tr(target.display_name)


func execute(room: LaikaRoom, target: LaikaInteractionPoint) -> void:
	if room.carry.item != null:
		if not room.carry.store(target.socket):
			room.thought_requested.emit(mismatch_message)
	elif not target.socket.is_full():
		room.thought_requested.emit(empty_message)


func configuration_errors(target: LaikaInteractionPoint, _room: LaikaRoom = null) -> PackedStringArray:
	if target.socket == null:
		return ["socket: assign an ItemSocket node."]
	return target.socket.configuration_errors()
