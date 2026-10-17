class_name ScentController
extends Node

signal changed(active: bool)

var active: bool = false
var enabled: bool = false:
	set(value):
		enabled = value
		_set_active(active and enabled)

@onready var room: LaikaRoom = owner


func _ready() -> void:
	room.carry.changed.connect(func(_item_name: String) -> void: refresh())


func _process(_delta: float) -> void:
	_set_active(enabled and Input.is_action_pressed(&"sniff"))


func refresh() -> void:
	for item: PickupItem in get_tree().get_nodes_in_group(&"pickups"):
		item.show_scent(active and item != room.carry.item and room.is_ancestor_of(item))


func _set_active(value: bool) -> void:
	if value == active:
		return
	active = value
	refresh()
	changed.emit(active)
