class_name LaikaRoom
extends Node3D

signal objective_changed(text: String, detail: String, values: Array)
signal prompt_changed(text: String, action: StringName)
signal carrying_changed(text: String)
signal thought_requested(text: String)
signal dialogue_requested(id: StringName)
signal departure_requested(destination: StringName)
signal sniffing_changed(active: bool)
signal completed

@export var player: FPSPlayer
@export var rig: FPSCamera
@export var camera: Camera3D
@export var carry_anchor: Marker3D
@export var menu_camera: Camera3D
@export var progress: RoomProgress
var _interactables: Array[LaikaInteractionPoint] = []

@onready var carry := get_node_or_null("Systems/Carry") as CarryController
@onready var interactor := get_node_or_null("Systems/Interactor") as PlayerInteractor
@onready var scent := get_node_or_null("Systems/Scent") as ScentController

var control_enabled: bool = false
var configured: bool = false


func _ready() -> void:
	var errors := configuration_errors()
	if not errors.is_empty():
		push_error("%s: %s" % [get_path(), "; ".join(errors)])
		return
	configured = true
	carry.room = self
	interactor.room = self
	scent.room = self
	carry.changed.connect(carrying_changed.emit)
	interactor.prompt_changed.connect(prompt_changed.emit)
	scent.changed.connect(sniffing_changed.emit)
	progress.setup(self)
	for target: LaikaInteractionPoint in get_interactions():
		target.validate_runtime()
	set_control_enabled(false)
	menu_camera.make_current()


func begin() -> void:
	if not configured:
		return
	camera.make_current()
	set_control_enabled(true)
	carrying_changed.emit("")
	progress.begin()


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	player.set_physics_process(enabled)
	rig.set_process_unhandled_input(enabled)
	set_interactions_enabled(enabled)
	if not enabled:
		player.velocity = Vector3.ZERO


func set_interactions_enabled(enabled: bool) -> void:
	interactor.set_enabled(enabled and control_enabled)
	scent.enabled = enabled and control_enabled


func complete_dialogue(id: StringName) -> void:
	progress.complete_dialogue(id)


func interact() -> void:
	interactor.interact()


func drop() -> void:
	if interactor.enabled:
		carry.drop()


func register_interaction(point: LaikaInteractionPoint) -> void:
	if not point in _interactables:
		_interactables.append(point)


func unregister_interaction(point: LaikaInteractionPoint) -> void:
	_interactables.erase(point)


func get_interactions() -> Array[LaikaInteractionPoint]:
	_interactables = _interactables.filter(is_instance_valid)
	return _interactables.duplicate()


func configuration_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for field: String in ["player", "rig", "camera", "carry_anchor", "menu_camera", "progress", "carry", "interactor", "scent"]:
		if not is_instance_valid(get(field)):
			errors.append(field + ": assign the required room component.")
	if is_instance_valid(progress):
		errors.append_array(progress.configuration_errors())
	return errors
