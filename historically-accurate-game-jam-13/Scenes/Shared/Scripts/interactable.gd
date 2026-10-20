@tool
class_name Interactable
extends StaticBody3D

signal inspection_part_activated(part_id: StringName)

@export var display_name: String
@export var action: InteractionAction:
	set(value):
		action = value
		update_configuration_warnings()
@export var enabled: bool = true
@export_group("Inspection")
@export var allow_inspection: bool = false
@export var inspection_scene: PackedScene
@export var inspection_title: String
@export_multiline var inspection_description: String

var inspected_parts: Dictionary[StringName, bool] = {}


func _enter_tree() -> void:
	add_to_group(&"interactables")


func can_interact(room: LaikaRoom) -> bool:
	return enabled and is_visible_in_tree() and action != null and action.is_available(room, self)


func get_prompt(room: LaikaRoom) -> String:
	return action.prompt(room, self) if can_interact(room) else ""


func interact(room: LaikaRoom) -> void:
	if can_interact(room):
		action.execute(room, self)


func configuration_errors(room: LaikaRoom = null) -> PackedStringArray:
	if action == null:
		return ["action: choose what this object does."]
	return action.configuration_errors(room, self)


func _get_configuration_warnings() -> PackedStringArray:
	return configuration_errors()
