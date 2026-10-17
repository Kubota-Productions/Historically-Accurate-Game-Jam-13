class_name RoomProgress
extends Node

var room: LaikaRoom
var _flags: Dictionary[StringName, bool] = {}
var _dialogues: Dictionary[StringName, Callable] = {}
var _events: Dictionary[StringName, Callable] = {}


func setup(owner_room: LaikaRoom) -> void:
	room = owner_room


func begin() -> void:
	pass


func knows_flag(flag: StringName) -> bool:
	return _flags.has(flag)


func has_flag(flag: StringName) -> bool:
	return _flags.get(flag, false)


func set_flag(flag: StringName, value: bool) -> void:
	_flags[flag] = value


func complete_dialogue(id: StringName) -> void:
	if _dialogues.has(id):
		_dialogues[id].call()


func supports_event(id: StringName) -> bool:
	return _events.has(id)


func handle_event(id: StringName, source: LaikaInteractionPoint) -> void:
	if supports_event(id):
		_events[id].call(source)
	else:
		push_error("%s: unknown event '%s'." % [get_path(), id])


func configuration_errors() -> PackedStringArray:
	return []
