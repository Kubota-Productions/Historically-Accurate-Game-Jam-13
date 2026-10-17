class_name PlayerInteractor
extends Node

signal prompt_changed(text: String)

@export var reach: float = 3.0

var target: Interactable
var enabled: bool = false:
	set(value):
		enabled = value
		if not enabled:
			target = null
			_show_prompt("")
var _prompt: String = ""

@onready var room: LaikaRoom = owner


func _process(_delta: float) -> void:
	if not enabled:
		return
	var eye := room.camera.global_transform
	var query := PhysicsRayQueryParameters3D.create(eye.origin, eye.origin - eye.basis.z * reach, Layers.WORLD | Layers.INTERACTABLES, [room.player.get_rid()])
	target = room.get_world_3d().direct_space_state.intersect_ray(query).get("collider") as Interactable
	_show_prompt(target.get_prompt(room) if target else "")


func interact() -> void:
	if enabled and is_instance_valid(target):
		target.interact(room)


func _show_prompt(text: String) -> void:
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
