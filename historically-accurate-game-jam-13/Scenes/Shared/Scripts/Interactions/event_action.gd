@tool
class_name EventAction
extends InteractionAction

@export var event_id: StringName:
	set(value):
		event_id = value
		emit_changed()
@export var completed_flag: StringName:
	set(value):
		completed_flag = value
		emit_changed()
@export var completed_prompt: String:
	set(value):
		completed_prompt = value
		emit_changed()


func prompt(room: LaikaRoom, target: LaikaInteractionPoint) -> String:
	if not completed_flag.is_empty() and room.progress.has_flag(completed_flag):
		return tr(completed_prompt)
	return tr(target.display_name)


func execute(room: LaikaRoom, target: LaikaInteractionPoint) -> void:
	room.progress.handle_event(event_id, target)


func configuration_errors(_target: LaikaInteractionPoint, room: LaikaRoom = null) -> PackedStringArray:
	if event_id.is_empty():
		return ["event_id: choose an event handled by the room's Progress."]
	if room and not room.progress.supports_event(event_id):
		return ["event_id: unknown event '%s' in this room's Progress." % event_id]
	return []
