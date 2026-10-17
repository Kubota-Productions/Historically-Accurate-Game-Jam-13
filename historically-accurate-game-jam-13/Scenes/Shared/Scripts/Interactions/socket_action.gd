@tool
class_name SocketAction
extends InteractionAction

@export var mismatch_message: String = "That does not fit here."
@export var empty_message: String = "Something goes in here. Probably not my nose."


func is_available(room: LaikaRoom, target: Interactable) -> bool:
	return super(room, target) and not target.is_full()


func prompt(room: LaikaRoom, target: Interactable) -> String:
	var item := room.carry.item
	if item and target.accepts(item):
		return tr("Place %s") % tr(item.item_name)
	return tr(target.display_name)


func execute(room: LaikaRoom, target: Interactable) -> void:
	if room.carry.item == null:
		room.thought_requested.emit(empty_message)
	elif not room.carry.store(target):
		room.thought_requested.emit(mismatch_message)


func configuration_errors(room: LaikaRoom, target: Interactable) -> PackedStringArray:
	var errors := super(room, target)
	if not target is ItemSocket:
		errors.append("SocketAction works on an ItemSocket.")
	return errors
