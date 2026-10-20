extends Node3D

var rotating = false

var mouse_pos_prev
var mouse_pos_next

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# First Priority: detect select part
	if Input.is_action_just_pressed("") :
		rotating = true
	# Second Priority: rotate 
	if Input.is_action_just_released("") :
		rotating = false
	
	if rotating :
		mouse_pos_next = get_viewport().get_mouse_position()
		rotate_y(mouse_pos_next.x - mouse_pos_prev.x)
		rotate_z(-(mouse_pos_next.y - mouse_pos_prev.y))
		mouse_pos_prev = mouse_pos_next
