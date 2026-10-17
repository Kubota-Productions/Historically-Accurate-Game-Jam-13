@tool
class_name ItemSocket
extends Node

signal installed(item_id: StringName, count: int)

@export var accepted_item: StringName = &"battery"
@export_range(1, 99) var capacity: int = 2
@export var indicators: Array[Node3D] = []

var _count: int = 0
var count: int:
	get: return _count


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for indicator: Node3D in indicators:
		if is_instance_valid(indicator):
			indicator.hide()


func is_full() -> bool:
	return count >= capacity


func accepts(item: LaikaInteractionPoint) -> bool:
	return not is_full() and item.item_id == accepted_item


func install(item_id: StringName) -> bool:
	if is_full() or item_id != accepted_item:
		return false
	if count < indicators.size() and is_instance_valid(indicators[count]):
		indicators[count].show()
	_count += 1
	installed.emit(item_id, count)
	return true


func configuration_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if accepted_item.is_empty():
		errors.append("accepted_item: enter the accepted item ID.")
	if capacity < 1:
		errors.append("capacity: must be at least one.")
	if indicators.size() > capacity:
		errors.append("indicators: cannot exceed the socket capacity.")
	for indicator: Node3D in indicators:
		if not is_instance_valid(indicator):
			errors.append("indicators: remove empty references.")
	return errors


func _get_configuration_warnings() -> PackedStringArray:
	return configuration_errors()
