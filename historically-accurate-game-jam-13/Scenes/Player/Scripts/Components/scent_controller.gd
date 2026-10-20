class_name ScentController
extends Node

signal changed(active: bool)

@export_range(0.5, 4.0) var hint_interval: float = 1.6

var active: bool = false
var enabled: bool = false:
	set(value):
		enabled = value
		_set_active(active and enabled)
var trail: ScentTrail
var _hint_remaining: float = 0.0

@onready var room: LaikaRoom = owner


func _ready() -> void:
	trail = ScentTrail.new()
	trail.name = "ScentTrail"
	room.add_child.call_deferred(trail)
	room.carry.changed.connect(func(_item_name: String) -> void: refresh())


func _process(delta: float) -> void:
	_set_active(enabled and Input.is_action_pressed(&"sniff"))
	if not active or not trail.is_inside_tree():
		return
	_hint_remaining -= delta
	if _hint_remaining <= 0.0:
		_hint_remaining = hint_interval
		var target := nearest_item()
		if target:
			trail.emit_hint(room.player.global_position, target.global_position, [room.player.get_rid()])
		else:
			trail.clear()


func refresh() -> void:
	for item: PickupItem in get_tree().get_nodes_in_group(&"pickups"):
		if room.is_ancestor_of(item):
			item.show_scent(false)
	if is_instance_valid(trail):
		trail.clear()
	_hint_remaining = 0.0


func _set_active(value: bool) -> void:
	if value == active:
		return
	active = value
	refresh()
	changed.emit(active)


func nearest_item() -> PickupItem:
	if not active:
		return null
	var nearest: PickupItem
	var nearest_distance := INF
	for item: PickupItem in get_tree().get_nodes_in_group(&"pickups"):
		if not room.is_ancestor_of(item) or item == room.carry.item or not item.enabled or not item.is_visible_in_tree() or item.scent_marker == null:
			continue
		var distance := room.player.global_position.distance_squared_to(item.global_position)
		if distance < nearest_distance:
			nearest = item
			nearest_distance = distance
	return nearest
