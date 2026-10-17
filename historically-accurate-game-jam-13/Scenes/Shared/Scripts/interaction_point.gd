class_name LaikaInteractionPoint
extends StaticBody3D

@export var interaction_id: StringName
@export var display_name: String
@export var action: InteractionAction
@export var enabled: bool = true
@export_group("Item")
@export var item_id: StringName
@export var item_name: String
@export var item_mesh: MeshInstance3D
@export var item_shape: CollisionShape3D
@export var scent_marker: Node3D
@export_group("Receptacle")
@export var socket: ItemSocket


func can_interact(room: LaikaRoom) -> bool:
	return enabled and is_visible_in_tree() and not is_queued_for_deletion() and action != null and action.is_available(room, self)


func get_prompt(room: LaikaRoom) -> String:
	return action.prompt(room, self) if can_interact(room) else ""


func interact(room: LaikaRoom) -> void:
	if can_interact(room):
		action.execute(room, self)
