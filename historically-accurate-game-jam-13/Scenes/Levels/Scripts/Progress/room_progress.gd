class_name RoomProgress
extends Node

var room: LaikaRoom
var _flags: Dictionary[StringName, bool] = {}


func _ready() -> void:
	room = owner as LaikaRoom


static func declared(constant: StringName) -> PackedStringArray:
	var names: PackedStringArray = []
	for info: Dictionary in ProjectSettings.get_global_class_list():
		if info.base == &"RoomProgress":
			for entry: StringName in load(info.path).get_script_constant_map().get(constant, []):
				if not entry in names:
					names.append(entry)
	return names


func begin() -> void:
	pass


func dialogue_finished(_dialogue: Dialogue) -> void:
	pass


func handle_event(_event: StringName) -> void:
	pass


func has_flag(flag: StringName) -> bool:
	return _flags.get(flag, false)


func set_flag(flag: StringName, value: bool = true) -> void:
	assert(knows_flag(flag), "Declare %s in FLAGS." % flag)
	_flags[flag] = value


func knows_flag(flag: StringName) -> bool:
	return flag in get_script().get_script_constant_map().get(&"FLAGS", [])


func knows_event(event: StringName) -> bool:
	return event in get_script().get_script_constant_map().get(&"EVENTS", [])


func configuration_errors() -> PackedStringArray:
	return []
