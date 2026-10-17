class_name ScentController
extends Node

signal changed(active: bool)

var room: LaikaRoom
var enabled: bool = false:
	set(value):
		enabled = value
		if not enabled and room:
			_update(false)
var active: bool = false


func _process(_delta: float) -> void:
	_update(enabled and Input.is_action_pressed(&"sniff"))


func _update(value: bool) -> void:
	for target: LaikaInteractionPoint in room.get_interactions():
		if is_instance_valid(target.scent_marker):
			target.scent_marker.visible = value and target != room.carry.item and target.is_visible_in_tree()
	if active != value:
		active = value
		changed.emit(active)
