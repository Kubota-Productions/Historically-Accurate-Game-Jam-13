@tool
class_name PickupAction
extends InteractionAction


func is_available(room: LaikaRoom, target: LaikaInteractionPoint) -> bool:
	return super.is_available(room, target) and room.carry.item == null


func execute(room: LaikaRoom, target: LaikaInteractionPoint) -> void:
	room.carry.take(target)


func configuration_errors(target: LaikaInteractionPoint, _room: LaikaRoom = null) -> PackedStringArray:
	var errors: PackedStringArray = []
	if target.item_id.is_empty():
		errors.append("item_id: enter a stable item ID.")
	if target.item_name.is_empty():
		errors.append("item_name: enter the displayed item name.")
	if target.visual_root == null or not target.is_ancestor_of(target.visual_root):
		errors.append("visual_root: assign a child containing the item's meshes.")
	elif not target.visual_root is MeshInstance3D and target.visual_root.find_children("*", "MeshInstance3D", true, false).is_empty():
		errors.append("visual_root: add a mesh or imported model.")
	if target.item_shape == null or target.item_shape.get_parent() != target or target.item_shape.shape == null:
		errors.append("item_shape: assign a CollisionShape3D directly under the item with a shape.")
	if target.scent_marker != null and not target.is_ancestor_of(target.scent_marker):
		errors.append("scent_marker: place it under this item so it moves with the item.")
	return errors
