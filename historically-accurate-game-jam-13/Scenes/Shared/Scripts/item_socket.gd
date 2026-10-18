@tool
class_name ItemSocket
extends Interactable

signal installed(count: int)

@export var accepted_item: StringName = &"battery"
@export_range(1, 99) var capacity: int = 2
@export var indicators: Array[Node3D] = []

var count: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for indicator: Node3D in indicators:
		indicator.hide()


func is_full() -> bool:
	return count >= capacity


func accepts(item: PickupItem) -> bool:
	return not is_full() and item.item_id == accepted_item


func install(item: PickupItem) -> bool:
	if not accepts(item):
		return false
	if count < indicators.size():
		indicators[count].show()
	count += 1
	installed.emit(count)
	return true


func configuration_errors(room: LaikaRoom = null) -> PackedStringArray:
	var errors := super(room)
	if accepted_item.is_empty():
		errors.append("accepted_item: enter the item_id this socket takes.")
	if indicators.size() > capacity or indicators.has(null):
		errors.append("indicators: use at most one existing node per slot.")
	return errors
