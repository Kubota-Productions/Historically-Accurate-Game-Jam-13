@tool
class_name TalkAction
extends InteractionAction

@export var dialogue_id: StringName:
	set(value):
		dialogue_id = value
		emit_changed()
@export var dialogue_by_flag: Dictionary[StringName, StringName] = {}:
	set(value):
		dialogue_by_flag = value
		emit_changed()
@export var completed_flag: StringName:
	set(value):
		completed_flag = value
		emit_changed()
@export var completed_message: String:
	set(value):
		completed_message = value
		emit_changed()


func execute(room: LaikaRoom, _target: LaikaInteractionPoint) -> void:
	if not completed_flag.is_empty() and room.progress.has_flag(completed_flag):
		room.thought_requested.emit(completed_message)
		return
	for flag: StringName in dialogue_by_flag:
		if room.progress.has_flag(flag):
			room.dialogue_requested.emit(dialogue_by_flag[flag])
			return
	room.dialogue_requested.emit(dialogue_id)


func configuration_errors(_target: LaikaInteractionPoint, room: LaikaRoom = null) -> PackedStringArray:
	var errors: PackedStringArray = []
	for id: StringName in [dialogue_id] + dialogue_by_flag.values():
		if not DialogueCatalog.CONVERSATIONS.has(id):
			errors.append("dialogue_id: unknown conversation '%s'." % id)
	if room:
		for flag: StringName in dialogue_by_flag:
			if not room.progress.knows_flag(flag):
				errors.append("dialogue_by_flag: unknown flag '%s'." % flag)
	return errors
