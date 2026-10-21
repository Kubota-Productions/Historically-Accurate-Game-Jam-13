class_name FootstepTracker
extends Node

signal step_requested

@export var player: FPSPlayer
@export_range(0.1, 5.0, 0.05) var step_distance: float = 0.8

var _previous_position: Vector3
var _distance: float = 0.0


func _ready() -> void:
	process_physics_priority = 1
	if player == null:
		set_physics_process(false)
		return
	player.teleported.connect(reset)
	reset()


func _physics_process(_delta: float) -> void:
	var movement := player.global_position - _previous_position
	_previous_position = player.global_position
	if not player.is_physics_processing() or not player.is_on_floor():
		_distance = 0.0
		return
	var traveled := Vector2(movement.x, movement.z).length()
	if traveled < 0.0001 or traveled > step_distance * 2.0:
		_distance = 0.0
		return
	_distance += traveled
	if _distance >= step_distance:
		_distance = fmod(_distance, step_distance)
		step_requested.emit()


func reset() -> void:
	_previous_position = player.global_position
	_distance = 0.0
