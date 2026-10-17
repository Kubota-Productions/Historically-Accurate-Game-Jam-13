@tool
class_name LaikaInteractionPoint
extends StaticBody3D

@export var interaction_id: StringName
@export var display_name: String
@export var action: InteractionAction:
	set(value):
		if action and action.changed.is_connected(_refresh_warnings):
			action.changed.disconnect(_refresh_warnings)
		action = value
		if action:
			action.changed.connect(_refresh_warnings)
		_refresh_warnings()
@export var enabled: bool = true
@export_group("Item")
@export var item_id: StringName:
	set(value):
		item_id = value
		_refresh_warnings()
@export var item_name: String:
	set(value):
		item_name = value
		_refresh_warnings()
@export var visual_root: Node3D:
	set(value):
		visual_root = value
		_refresh_warnings()
@export var item_shape: CollisionShape3D:
	set(value):
		item_shape = value
		_refresh_warnings()
@export var scent_marker: Node3D:
	set(value):
		scent_marker = value
		_refresh_warnings()
@export_group("Receptacle")
@export var socket: ItemSocket:
	set(value):
		socket = value
		_refresh_warnings()

var _room: LaikaRoom


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is LaikaRoom:
			_room = ancestor
			_room.register_interaction(self)
			break
		ancestor = ancestor.get_parent()


func _ready() -> void:
	if scent_marker and not Engine.is_editor_hint():
		scent_marker.hide()
	if is_instance_valid(_room) and _room.is_node_ready():
		validate_runtime()


func _exit_tree() -> void:
	if is_instance_valid(_room):
		_room.unregister_interaction(self)
	_room = null


func can_interact(room: LaikaRoom) -> bool:
	return enabled and is_visible_in_tree() and not is_queued_for_deletion() and action != null and action.is_available(room, self)


func get_prompt(room: LaikaRoom) -> String:
	return action.prompt(room, self) if can_interact(room) else ""


func interact(room: LaikaRoom) -> void:
	if can_interact(room):
		action.execute(room, self)


func configuration_errors(room: LaikaRoom = null) -> PackedStringArray:
	if action == null:
		return PackedStringArray(["action: assign an interaction resource."])
	var errors := action.configuration_errors(self, room)
	if room:
		for property: Dictionary in action.get_property_list():
			if property.name in ["required_flag", "completed_flag"]:
				var flag: StringName = action.get(property.name)
				if not flag.is_empty() and not room.progress.knows_flag(flag):
					errors.append("%s: unknown flag '%s' in this room's Progress." % [property.name, flag])
	return errors


func validate_runtime() -> void:
	var errors := configuration_errors(_room)
	if not errors.is_empty():
		enabled = false
		push_error("%s: %s" % [get_path(), "; ".join(errors)])


func _get_configuration_warnings() -> PackedStringArray:
	return configuration_errors()


func _refresh_warnings() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		update_configuration_warnings()
