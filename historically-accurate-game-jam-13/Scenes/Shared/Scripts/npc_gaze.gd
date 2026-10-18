class_name NpcGaze
extends Node

@export var head: Node3D
@export var torso: Node3D
@export var target: Node3D
@export var enter_radius: float = 3.0
@export var exit_radius: float = 3.3
@export var head_yaw_limit: float = 60.0
@export var head_pitch_limit: float = 25.0
@export var torso_yaw_limit: float = 12.0
@export var response: float = 7.5

var _head_rest: Basis
var _torso_rest: Basis
var _following: bool = false


func _ready() -> void:
	_head_rest = head.basis
	_torso_rest = torso.basis


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var distance := head.global_position.distance_to(target.global_position)
	_following = distance <= (exit_radius if _following else enter_radius)
	var head_goal := _head_rest
	var torso_goal := _torso_rest
	if _following:
		var direction := (head.get_parent_node_3d().to_local(target.global_position) - head.position).normalized()
		var yaw := clampf(atan2(-direction.x, -direction.z), -deg_to_rad(head_yaw_limit), deg_to_rad(head_yaw_limit))
		var pitch := clampf(asin(direction.y), -deg_to_rad(head_pitch_limit), deg_to_rad(head_pitch_limit))
		head_goal = _head_rest * Basis.from_euler(Vector3(pitch, yaw, 0))
		torso_goal = _torso_rest * Basis(Vector3.UP, clampf(yaw * 0.2, -deg_to_rad(torso_yaw_limit), deg_to_rad(torso_yaw_limit)))
	var weight := 1.0 - exp(-response * delta)
	head.basis = head.basis.slerp(head_goal, weight)
	torso.basis = torso.basis.slerp(torso_goal, weight)
