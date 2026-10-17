class_name LaikaRoom
extends Node3D

signal objective_changed(text: String, detail: String)
signal prompt_changed(text: String, action: StringName)
signal carrying_changed(text: String)
signal thought_requested(text: String)
signal dialogue_requested(id: StringName)
signal departure_requested(destination: StringName)
signal sniffing_changed(active: bool)
signal completed

const Step = RoomProgress.Step

@export var player: FPSPlayer
@export var rig: FPSCamera
@export var camera: Camera3D
@export var carry_anchor: Marker3D
@export var menu_camera: Camera3D
@export var scent_markers: Node3D
@export var progress: RoomProgress
var interactables: Array[LaikaInteractionPoint] = []

@onready var carry: CarryController = $Systems/Carry
@onready var interactor: PlayerInteractor = $Systems/Interactor
@onready var scent: ScentController = $Systems/Scent

var control_enabled: bool = false
var step: RoomProgress.Step:
	get: return progress.step


func _ready() -> void:
	for body: Node in find_children("*", "StaticBody3D", true, false):
		if body is LaikaInteractionPoint:
			interactables.append(body)
	carry.room = self
	interactor.room = self
	scent.room = self
	carry.changed.connect(carrying_changed.emit)
	interactor.prompt_changed.connect(prompt_changed.emit)
	scent.changed.connect(sniffing_changed.emit)
	progress.setup(self)
	set_control_enabled(false)
	menu_camera.make_current()


func begin() -> void:
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


func bark() -> void:
	thought_requested.emit(tr("Woof!"))
