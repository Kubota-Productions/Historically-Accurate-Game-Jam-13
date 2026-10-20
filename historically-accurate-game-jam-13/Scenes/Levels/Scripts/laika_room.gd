class_name LaikaRoom
extends Node3D

@warning_ignore_start("unused_signal")
signal objective_changed(text: String, detail: String, values: Array)
signal prompt_changed(text: String)
signal carrying_changed(item_name: String)
signal thought_requested(text: String)
signal dialogue_requested(dialogue: Dialogue)
signal departure_requested(destination: RoomDefinition)
signal sniffing_changed(active: bool)
signal completed
@warning_ignore_restore("unused_signal")

@export var movement_enabled: bool = true
@export var rig: FPSCamera
@export var menu_camera: Camera3D
@export var progress: RoomProgress
@export var carry: CarryController
@export var interactor: PlayerInteractor
@export var scent: ScentController

var player: FPSPlayer:
	get: return rig.player
var camera: Camera3D:
	get: return rig.camera
var control_enabled: bool = false
var configured: bool = false


func _ready() -> void:
	var errors := configuration_errors()
	if not errors.is_empty():
		push_error("%s: %s" % [name, "; ".join(errors)])
		return
	configured = true
	carry.changed.connect(carrying_changed.emit)
	interactor.prompt_changed.connect(prompt_changed.emit)
	scent.changed.connect(sniffing_changed.emit)
	for target: Interactable in interactables():
		var target_errors := target.configuration_errors(self)
		if not target_errors.is_empty():
			target.enabled = false
			push_error("%s: %s" % [get_path_to(target), "; ".join(target_errors)])
	set_control_enabled(false)
	menu_camera.make_current()


func begin() -> void:
	camera.make_current()
	set_control_enabled(true)
	progress.begin()


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	player.set_physics_process(enabled and movement_enabled)
	rig.set_process_unhandled_input(enabled)
	set_interactions_enabled(enabled)
	if not enabled:
		player.velocity = Vector3.ZERO


func set_interactions_enabled(enabled: bool) -> void:
	interactor.enabled = enabled and control_enabled
	scent.enabled = enabled and control_enabled


func interact() -> void:
	interactor.interact()


func drop() -> void:
	if interactor.enabled:
		carry.drop()


func interactables() -> Array[Interactable]:
	var result: Array[Interactable] = []
	for node: Node in get_tree().get_nodes_in_group(&"interactables"):
		if is_ancestor_of(node):
			result.append(node)
	return result


func configuration_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	var required := {"rig": rig, "menu_camera": menu_camera, "progress": progress, "carry": carry, "interactor": interactor, "scent": scent}
	for field: String in required:
		if required[field] == null:
			errors.append(field + ": assign it in the Inspector.")
	if carry and carry.anchor == null:
		errors.append("carry: assign its anchor.")
	if progress:
		errors.append_array(progress.configuration_errors())
	return errors
