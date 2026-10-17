class_name ScentController
extends Node

signal changed(active: bool)

var room: LaikaRoom
var enabled: bool = false
var _active: bool = false


func _process(_delta: float) -> void:
	var active := enabled and Input.is_action_pressed(&"sniff")
	room.scent_markers.visible = active
	for target: LaikaInteractionPoint in room.interactables:
		if target.scent_marker:
			target.scent_marker.visible = target != room.carry.item and target.is_visible_in_tree()
	if _active != active:
		_active = active
		changed.emit(active)
