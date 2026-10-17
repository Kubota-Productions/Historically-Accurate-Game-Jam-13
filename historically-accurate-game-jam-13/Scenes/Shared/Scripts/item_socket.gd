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
	for indicator: Node3D in indicators:
		indicator.hide()


func is_full() -> bool:
	return count >= capacity


func accepts(item: LaikaInteractionPoint) -> bool:
	return not is_full() and item.item_id == accepted_item


func install(item_id: StringName) -> bool:
	if is_full() or item_id != accepted_item:
		return false
	if count < indicators.size():
		indicators[count].show()
	_count += 1
	installed.emit(item_id, count)
	return true
