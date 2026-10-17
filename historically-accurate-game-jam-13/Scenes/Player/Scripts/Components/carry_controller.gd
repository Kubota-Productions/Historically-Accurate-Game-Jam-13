class_name CarryController
extends Node

signal changed(text: String)

@export var hold_offset := Vector3(0, -0.5, -1)
@export var hold_rotation := Vector3(0, 0, 90)

var room: LaikaRoom
var item: LaikaInteractionPoint
var _parent: Node3D
var _basis: Basis
var _appearance := ViewmodelAppearance.new()
var _shape_local: Transform3D
var _collision_layer: int


func take(target: LaikaInteractionPoint) -> bool:
	if item != null or target.visual_root == null or target.item_shape == null:
		return false
	item = target
	_parent = item.get_parent() as Node3D
	_basis = item.global_basis
	_shape_local = item.global_transform.affine_inverse() * item.item_shape.global_transform
	_collision_layer = item.collision_layer
	_appearance.apply(item.visual_root, 125)
	if item.scent_marker:
		item.scent_marker.hide()
	item.collision_layer = 0
	item.reparent(room.carry_anchor)
	var rotation := Basis.from_euler(hold_rotation * PI / 180.0)
	var held_basis := room.carry_anchor.global_basis.orthonormalized() * rotation.scaled_local(_basis.get_scale())
	item.global_transform = Transform3D(held_basis, room.carry_anchor.to_global(hold_offset))
	changed.emit(item.item_name)
	return true


func drop() -> void:
	if item == null:
		return
	var point := _find_drop_position()
	if not point.is_finite():
		room.thought_requested.emit("No room to put this down here.")
		return
	item.reparent(_parent if is_instance_valid(_parent) else room)
	item.global_transform = Transform3D(_basis, point)
	item.collision_layer = _collision_layer
	_release()


func store(socket: ItemSocket) -> bool:
	if item == null or socket == null or not socket.accepts(item):
		return false
	if not socket.install(item.item_id):
		return false
	item.reparent(_parent if is_instance_valid(_parent) else room)
	item.hide()
	_release()
	return true


func _release() -> void:
	_appearance.restore()
	item = null
	changed.emit("")


func _find_drop_position() -> Vector3:
	var forward := Basis(Vector3.UP, room.player.look_yaw) * Vector3.FORWARD
	var side := forward.cross(Vector3.UP)
	var offsets: Array[Vector3] = [forward * 0.85, forward * 0.55, forward * 0.3 + side * 0.65, forward * 0.3 - side * 0.65]
	var shape: CollisionShape3D = item.item_shape
	var bounds: AABB = Transform3D(_basis, Vector3.ZERO) * _shape_local * shape.shape.get_debug_mesh().get_aabb()
	var space := room.get_world_3d().direct_space_state
	for offset: Vector3 in offsets:
		var from := room.player.global_position + offset + Vector3.UP * 1.3
		var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0, 1, [room.player.get_rid()])
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
			continue
		var point: Vector3 = hit.position + Vector3.UP * (-bounds.position.y + 0.03)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = Transform3D(_basis, point) * _shape_local
		query.collision_mask = 3
		query.exclude = [room.player.get_rid(), item.get_rid()]
		if space.intersect_shape(query, 1).is_empty():
			return point
	return Vector3.INF
