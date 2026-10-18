@tool
class_name TalkAction
extends InteractionAction

@export var dialogue: Dialogue
@export var dialogue_when_flag: Dictionary[StringName, Dialogue] = {}
@export var completed_flag: StringName
@export var completed_message: String


func execute(room: LaikaRoom, _target: Interactable) -> void:
	if room.progress.has_flag(completed_flag):
		room.thought_requested.emit(completed_message)
		return
	for flag: StringName in dialogue_when_flag:
		if room.progress.has_flag(flag):
			room.dialogue_requested.emit(dialogue_when_flag[flag])
			return
	room.dialogue_requested.emit(dialogue)


func configuration_errors(room: LaikaRoom, target: Interactable) -> PackedStringArray:
	var errors := super(room, target)
	errors.append_array(unknown_flags(room, [completed_flag] + dialogue_when_flag.keys()))
	if dialogue == null or dialogue_when_flag.values().has(null):
		errors.append("dialogue: choose a conversation.")
	return errors
