class_name NpcGaze
extends Node

@export var look_at: LookAtModifier3D
@export var target: Node3D
@export var enter_radius: float = 3.0
@export var exit_radius: float = 3.3
@export var response: float = 7.5

var _following: bool = false
var _weight: float = 0.0


func _ready() -> void:
	if look_at:
		look_at.active = true
		look_at.influence = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(target) or not is_instance_valid(look_at):
		return

	var distance := look_at.global_position.distance_to(target.global_position)
	_following = distance <= (exit_radius if _following else enter_radius)

	var goal := 1.0 if _following else 0.0
	_weight = move_toward(_weight, goal, response * delta)
	look_at.influence = _weight
