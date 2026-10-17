class_name TalkAction
extends InteractionAction

@export var dialogue_id: StringName
@export var dialogue_by_flag: Dictionary[StringName, StringName] = {}
@export var completed_flag: StringName
@export var completed_message: String


func execute(room: LaikaRoom, _target: LaikaInteractionPoint) -> void:
	if not completed_flag.is_empty() and room.progress.has_flag(completed_flag):
		room.thought_requested.emit(completed_message)
		return
	for flag: StringName in dialogue_by_flag:
		if room.progress.has_flag(flag):
			room.dialogue_requested.emit(dialogue_by_flag[flag])
			return
	room.dialogue_requested.emit(dialogue_id)
