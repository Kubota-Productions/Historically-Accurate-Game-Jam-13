class_name PlayerInteractor
extends Node

signal prompt_changed(text: String, action: StringName)

@export var reach: float = 3.0

var room: LaikaRoom
var target: LaikaInteractionPoint
var enabled: bool = false
var _last_prompt: String = ""


func _process(_delta: float) -> void:
	if not enabled:
		return
	var camera := room.camera
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * reach, 3, [room.player.get_rid()])
	var hit := room.get_world_3d().direct_space_state.intersect_ray(query)
	target = hit.get("collider") as LaikaInteractionPoint
	var text := target.get_prompt(room) if is_instance_valid(target) else ""
	if text != _last_prompt:
		_last_prompt = text
		prompt_changed.emit(text, &"interact")


func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		target = null
		_last_prompt = ""
		prompt_changed.emit("", &"interact")


func interact() -> void:
	if enabled and is_instance_valid(target):
		target.interact(room)
