@tool
extends Node3D

@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			_apply_enabled()

var _collisions: Dictionary[Node, bool] = {}
var _process_mode: ProcessMode


func _ready() -> void:
	_process_mode = process_mode
	if not Engine.is_editor_hint():
		for shape: Node in find_children("*", "CollisionShape3D", true, false):
			_collisions[shape] = shape.disabled
		for csg: Node in find_children("*", "CSGShape3D", true, false):
			_collisions[csg] = csg.use_collision
	_apply_enabled()


func _apply_enabled() -> void:
	visible = enabled
	if Engine.is_editor_hint():
		return
	process_mode = _process_mode if enabled else Node.PROCESS_MODE_DISABLED
	for collider: Node in _collisions:
		if collider is CollisionShape3D:
			collider.set_deferred("disabled", _collisions[collider] if enabled else true)
		else:
			collider.set_deferred("use_collision", _collisions[collider] if enabled else false)
