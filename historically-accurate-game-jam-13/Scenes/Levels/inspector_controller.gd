extends Node

@export var target: Node3D
@export var rotate_action: StringName
@export_range(0.001, 0.05) var sensitivity: float = 0.01

var rotating: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(target) or rotate_action.is_empty() or not InputMap.has_action(rotate_action):
		return
	if event.is_action_pressed(rotate_action):
		rotating = true
	elif event.is_action_released(rotate_action):
		rotating = false
	elif rotating and event is InputEventMouseMotion:
		target.rotate_y(event.relative.x * sensitivity)
		target.rotate_x(event.relative.y * sensitivity)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		rotating = false
