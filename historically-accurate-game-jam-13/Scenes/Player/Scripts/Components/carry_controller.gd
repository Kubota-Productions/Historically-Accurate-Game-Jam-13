class_name CarryController
extends Node

signal changed(item_name: String)

const HOLD_PRIORITY := 125
const DROP_OFFSETS: Array[Vector2] = [Vector2(0.85, 0.0), Vector2(0.55, 0.0), Vector2(0.3, 0.65), Vector2(0.3, -0.65)]
const DROP_RAY_HEIGHT := 1.3
const DROP_RAY_LENGTH := 2.0
const FLOOR_MIN_NORMAL_Y := 0.7
const DROP_CLEARANCE := 0.03

@export var anchor: Marker3D
@export var hold_offset := Vector3(0, -0.5, -1)
@export var hold_rotation_degrees := Vector3(0, 0, 90)

var item: PickupItem
var _parent: Node
var _basis: Basis
var _layer: int
var _appearance := ViewmodelAppearance.new()

@onready var room: LaikaRoom = owner


func take(target: PickupItem) -> void:
	item = target
	_parent = item.get_parent()
	_basis = item.global_basis
	_layer = item.collision_layer
	item.collision_layer = 0
	item.show_scent(false)
	_appearance.apply(item.visual_root, HOLD_PRIORITY)
	item.reparent(anchor)
	var held := Basis.from_euler(hold_rotation_degrees * PI / 180.0).scaled_local(_basis.get_scale())
	item.global_transform = Transform3D(anchor.global_basis.orthonormalized() * held, anchor.to_global(hold_offset))
	changed.emit(item.item_name)


func drop() -> void:
	if item == null:
		return
	var point := _drop_point()
	if point.is_finite():
		_release(Transform3D(_basis, point))
	else:
		room.thought_requested.emit("No room to put this down here.")


func store(socket: ItemSocket) -> bool:
	if item == null or not socket.install(item):
		return false
	var stored := item
	_release(stored.global_transform)
	stored.collision_layer = 0
	stored.hide()
	return true


func _release(placement: Transform3D) -> void:
	item.reparent(_parent if is_instance_valid(_parent) else room)
	item.global_transform = placement
	item.collision_layer = _layer
	_appearance.restore()
	item = null
	changed.emit("")


func _drop_point() -> Vector3:
	var forward := Basis(Vector3.UP, room.player.look_yaw) * Vector3.FORWARD
	var side := forward.cross(Vector3.UP)
	var shape_offset := item.global_transform.affine_inverse() * item.shape.global_transform
	var bounds := Transform3D(_basis, Vector3.ZERO) * shape_offset * item.shape.shape.get_debug_mesh().get_aabb()
	var space := room.get_world_3d().direct_space_state
	var excluded: Array[RID] = [room.player.get_rid(), item.get_rid()]
	for offset: Vector2 in DROP_OFFSETS:
		var from := room.player.global_position + forward * offset.x + side * offset.y + Vector3.UP * DROP_RAY_HEIGHT
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * DROP_RAY_LENGTH, Layers.WORLD, excluded))
		if hit.is_empty() or hit.normal.y < FLOOR_MIN_NORMAL_Y:
			continue
		var point: Vector3 = hit.position + Vector3.UP * (DROP_CLEARANCE - bounds.position.y)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = item.shape.shape
		query.transform = Transform3D(_basis, point) * shape_offset
		query.collision_mask = Layers.WORLD | Layers.INTERACTABLES
		query.exclude = excluded
		if space.intersect_shape(query, 1).is_empty():
			return point
	return Vector3.INF
