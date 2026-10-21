extends Node

@export var target: Node3D # Handle Object as selectable input
@export var rotate_action: StringName # Add a new action keyword for new functionality
@export_range(0.001, 0.05) var sensitivity: float = 0.01 # Control rotation speed
@export var interaction_group: StringName

var rotating: bool = false # Program a state for rotation

# Handle input
func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(target) or rotate_action.is_empty() or not InputMap.has_action(rotate_action): # Invalid inputs
		return
	if event.is_action_pressed(rotate_action): # Don't use the 'Input' object
		rotating = true
	elif event.is_action_released(rotate_action): # is_action ... why?
		rotating = false
	elif rotating and event is InputEventMouseMotion:
		target.rotate_y(event.relative.x * sensitivity)
		target.rotate_x(event.relative.y * sensitivity)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		rotating = false
