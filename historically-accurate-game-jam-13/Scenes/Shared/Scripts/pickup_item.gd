@tool
class_name PickupItem
extends Interactable

@export var item_id: StringName
@export var item_name: String
@export var visual_root: Node3D
@export var shape: CollisionShape3D
@export var scent_marker: Node3D


func _enter_tree() -> void:
	super()
	add_to_group(&"pickups")


func _ready() -> void:
	show_scent(false)


func show_scent(visible_now: bool) -> void:
	if scent_marker:
		scent_marker.visible = visible_now and is_visible_in_tree()


func configuration_errors(room: LaikaRoom = null) -> PackedStringArray:
	var errors := super(room)
	if item_id.is_empty() or item_name.is_empty():
		errors.append("item_id and item_name: describe the item.")
	if visual_root == null or not is_ancestor_of(visual_root):
		errors.append("visual_root: choose a child that holds the item's meshes.")
	if shape == null or shape.get_parent() != self or shape.shape == null:
		errors.append("shape: choose a CollisionShape3D directly under the item.")
	if scent_marker != null and not is_ancestor_of(scent_marker):
		errors.append("scent_marker: place it under the item.")
	return errors
