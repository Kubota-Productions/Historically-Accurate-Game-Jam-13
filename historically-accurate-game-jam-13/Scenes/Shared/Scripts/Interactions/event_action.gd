class_name EventAction
extends InteractionAction

@export var event_id: StringName
@export var completed_flag: StringName
@export var completed_prompt: String


func prompt(room: LaikaRoom, target: LaikaInteractionPoint) -> String:
	if not completed_flag.is_empty() and room.progress.has_flag(completed_flag):
		return tr(completed_prompt)
	return tr(target.display_name)


func execute(room: LaikaRoom, target: LaikaInteractionPoint) -> void:
	room.progress.handle_event(event_id, target)
