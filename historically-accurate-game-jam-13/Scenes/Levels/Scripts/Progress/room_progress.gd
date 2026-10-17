class_name RoomProgress
extends Node

enum Step { GREETING, FETCH, POWER, CAPSULE, ARRIVAL, COMPLETE }

var room: LaikaRoom
var step: Step = Step.GREETING
var _flags: Dictionary[StringName, bool] = {}


func setup(owner_room: LaikaRoom) -> void:
	room = owner_room


func has_flag(flag: StringName) -> bool:
	return _flags.get(flag, false)


func set_flag(flag: StringName, value: bool) -> void:
	_flags[flag] = value


func begin() -> void:
	pass


func complete_dialogue(_id: StringName) -> void:
	pass


func handle_event(_event: StringName, _source: LaikaInteractionPoint) -> void:
	pass


func get_item_count() -> int:
	return 0
